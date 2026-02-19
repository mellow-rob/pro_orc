import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_settings_table.dart';
import 'package:pro_orc/data/services/project_scanner.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a temporary directory containing a basic GSD project structure.
Future<Directory> createGsdProject(Directory parent, String name, {
  String? status,
  String? phase,
  bool withGit = false,
}) async {
  final dir = Directory(p.join(parent.path, name));
  await dir.create();

  final planningDir = Directory(p.join(dir.path, '.planning'));
  await planningDir.create();

  // Write STATE.md
  final stateContent = '''# Project State

**Status:** ${status ?? 'building'}
**Phase:** ${phase ?? '1 of 3'}
''';
  await File(p.join(planningDir.path, 'STATE.md')).writeAsString(stateContent);

  // Write PROJECT.md
  final projectContent = '''# $name

## Core Value

Test project description for $name.
''';
  await File(p.join(planningDir.path, 'PROJECT.md')).writeAsString(projectContent);

  if (withGit) {
    await Process.run('git', ['init'], workingDirectory: dir.path, runInShell: true);
    await Process.run('git', ['config', 'user.email', 'test@test.com'], workingDirectory: dir.path, runInShell: true);
    await Process.run('git', ['config', 'user.name', 'Test'], workingDirectory: dir.path, runInShell: true);
    await File(p.join(dir.path, 'README.md')).writeAsString('# $name');
    await Process.run('git', ['add', '.'], workingDirectory: dir.path, runInShell: true);
    await Process.run('git', ['commit', '-m', 'Initial commit'], workingDirectory: dir.path, runInShell: true);
  }

  return dir;
}

/// Creates a plain (non-GSD) project directory.
Future<Directory> createPlainProject(Directory parent, String name) async {
  final dir = Directory(p.join(parent.path, name));
  await dir.create();
  await File(p.join(dir.path, 'README.md')).writeAsString('# $name');
  return dir;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProjectScanner', () {
    late AppDatabase db;
    late Directory scanRoot;
    late ProjectScanner scanner;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      scanRoot = await Directory.systemTemp.createTemp('scanner_test_');
      scanner = ProjectScanner(db);
    });

    tearDown(() async {
      await db.close();
      await scanRoot.delete(recursive: true);
    });

    // -----------------------------------------------------------------------
    // ScanDirectoryNotFoundError
    // -----------------------------------------------------------------------

    group('ScanDirectoryNotFoundError', () {
      test('thrown when scan dir does not exist', () async {
        final nonExistent = p.join(scanRoot.path, 'does_not_exist');
        expect(
          () => scanner.scanAll(scanDirOverride: nonExistent),
          throwsA(isA<ScanDirectoryNotFoundError>()),
        );
      });

      test('error has path and message fields', () async {
        const badPath = '/tmp/definitely_not_a_real_path_xyz987';
        try {
          await scanner.scanAll(scanDirOverride: badPath);
          fail('Expected ScanDirectoryNotFoundError');
        } on ScanDirectoryNotFoundError catch (e) {
          expect(e.path, equals(badPath));
          expect(e.message, isNotEmpty);
        }
      });

      test('thrown when scanDir is empty and no override provided', () async {
        // DB config defaults to empty scanDir
        expect(
          () => scanner.scanAll(),
          throwsA(isA<ScanDirectoryNotFoundError>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    // Directory listing / filtering
    // -----------------------------------------------------------------------

    group('directory listing', () {
      test('returns empty list for empty scan dir', () async {
        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results, isEmpty);
      });

      test('ignores files at scan root level', () async {
        await File(p.join(scanRoot.path, 'some_file.txt')).writeAsString('hello');
        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results, isEmpty);
      });

      test('lists only direct child directories', () async {
        await createPlainProject(scanRoot, 'project-a');
        await createPlainProject(scanRoot, 'project-b');
        // Nested dir should not be listed directly
        final nested = Directory(p.join(scanRoot.path, 'project-a', 'subdir'));
        await nested.create(recursive: true);

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(2));
        final ids = results.map((r) => r.folderId).toSet();
        expect(ids, containsAll(['project-a', 'project-b']));
        expect(ids, isNot(contains('subdir')));
      });

      test('skips hidden directories (starting with .)', () async {
        await createPlainProject(scanRoot, 'visible-project');
        final hiddenDir = Directory(p.join(scanRoot.path, '.hidden'));
        await hiddenDir.create();

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(1));
        expect(results.first.folderId, equals('visible-project'));
      });

      test('skips directories matching ignore patterns (exact match)', () async {
        await createPlainProject(scanRoot, 'my-app');
        await createPlainProject(scanRoot, 'node_modules');

        // Ensure config row exists, then override ignore list
        await db.getConfig();
        await db.updateConfig(ignoreListJson: '["node_modules"]');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(1));
        expect(results.first.folderId, equals('my-app'));
      });

      test('skips directories matching ignore patterns (wildcard prefix *)', () async {
        await createPlainProject(scanRoot, 'my-app');
        await createPlainProject(scanRoot, 'build');
        await createPlainProject(scanRoot, 'build-cache');

        // Ensure config row exists, then override ignore list
        await db.getConfig();
        await db.updateConfig(ignoreListJson: '["build*"]');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(1));
        expect(results.first.folderId, equals('my-app'));
      });

      test('results are sorted by displayName', () async {
        await createPlainProject(scanRoot, 'zebra-project');
        await createPlainProject(scanRoot, 'alpha-project');
        await createPlainProject(scanRoot, 'mango-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        final names = results.map((r) => r.displayName).toList();
        // Plain projects use folder name as displayName
        expect(names, equals(['alpha-project', 'mango-project', 'zebra-project']));
      });
    });

    // -----------------------------------------------------------------------
    // GSD data assembly
    // -----------------------------------------------------------------------

    group('GSD data assembly', () {
      test('non-GSD project gets null gsd field', () async {
        await createPlainProject(scanRoot, 'plain-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(1));
        expect(results.first.gsd, isNull);
        expect(results.first.hasParseError, isFalse);
      });

      test('GSD project has gsd field populated', () async {
        await createGsdProject(scanRoot, 'gsd-project', status: 'building', phase: '2 of 5');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(1));
        final proj = results.first;
        expect(proj.gsd, isNotNull);
        expect(proj.gsd!.isEmpty, isFalse);
      });

      test('displayName comes from PROJECT.md H1 for GSD project', () async {
        await createGsdProject(scanRoot, 'my-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.displayName, equals('my-project'));
      });

      test('displayName falls back to folder name for non-GSD project', () async {
        await createPlainProject(scanRoot, 'folder-name');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.displayName, equals('folder-name'));
      });

      test('folderId is the folder basename', () async {
        await createPlainProject(scanRoot, 'project-folder');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.folderId, equals('project-folder'));
      });

      test('path is the absolute path to the project folder', () async {
        await createPlainProject(scanRoot, 'a-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.path, equals(p.join(scanRoot.path, 'a-project')));
      });
    });

    // -----------------------------------------------------------------------
    // Git data assembly
    // -----------------------------------------------------------------------

    group('git data assembly', () {
      test('non-git project gets null git field', () async {
        await createPlainProject(scanRoot, 'no-git-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.git, isNull);
      });

      test('git project gets git field populated', () async {
        await createGsdProject(scanRoot, 'git-project', withGit: true);

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.git, isNotNull);
        expect(results.first.git!.isEmpty, isFalse);
        expect(results.first.git!.lastCommitMessage, equals('Initial commit'));
      });
    });

    // -----------------------------------------------------------------------
    // DB project type resolution
    // -----------------------------------------------------------------------

    group('project type resolution', () {
      test('projectType is null for project with no DB settings', () async {
        await createPlainProject(scanRoot, 'untyped-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.projectType, isNull);
      });

      test('projectType is set from DB settings', () async {
        await createPlainProject(scanRoot, 'typed-project');

        await db.upsertProjectSettings(
          ProjectSettingsTableCompanion.insert(
            folderId: 'typed-project',
            projectType: const Value('code'),
          ),
        );

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.projectType, equals('code'));
      });

      test('multiple projects each get their own type from DB', () async {
        await createPlainProject(scanRoot, 'code-project');
        await createPlainProject(scanRoot, 'research-project');
        await createPlainProject(scanRoot, 'untyped-project');

        await db.upsertProjectSettings(
          ProjectSettingsTableCompanion.insert(
            folderId: 'code-project',
            projectType: const Value('code'),
          ),
        );
        await db.upsertProjectSettings(
          ProjectSettingsTableCompanion.insert(
            folderId: 'research-project',
            projectType: const Value('research'),
          ),
        );

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        final byId = {for (final r in results) r.folderId: r};

        expect(byId['code-project']!.projectType, equals('code'));
        expect(byId['research-project']!.projectType, equals('research'));
        expect(byId['untyped-project']!.projectType, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Stale detection
    // -----------------------------------------------------------------------

    group('stale detection', () {
      test('non-stale git project: recent commit returns isStale=false', () async {
        await createGsdProject(scanRoot, 'fresh-git-project', withGit: true);

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.isStale, isFalse);
      });

      test('non-git, non-GSD project with no signal is not stale', () async {
        await createPlainProject(scanRoot, 'no-signal-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.isStale, isFalse);
      });

      test('GSD project without git: recent STATE.md is not stale', () async {
        await createGsdProject(scanRoot, 'gsd-no-git');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.first.isStale, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Mix of project types
    // -----------------------------------------------------------------------

    group('mixed project types', () {
      test('scan dir with mix of GSD, git, and plain projects', () async {
        await createGsdProject(scanRoot, 'full-project', withGit: true);
        await createGsdProject(scanRoot, 'gsd-only');
        await createPlainProject(scanRoot, 'plain-project');

        final results = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results.length, equals(3));

        final byId = {for (final r in results) r.folderId: r};

        // full-project: has GSD and git
        expect(byId['full-project']!.gsd, isNotNull);
        expect(byId['full-project']!.git, isNotNull);

        // gsd-only: has GSD but no git
        expect(byId['gsd-only']!.gsd, isNotNull);
        expect(byId['gsd-only']!.git, isNull);

        // plain-project: no GSD, no git
        expect(byId['plain-project']!.gsd, isNull);
        expect(byId['plain-project']!.git, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // _FileCache: mtime-based caching
    // -----------------------------------------------------------------------

    group('_FileCache (repeated scanAll calls)', () {
      test('second scanAll() returns same results as first', () async {
        await createGsdProject(scanRoot, 'cached-project');
        await createPlainProject(scanRoot, 'plain-project');

        final results1 = await scanner.scanAll(scanDirOverride: scanRoot.path);
        final results2 = await scanner.scanAll(scanDirOverride: scanRoot.path);

        expect(results1.length, equals(results2.length));
        for (int i = 0; i < results1.length; i++) {
          expect(results1[i].folderId, equals(results2[i].folderId));
          expect(results1[i].displayName, equals(results2[i].displayName));
        }
      });

      test('scan after file content changes picks up new data', () async {
        final projDir = await createGsdProject(scanRoot, 'updating-project',
            status: 'planning');

        final results1 = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results1.first.gsd!.status, equals('planning'));

        // Modify STATE.md with a small delay to change mtime
        await Future.delayed(const Duration(milliseconds: 50));
        await File(p.join(projDir.path, '.planning', 'STATE.md'))
            .writeAsString('# Project State\n\n**Status:** done\n');

        final results2 = await scanner.scanAll(scanDirOverride: scanRoot.path);
        expect(results2.first.gsd!.status, equals('done'));
      });
    });
  });
}
