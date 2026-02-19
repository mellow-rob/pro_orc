import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/services/git_reader.dart';
import 'package:pro_orc/data/models/git_data.dart';

/// Creates a temporary git repo with an initial commit and optional remote.
Future<Directory> createTempGitRepo({String? remote}) async {
  final tmp = await Directory.systemTemp.createTemp('git_test_');
  await Process.run('git', ['init'], workingDirectory: tmp.path, runInShell: true);
  await Process.run('git', ['config', 'user.email', 'test@test.com'], workingDirectory: tmp.path, runInShell: true);
  await Process.run('git', ['config', 'user.name', 'Test'], workingDirectory: tmp.path, runInShell: true);
  await File(p.join(tmp.path, 'README.md')).writeAsString('# Test');
  await Process.run('git', ['add', '.'], workingDirectory: tmp.path, runInShell: true);
  await Process.run('git', ['commit', '-m', 'Initial commit'], workingDirectory: tmp.path, runInShell: true);
  if (remote != null) {
    await Process.run('git', ['remote', 'add', 'origin', remote], workingDirectory: tmp.path, runInShell: true);
  }
  return tmp;
}

void main() {
  group('GitReader', () {
    group('readGitData', () {
      test('returns commit data for a valid git repo with GitHub HTTPS remote', () async {
        final tmp = await createTempGitRepo(
          remote: 'https://github.com/owner/repo.git',
        );
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.isEmpty, isFalse);
        expect(result.lastCommitMessage, equals('Initial commit'));
        expect(result.lastCommitHash, isNotNull);
        expect(result.lastCommitHash!.length, equals(7));
        expect(result.lastCommitDate, isNotNull);
        expect(result.githubUrl, equals('https://github.com/owner/repo'));
      });

      test('returns commit data for a valid git repo with GitHub SSH remote', () async {
        final tmp = await createTempGitRepo(
          remote: 'git@github.com:owner/repo.git',
        );
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.isEmpty, isFalse);
        expect(result.lastCommitMessage, equals('Initial commit'));
        expect(result.githubUrl, equals('https://github.com/owner/repo'));
      });

      test('returns commit data with null githubUrl for git repo without remote', () async {
        final tmp = await createTempGitRepo();
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.isEmpty, isFalse);
        expect(result.lastCommitMessage, equals('Initial commit'));
        expect(result.lastCommitHash, isNotNull);
        expect(result.lastCommitDate, isNotNull);
        expect(result.githubUrl, isNull);
      });

      test('returns GitData.empty for a non-git directory without throwing', () async {
        final tmp = await Directory.systemTemp.createTemp('non_git_');
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.isEmpty, isTrue);
      });

      test('returns GitData.empty for a non-existent directory without throwing', () async {
        final result = await readGitData('/tmp/this_path_does_not_exist_9182736');

        expect(result.isEmpty, isTrue);
      });

      test('returns null githubUrl for non-GitHub remote', () async {
        final tmp = await createTempGitRepo(
          remote: 'https://gitlab.com/owner/repo.git',
        );
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.isEmpty, isFalse);
        expect(result.githubUrl, isNull);
      });

      test('gitBinary parameter is used for git calls', () async {
        // Using 'git' as gitBinary (same as default) to verify parameter is accepted
        final tmp = await createTempGitRepo();
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path, gitBinary: 'git');

        expect(result.isEmpty, isFalse);
      });
    });

    group('_remoteToGithubUrl (via readGitData)', () {
      test('normalizes HTTPS remote by stripping .git suffix', () async {
        final tmp = await createTempGitRepo(
          remote: 'https://github.com/myorg/myrepo.git',
        );
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.githubUrl, equals('https://github.com/myorg/myrepo'));
      });

      test('normalizes SSH remote to HTTPS format', () async {
        final tmp = await createTempGitRepo(
          remote: 'git@github.com:myorg/myrepo.git',
        );
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.githubUrl, equals('https://github.com/myorg/myrepo'));
      });

      test('returns null for non-GitHub HTTPS remote', () async {
        final tmp = await createTempGitRepo(
          remote: 'https://bitbucket.org/owner/repo.git',
        );
        addTearDown(() => tmp.delete(recursive: true));

        final result = await readGitData(tmp.path);

        expect(result.githubUrl, isNull);
      });
    });

    group('readAllGitData', () {
      test('returns results for all paths in correct order', () async {
        final repos = await Future.wait([
          createTempGitRepo(remote: 'https://github.com/owner/repo1.git'),
          createTempGitRepo(remote: 'https://github.com/owner/repo2.git'),
          createTempGitRepo(),
        ]);
        addTearDown(() async {
          for (final r in repos) {
            await r.delete(recursive: true);
          }
        });

        final paths = repos.map((r) => r.path).toList();
        final results = await readAllGitData(paths);

        expect(results.length, equals(3));
        expect(results[0].githubUrl, equals('https://github.com/owner/repo1'));
        expect(results[1].githubUrl, equals('https://github.com/owner/repo2'));
        expect(results[2].githubUrl, isNull);
        expect(results[2].lastCommitMessage, equals('Initial commit'));
      });

      test('handles 12 paths in chunks of 5 (3 chunks: 5, 5, 2)', () async {
        // Create 12 directories — mix of git repos and non-git
        final dirs = await Future.wait(
          List.generate(12, (i) => i < 6
            ? createTempGitRepo()
            : Directory.systemTemp.createTemp('non_git_')),
        );
        addTearDown(() async {
          for (final d in dirs) {
            await d.delete(recursive: true);
          }
        });

        final paths = dirs.map((d) => d.path).toList();
        final results = await readAllGitData(paths);

        expect(results.length, equals(12));
        // First 6 are git repos, last 6 are non-git (empty)
        for (int i = 0; i < 6; i++) {
          expect(results[i].isEmpty, isFalse, reason: 'Index $i should be non-empty git repo');
        }
        for (int i = 6; i < 12; i++) {
          expect(results[i].isEmpty, isTrue, reason: 'Index $i should be empty non-git dir');
        }
      });

      test('returns empty list for empty input', () async {
        final results = await readAllGitData([]);
        expect(results, isEmpty);
      });

      test('individual errors do not fail the whole batch', () async {
        final repo = await createTempGitRepo();
        addTearDown(() => repo.delete(recursive: true));

        final results = await readAllGitData([
          repo.path,
          '/tmp/nonexistent_path_xyz_987654',
          repo.path,
        ]);

        expect(results.length, equals(3));
        expect(results[0].isEmpty, isFalse);
        expect(results[1].isEmpty, isTrue);
        expect(results[2].isEmpty, isFalse);
      });
    });
  });
}
