import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/gitignore_template.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_creator_service.dart';

void main() {
  group('createProject', () {
    late Directory scanDir;

    setUp(() async {
      scanDir = await Directory.systemTemp.createTemp('creator_scan_');
    });

    tearDown(() async {
      await scanDir.delete(recursive: true);
    });

    test(
      'successful scaffold creates directory, CLAUDE.md, and .gitignore',
      () async {
        final result = await createProject(
          scanDir: scanDir.path,
          folderName: 'my-new-project',
          displayName: 'My New Project',
          projectType: ProjectType.code,
          claudeMd: true,
          gitignoreTemplate: GitignoreTemplate.flutter,
        );

        final projectPath = p.join(scanDir.path, 'my-new-project');

        expect(result.success, isTrue);
        expect(result.projectPath, projectPath);
        expect(Directory(projectPath).existsSync(), isTrue);

        final claudeFile = File(p.join(projectPath, 'CLAUDE.md'));
        expect(claudeFile.existsSync(), isTrue);
        expect(await claudeFile.readAsString(), contains('My New Project'));

        final gitignoreFile = File(p.join(projectPath, '.gitignore'));
        expect(gitignoreFile.existsSync(), isTrue);
        expect(await gitignoreFile.readAsString(), contains('.dart_tool/'));
      },
    );

    test('research project type creates a placeholder README.md', () async {
      final result = await createProject(
        scanDir: scanDir.path,
        folderName: 'my-research',
        displayName: 'My Research',
        projectType: ProjectType.research,
      );

      final readme = File(p.join(scanDir.path, 'my-research', 'README.md'));
      expect(result.success, isTrue);
      expect(readme.existsSync(), isTrue);
      expect(await readme.readAsString(), contains('My Research'));
    });

    test('code project type does not create README.md', () async {
      final result = await createProject(
        scanDir: scanDir.path,
        folderName: 'code-only',
        displayName: 'Code Only',
        projectType: ProjectType.code,
      );

      expect(result.success, isTrue);
      expect(
        File(p.join(scanDir.path, 'code-only', 'README.md')).existsSync(),
        isFalse,
      );
    });

    test(
      'existing-folder guard fails without creating scaffold files',
      () async {
        final existing = Directory(p.join(scanDir.path, 'already-here'));
        await existing.create();
        await File(
          p.join(existing.path, 'marker.txt'),
        ).writeAsString('pre-existing');

        final result = await createProject(
          scanDir: scanDir.path,
          folderName: 'already-here',
          displayName: 'Already Here',
          projectType: ProjectType.code,
          claudeMd: true,
        );

        expect(result.success, isFalse);
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.first, contains('existiert bereits'));
        // Existing content must be untouched — no scaffold files added.
        expect(File(p.join(existing.path, 'CLAUDE.md')).existsSync(), isFalse);
        expect(File(p.join(existing.path, 'marker.txt')).existsSync(), isTrue);
      },
    );

    test(
      'gitInit=true runs git init and initial commit with no warnings',
      () async {
        final result = await createProject(
          scanDir: scanDir.path,
          folderName: 'with-git',
          displayName: 'With Git',
          projectType: ProjectType.code,
          gitInit: true,
          claudeMd: true,
        );

        final projectPath = p.join(scanDir.path, 'with-git');
        expect(result.success, isTrue);
        expect(Directory(p.join(projectPath, '.git')).existsSync(), isTrue);
        expect(result.warnings, isEmpty);

        final logResult = await Process.run(
          'git',
          ['log', '--oneline', '-1'],
          workingDirectory: projectPath,
          runInShell: true,
        );
        expect(logResult.stdout.toString(), contains('Initial commit'));
      },
    );

    test('gitInit=false does not create a .git directory', () async {
      final result = await createProject(
        scanDir: scanDir.path,
        folderName: 'no-git',
        displayName: 'No Git',
        projectType: ProjectType.code,
      );

      expect(result.success, isTrue);
      expect(
        Directory(p.join(scanDir.path, 'no-git', '.git')).existsSync(),
        isFalse,
      );
    });

    test('directory-creation failure returns success=false with a warning '
        '(git init is never reached)', () async {
      // Make scanDir read-only so createProject's own `dir.create()` step
      // (line 1 of its documented order) fails — a real, portable failure
      // mode, unlike trying to force git itself to fail.
      await Process.run('chmod', ['a-w', scanDir.path]);
      addTearDown(() => Process.run('chmod', ['u+w', scanDir.path]));

      final result = await createProject(
        scanDir: scanDir.path,
        folderName: 'blocked-project',
        displayName: 'Blocked Project',
        projectType: ProjectType.code,
        gitInit: true,
      );

      expect(result.success, isFalse);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.first,
        contains('Ordner konnte nicht erstellt werden'),
      );
    }, testOn: '!windows');
  });
}
