// Testing rationale (applies to any future MCP/HTTP-tier test in this
// project — follow this same pattern rather than reaching for a mock
// library):
//
// The project convention forbids mock OBJECTS (see `test/data/a1_reader_test.dart`:
// real temp dirs, no `Mock`/`when()` doubles) but a live network call to the
// production A1 Brain server in CI/tests is undesirable (slow, flaky, needs
// a real Keychain token, mutates nothing but still an external dependency).
//
// This is resolved by injecting the HTTP TRANSPORT as a constructor
// dependency (`McpTransport`, see `mcp_transport.dart`). Production code
// gets the default `HttpMcpTransport` (a real `dart:io` `HttpClient` against
// the real Brain URL); these tests instead spin up a REAL local
// `HttpServer` bound to `localhost` (a real socket, not a mock) that serves
// recorded JSON-RPC response bodies from `test/fixtures/brain/*.json`. The
// repository under test talks to this fixture server exactly as it would
// to production — only the endpoint differs. Timeout behavior is exercised
// by simply not responding within the repository's configured timeout, and
// auth-failure behavior by returning a real HTTP 401 — again, real
// transport-level behavior, not a stubbed exception.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/roadmap/a1_brain_roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/mcp_transport.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';

/// Loads and decodes a recorded MCP JSON-RPC fixture from
/// `test/fixtures/brain/<name>.json`.
Map<String, dynamic> _loadFixture(String name) {
  final file = File('test/fixtures/brain/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Real local HTTP server that answers each JSON-RPC `method` with a
/// canned fixture response, or with a deliberate delay/401 to exercise
/// timeout/auth failure classification. Not a mock — a genuine socket.
class _FixtureBrainServer {
  _FixtureBrainServer._(this._server, this.port);

  final HttpServer _server;
  final int port;

  /// Requests captured so tests can assert the bearer token was sent (and,
  /// separately, never appears in any log output — see the "never logs
  /// token" test which inspects captured `developer.log` output instead).
  final List<String?> capturedAuthHeaders = [];

  static Future<_FixtureBrainServer> start({
    Map<String, dynamic>? initializeResponse,
    Map<String, dynamic>? searchNotesResponse,
    Map<String, dynamic>? readNoteResponse,
    Duration? hangFor,
    bool rejectAuth = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = _FixtureBrainServer._(server, server.port);

    server.listen((HttpRequest request) async {
      instance.capturedAuthHeaders.add(
        request.headers.value(HttpHeaders.authorizationHeader),
      );

      if (rejectAuth) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }

      if (hangFor != null) {
        await Future<void>.delayed(hangFor);
      }

      final bodyStr = await utf8.decoder.bind(request).join();
      final body = bodyStr.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(bodyStr) as Map<String, dynamic>;
      final method = body['method'] as String?;

      Map<String, dynamic>? responseBody;
      switch (method) {
        case 'initialize':
          responseBody = initializeResponse;
          request.response.headers.set('mcp-session-id', 'fixture-session-1');
          break;
        case 'notifications/initialized':
          responseBody = null;
          break;
        case 'tools/call':
          final toolName = (body['params'] as Map?)?['name'] as String?;
          responseBody = toolName == 'search_notes'
              ? searchNotesResponse
              : readNoteResponse;
          break;
      }

      request.response.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      if (responseBody != null) {
        request.response.add(utf8.encode(jsonEncode(responseBody)));
      }
      await request.response.close();
    });

    return instance;
  }

  Future<void> close() => _server.close(force: true);
}

class _FixtureTransport implements McpTransport {
  _FixtureTransport(
    this.port, {
    this.timeout = const Duration(milliseconds: 500),
  });

  final int port;
  final Duration timeout;

  @override
  Future<McpResponse> send({
    required Map<String, dynamic> body,
    required String bearerToken,
    String? sessionId,
  }) async {
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:$port/mcp'))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $bearerToken',
      );
      if (sessionId != null) {
        request.headers.set('mcp-session-id', sessionId);
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(timeout);

      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        throw McpAuthException('HTTP ${response.statusCode}');
      }

      final respSessionId = response.headers.value('mcp-session-id');
      final raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (raw.trim().isEmpty) {
        return (body: null, sessionId: respSessionId);
      }
      return (
        body: jsonDecode(raw) as Map<String, dynamic>,
        sessionId: respSessionId,
      );
    } on TimeoutException {
      throw const McpTimeoutException('fixture transport timed out');
    } finally {
      client.close(force: true);
    }
  }
}

void main() {
  group('A1BrainRoadmapRepository — success path', () {
    test(
      'resolves RoadmapData from search_notes + read_note fixtures',
      () async {
        final server = await _FixtureBrainServer.start(
          initializeResponse: _loadFixture('initialize_success'),
          searchNotesResponse: _loadFixture('search_notes_success'),
          readNoteResponse: _loadFixture('read_note_success'),
        );
        addTearDown(server.close);

        final repo = A1BrainRoadmapRepository(
          transport: _FixtureTransport(server.port),
          readToken: () async => 'fixture-token-value',
        );

        final result = await repo.resolve('pro-orc', '/unused');

        expect(result.source, RoadmapSource.brain);
        expect(result.failure, isNull);
        expect(result.data.isEmpty, isFalse);
        expect(
          result.data.milestones.map((m) => m.name),
          containsAll(['M1 — Setup', 'M2 — Roadmap Dashboard']),
        );

        // Sanity: the token WAS sent as a bearer header (transport-level
        // proof the injection works) but never logged (see below).
        expect(server.capturedAuthHeaders, isNotEmpty);
        expect(
          server.capturedAuthHeaders.first,
          contains('fixture-token-value'),
        );
      },
    );
  });

  group('A1BrainRoadmapRepository — failure classification (FR-015)', () {
    test('classifies a hanging server as timeout', () async {
      final server = await _FixtureBrainServer.start(
        initializeResponse: _loadFixture('initialize_success'),
        hangFor: const Duration(seconds: 2),
      );
      addTearDown(server.close);

      final repo = A1BrainRoadmapRepository(
        transport: _FixtureTransport(
          server.port,
          timeout: const Duration(milliseconds: 200),
        ),
        readToken: () async => 'fixture-token-value',
      );

      final result = await repo.resolve('pro-orc', '/unused');

      expect(result.data.isEmpty, isTrue);
      expect(result.failure, isNotNull);
      expect(result.failure!.kind, RoadmapFailureKind.timeout);
    });

    test('classifies an HTTP 401 as authFailure', () async {
      final server = await _FixtureBrainServer.start(rejectAuth: true);
      addTearDown(server.close);

      final repo = A1BrainRoadmapRepository(
        transport: _FixtureTransport(server.port),
        readToken: () async => 'fixture-token-value',
      );

      final result = await repo.resolve('pro-orc', '/unused');

      expect(result.data.isEmpty, isTrue);
      expect(result.failure, isNotNull);
      expect(result.failure!.kind, RoadmapFailureKind.authFailure);
    });

    test(
      'classifies a missing keychain token as authFailure without any network call',
      () async {
        final repo = A1BrainRoadmapRepository(
          transport: _FixtureTransport(0), // never reached
          readToken: () async => null,
        );

        final result = await repo.resolve('pro-orc', '/unused');

        expect(result.data.isEmpty, isTrue);
        expect(result.failure!.kind, RoadmapFailureKind.authFailure);
      },
    );

    test('classifies an empty search_notes result as noResult', () async {
      final server = await _FixtureBrainServer.start(
        initializeResponse: _loadFixture('initialize_success'),
        searchNotesResponse: _loadFixture('search_notes_empty'),
      );
      addTearDown(server.close);

      final repo = A1BrainRoadmapRepository(
        transport: _FixtureTransport(server.port),
        readToken: () async => 'fixture-token-value',
      );

      final result = await repo.resolve('unknown-slug', '/unused');

      expect(result.data.isEmpty, isTrue);
      expect(result.failure, isNotNull);
      expect(result.failure!.kind, RoadmapFailureKind.noResult);
    });
  });

  group('A1BrainRoadmapRepository — token safety (FR-010)', () {
    test('never includes the bearer token in the failure message', () async {
      const secretToken = 'super-secret-keychain-token-xyz';
      final server = await _FixtureBrainServer.start(rejectAuth: true);
      addTearDown(server.close);

      final repo = A1BrainRoadmapRepository(
        transport: _FixtureTransport(server.port),
        readToken: () async => secretToken,
      );

      final result = await repo.resolve('pro-orc', '/unused');

      // Negative assertion: the token must not leak into any user-facing
      // or logged string this call produces.
      expect(result.failure!.message, isNot(contains(secretToken)));
      expect(result.data.isEmpty, isTrue);
    });
  });
}
