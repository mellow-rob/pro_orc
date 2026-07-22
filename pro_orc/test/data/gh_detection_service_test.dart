import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';

/// Fake [ProcessResult] fixtures mimicking real `gh auth status` text output.
///
/// `gh` prints its human-readable status block to stderr, not stdout, so all
/// fixtures put the interesting text on [ProcessResult.stderr] to match real
/// behavior. The parser under test must not assume stdout.
class _GhAuthStatusFixtures {
  /// Logged in, `delete_repo` scope present among others.
  static final withDeleteRepoScope = ProcessResult(
    0,
    0,
    '',
    "github.com\n"
        "  ✓ Logged in to github.com account octocat (keyring)\n"
        "  - Active account: true\n"
        "  - Git operations protocol: https\n"
        "  - Token: gho_************************************\n"
        "  - Token scopes: 'gist', 'read:org', 'repo', 'workflow', 'delete_repo'\n",
  );

  /// Logged in, but `delete_repo` scope is absent.
  static final withoutDeleteRepoScope = ProcessResult(
    0,
    0,
    '',
    "github.com\n"
        "  ✓ Logged in to github.com account octocat (keyring)\n"
        "  - Active account: true\n"
        "  - Git operations protocol: https\n"
        "  - Token: gho_************************************\n"
        "  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'\n",
  );

  /// Logged in, scope list contains a superstring of `delete_repo` but not
  /// the exact scope itself — must NOT be matched as present (negative
  /// control against naive substring matching).
  static final withSuperstringScope = ProcessResult(
    0,
    0,
    '',
    "github.com\n"
        "  ✓ Logged in to github.com account octocat (keyring)\n"
        "  - Active account: true\n"
        "  - Token scopes: 'gist', 'not_delete_repo_related', 'repo'\n",
  );

  /// Not logged in at all — exit code non-zero, no scopes line.
  static final notLoggedIn = ProcessResult(
    0,
    1,
    '',
    "You are not logged into any GitHub hosts. Run gh auth login to authenticate.\n",
  );

  /// Garbage/unparseable output (e.g. unexpected CLI format change).
  static final garbageOutput = ProcessResult(
    0,
    0,
    '',
    'unexpected garbage output',
  );

  /// Multiple accounts logged in on the same host; the second one
  /// (`n3urala1-rob`) is the active one. Mirrors the real `gh auth status`
  /// shape when several accounts share a host block.
  static final multiAccountSecondActive = ProcessResult(
    0,
    0,
    '',
    "github.com\n"
        "  ✓ Logged in to github.com account mellow-rob (keyring)\n"
        "  - Active account: false\n"
        "  - Git operations protocol: https\n"
        "  - Token scopes: 'gist', 'repo'\n"
        "  ✓ Logged in to github.com account n3urala1-rob (keyring)\n"
        "  - Active account: true\n"
        "  - Git operations protocol: https\n"
        "  - Token scopes: 'gist', 'read:org', 'repo', 'delete_repo'\n",
  );

  /// Logged in, but no line is explicitly marked as the active account
  /// (unexpected `gh` output shape) — the parser must not guess.
  static final noActiveAccountMarked = ProcessResult(
    0,
    0,
    '',
    "github.com\n"
        "  ✓ Logged in to github.com account octocat (keyring)\n"
        "  - Git operations protocol: https\n"
        "  - Token scopes: 'gist', 'repo'\n",
  );
}

/// Injects a fixed [ProcessResult] regardless of the command invoked, so the
/// service's parsing logic can be exercised without a real `gh` binary.
Future<ProcessResult> Function(String, List<String>, {Duration? timeout})
_fixedRunner(ProcessResult result) {
  return (String command, List<String> args, {Duration? timeout}) async =>
      result;
}

/// Injects a runner that never completes within any reasonable timeout, to
/// simulate a hung `gh` process.
Future<ProcessResult> Function(String, List<String>, {Duration? timeout})
_hangingRunner() {
  return (String command, List<String> args, {Duration? timeout}) async {
    await Future<void>.delayed(const Duration(seconds: 30));
    return ProcessResult(0, 0, '', '');
  };
}

/// Injects a runner that throws, simulating a process-launch failure.
Future<ProcessResult> Function(String, List<String>, {Duration? timeout})
_throwingRunner() {
  return (String command, List<String> args, {Duration? timeout}) async {
    throw ProcessException(command, args, 'simulated launch failure');
  };
}

void main() {
  group('GhDetectionService.isAvailable() (existing behavior, untouched)', () {
    test(
      'isAvailable() returns true when which and auth status both succeed',
      () async {
        final service = GhDetectionService(
          whichCommand: 'true', // exits 0 regardless of args
          ghCommand: 'true',
        );

        final available = await service.isAvailable();

        expect(available, isTrue);
      },
    );

    test(
      'isAvailable() returns false when which fails (CLI not installed)',
      () async {
        final service = GhDetectionService(
          whichCommand: 'false', // exits 1 regardless of args
          ghCommand: 'true',
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );

    test(
      'isAvailable() returns false when auth status fails (not logged in)',
      () async {
        final service = GhDetectionService(
          whichCommand: 'true',
          ghCommand: 'false', // auth status subcommand also exits 1
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );

    test(
      'isAvailable() returns false (no crash) for a nonexistent binary',
      () async {
        final service = GhDetectionService(
          whichCommand: 'which_nonexistent_binary_xyz',
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );
  });

  group(
    'GhDetectionService.checkDeleteRepoScope() — FR-001 (scope parsing)',
    () {
      test(
        'returns present when delete_repo appears in Token scopes line',
        () async {
          final service = GhDetectionService(
            whichCommand: 'true',
            authStatusRunner: _fixedRunner(
              _GhAuthStatusFixtures.withDeleteRepoScope,
            ),
          );

          final status = await service.checkDeleteRepoScope();

          expect(status, GhScopeStatus.present);
        },
      );

      test(
        'returns missing when delete_repo is absent from Token scopes line',
        () async {
          final service = GhDetectionService(
            whichCommand: 'true',
            authStatusRunner: _fixedRunner(
              _GhAuthStatusFixtures.withoutDeleteRepoScope,
            ),
          );

          final status = await service.checkDeleteRepoScope();

          expect(status, GhScopeStatus.missing);
        },
      );

      test(
        'does NOT match a superstring scope as delete_repo (negative control '
        'against naive substring matching)',
        () async {
          final service = GhDetectionService(
            whichCommand: 'true',
            authStatusRunner: _fixedRunner(
              _GhAuthStatusFixtures.withSuperstringScope,
            ),
          );

          final status = await service.checkDeleteRepoScope();

          expect(
            status,
            GhScopeStatus.missing,
            reason:
                "'not_delete_repo_related' must not be substring-matched as "
                "'delete_repo'",
          );
        },
      );
    },
  );

  group(
    'GhDetectionService.checkDeleteRepoScope() — FR-012 (cli-unavailable is distinct)',
    () {
      test(
        'returns cliUnavailable when isAvailable() is false (gh not installed)',
        () async {
          final service = GhDetectionService(
            whichCommand: 'false', // simulates `which gh` failing
            authStatusRunner: _fixedRunner(
              _GhAuthStatusFixtures.withDeleteRepoScope,
            ),
          );

          final status = await service.checkDeleteRepoScope();

          expect(status, GhScopeStatus.cliUnavailable);
        },
      );

      test('returns cliUnavailable when not logged in '
          '(isAvailable()\'s own auth status check exits != 0)', () async {
        // `false` simulates `gh auth status` failing inside isAvailable()
        // itself (the real not-logged-in signal) — distinct from the
        // authStatusRunner fixture below, which only feeds
        // checkDeleteRepoScope()'s own second call once isAvailable() has
        // already returned true.
        final service = GhDetectionService(
          whichCommand: 'true',
          ghCommand: 'false',
          authStatusRunner: _fixedRunner(_GhAuthStatusFixtures.notLoggedIn),
        );

        final status = await service.checkDeleteRepoScope();

        expect(status, GhScopeStatus.cliUnavailable);
      });

      test(
        'cliUnavailable is a distinct value from missing (not the same enum case)',
        () {
          expect(
            GhScopeStatus.cliUnavailable,
            isNot(equals(GhScopeStatus.missing)),
          );
        },
      );
    },
  );

  group(
    'GhDetectionService.checkDeleteRepoScope() — FR-007 (check failed degrades to blocked)',
    () {
      test('returns a blocked status (not present) when auth status output is '
          'unparseable garbage', () async {
        final service = GhDetectionService(
          whichCommand: 'true',
          authStatusRunner: _fixedRunner(_GhAuthStatusFixtures.garbageOutput),
        );

        final status = await service.checkDeleteRepoScope();

        expect(status, isNot(GhScopeStatus.present));
      });

      test(
        'returns a blocked status (not present) when the runner throws',
        () async {
          final service = GhDetectionService(
            whichCommand: 'true',
            authStatusRunner: _throwingRunner(),
          );

          final status = await service.checkDeleteRepoScope();

          expect(status, isNot(GhScopeStatus.present));
        },
      );

      test(
        'never throws when the runner throws (caller can always await safely)',
        () async {
          final service = GhDetectionService(
            whichCommand: 'true',
            authStatusRunner: _throwingRunner(),
          );

          await expectLater(service.checkDeleteRepoScope(), completes);
        },
      );

      test(
        'returns a blocked status (not present) when gh hangs past the timeout',
        () async {
          final service = GhDetectionService(
            whichCommand: 'true',
            authStatusRunner: _hangingRunner(),
            authStatusTimeout: const Duration(milliseconds: 50),
          );

          final status = await service.checkDeleteRepoScope();

          expect(status, isNot(GhScopeStatus.present));
        },
      );
    },
  );

  group('GhDetectionService.getActiveAccountLogin() '
      '(2026-07-22-gh-auth-refresh-wrong-account)', () {
    test(
      'returns the login of the account marked "Active account: true"',
      () async {
        final service = GhDetectionService(
          whichCommand: 'true',
          authStatusRunner: _fixedRunner(
            _GhAuthStatusFixtures.withDeleteRepoScope,
          ),
        );

        final login = await service.getActiveAccountLogin();

        expect(login, 'octocat');
      },
    );

    test('with multiple accounts logged in, returns the one marked active '
        '(not the first line)', () async {
      final service = GhDetectionService(
        whichCommand: 'true',
        authStatusRunner: _fixedRunner(
          _GhAuthStatusFixtures.multiAccountSecondActive,
        ),
      );

      final login = await service.getActiveAccountLogin();

      expect(login, 'n3urala1-rob');
    });

    test(
      'returns null when gh is not installed/logged in (isAvailable() false)',
      () async {
        final service = GhDetectionService(
          whichCommand: 'false',
          authStatusRunner: _fixedRunner(
            _GhAuthStatusFixtures.withDeleteRepoScope,
          ),
        );

        final login = await service.getActiveAccountLogin();

        expect(login, isNull);
      },
    );

    test('returns null when no line is marked as the active account '
        '(conservative: cannot determine, do not guess)', () async {
      final service = GhDetectionService(
        whichCommand: 'true',
        authStatusRunner: _fixedRunner(
          _GhAuthStatusFixtures.noActiveAccountMarked,
        ),
      );

      final login = await service.getActiveAccountLogin();

      expect(login, isNull);
    });

    test('returns null on garbage/unparseable output', () async {
      final service = GhDetectionService(
        whichCommand: 'true',
        authStatusRunner: _fixedRunner(_GhAuthStatusFixtures.garbageOutput),
      );

      final login = await service.getActiveAccountLogin();

      expect(login, isNull);
    });

    test('returns null (never throws) when the runner throws', () async {
      final service = GhDetectionService(
        whichCommand: 'true',
        authStatusRunner: _throwingRunner(),
      );

      await expectLater(service.getActiveAccountLogin(), completes);
      final login = await service.getActiveAccountLogin();
      expect(login, isNull);
    });
  });
}
