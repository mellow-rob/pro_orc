import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A single JSON-RPC round-trip result from an [McpTransport] call: the
/// decoded response body (null for fire-and-forget notifications with no
/// body) plus the `mcp-session-id` response header, if the server sent one
/// (only `initialize` responses carry it in practice).
typedef McpResponse = ({Map<String, dynamic>? body, String? sessionId});

/// Thin transport abstraction over the A1 Brain MCP streamable-HTTP
/// endpoint, injected into [A1BrainRoadmapRepository] so tests can swap in a
/// real local fixture HTTP server instead of the production Brain server.
///
/// This is intentionally NOT a mock object — per project convention (see
/// `test/data/roadmap/a1_brain_roadmap_repository_test.dart` header), the
/// test double is a real `HttpServer` bound to localhost serving recorded
/// JSON-RPC fixtures, and this interface is what lets the repository be
/// pointed at either transport without changing its logic.
///
/// No Flutter imports — pure Dart, isolate-safe.
abstract class McpTransport {
  /// Sends a single JSON-RPC 2.0 request (`initialize`,
  /// `notifications/initialized`, or `tools/call`) to the MCP endpoint.
  ///
  /// [sessionId] is the `mcp-session-id` header value returned by a prior
  /// `initialize` call, echoed on all subsequent calls; `null` on the very
  /// first (`initialize`) call.
  ///
  /// Implementations MUST NOT throw for ordinary failure modes (timeout,
  /// non-2xx status, connection refused) — instead throw one of the typed
  /// exceptions in this file so [A1BrainRoadmapRepository] can classify them
  /// per FR-015. Truly unexpected errors may still propagate; the
  /// repository wraps every transport call in a try/catch as a final
  /// safety net.
  Future<McpResponse> send({
    required Map<String, dynamic> body,
    required String bearerToken,
    String? sessionId,
  });
}

/// Thrown by an [McpTransport] when a call did not complete within the
/// configured time budget. Maps to `RoadmapFailureKind.timeout`.
class McpTimeoutException implements Exception {
  const McpTimeoutException([this.message]);
  final String? message;
  @override
  String toString() => 'McpTimeoutException: ${message ?? 'timed out'}';
}

/// Thrown by an [McpTransport] when the server rejects the bearer token
/// (HTTP 401/403). Maps to `RoadmapFailureKind.authFailure`.
class McpAuthException implements Exception {
  const McpAuthException([this.message]);
  final String? message;
  @override
  String toString() => 'McpAuthException: ${message ?? 'auth rejected'}';
}

/// Real production transport: a streamable-HTTP client against the A1
/// Brain MCP endpoint using `dart:io`'s [HttpClient] (no extra package
/// dependency needed). One instance is safe to reuse across calls.
class HttpMcpTransport implements McpTransport {
  HttpMcpTransport({
    this.baseUrl = 'https://brain-proxy-production.up.railway.app/mcp',
    Duration? timeout,
    HttpClient? client,
  }) : _timeout = timeout ?? const Duration(seconds: 8),
       _client = client ?? HttpClient();

  final String baseUrl;
  final Duration _timeout;
  final HttpClient _client;

  @override
  Future<McpResponse> send({
    required Map<String, dynamic> body,
    required String bearerToken,
    String? sessionId,
  }) async {
    final uri = Uri.parse(baseUrl);
    HttpClientRequest request;
    try {
      request = await _client.postUrl(uri).timeout(_timeout);
    } on TimeoutException {
      throw const McpTimeoutException('connect timed out');
    }

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(
      HttpHeaders.acceptHeader,
      'text/event-stream,application/json',
    );
    if (sessionId != null) {
      request.headers.set('mcp-session-id', sessionId);
    }

    request.write(jsonEncode(body));

    HttpClientResponse response;
    try {
      response = await request.close().timeout(_timeout);
    } on TimeoutException {
      throw const McpTimeoutException('request timed out');
    }

    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      // Drain the body so the connection can be reused/closed cleanly.
      await response.drain<void>();
      throw McpAuthException('HTTP ${response.statusCode}');
    }

    final responseSessionId = response.headers.value('mcp-session-id');

    String raw;
    try {
      raw = await response.transform(utf8.decoder).join().timeout(_timeout);
    } on TimeoutException {
      throw const McpTimeoutException('response body timed out');
    }

    if (raw.trim().isEmpty) {
      return (body: null, sessionId: responseSessionId);
    }

    // The endpoint may respond with a bare JSON object or an SSE frame
    // (`data: {...}`); handle both by taking the last JSON-looking line.
    final jsonLine = raw
        .split('\n')
        .map((l) => l.trim())
        .lastWhere((l) => l.startsWith('{'), orElse: () => raw.trim());

    final decoded = jsonDecode(jsonLine);
    return (
      body: decoded is Map<String, dynamic> ? decoded : null,
      sessionId: responseSessionId,
    );
  }
}
