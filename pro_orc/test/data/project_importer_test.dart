import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/gitignore_template.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_importer_service.dart';

void main() {
  // -------------------------------------------------------------------------
  // inferProjectType
  // -------------------------------------------------------------------------

  group('inferProjectType', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('importer_type_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('folder with pubspec.yaml -> code', () async {
      await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('name: x');
      expect(await inferProjectType(tempDir.path), ProjectType.code);
    });

    test('folder with package.json -> code', () async {
      await File(p.join(tempDir.path, 'package.json')).writeAsString('{}');
      expect(await inferProjectType(tempDir.path), ProjectType.code);
    });

    test('folder with Cargo.toml -> code', () async {
      await File(p.join(tempDir.path, 'Cargo.toml')).writeAsString('[package]');
      expect(await inferProjectType(tempDir.path), ProjectType.code);
    });

    test('empty folder -> research', () async {
      expect(await inferProjectType(tempDir.path), ProjectType.research);
    });

    test('folder with lib/ subdir -> code', () async {
      await Directory(p.join(tempDir.path, 'lib')).create();
      expect(await inferProjectType(tempDir.path), ProjectType.code);
    });

    test('folder with src/ subdir -> code', () async {
      await Directory(p.join(tempDir.path, 'src')).create();
      expect(await inferProjectType(tempDir.path), ProjectType.code);
    });

    test('monorepo with nested pubspec.yaml -> code', () async {
      final sub = Directory(p.join(tempDir.path, 'my_app'));
      await sub.create();
      await File(p.join(sub.path, 'pubspec.yaml')).writeAsString('name: y');
      expect(await inferProjectType(tempDir.path), ProjectType.code);
    });

    test('folder with only markdown files -> research', () async {
      await File(p.join(tempDir.path, 'README.md')).writeAsString('# Hi');
      await File(p.join(tempDir.path, 'notes.md')).writeAsString('notes');
      expect(await inferProjectType(tempDir.path), ProjectType.research);
    });
  });

  // -------------------------------------------------------------------------
  // analyzeFolder
  // -------------------------------------------------------------------------

  group('analyzeFolder', () {
    late Directory tempDir;
    late String scanDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('importer_analyze_');
      scanDir = tempDir.path;
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('detects hasGit when .git exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'my-project'));
      await projectDir.create();
      await Directory(p.join(projectDir.path, '.git')).create();

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.hasGit, isTrue);
    });

    test('detects no git when .git missing', () async {
      final projectDir = Directory(p.join(tempDir.path, 'no-git'));
      await projectDir.create();

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.hasGit, isFalse);
    });

    test('detects hasPlanning when .planning/ exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'gsd-project'));
      await projectDir.create();
      await Directory(p.join(projectDir.path, '.planning')).create();

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.hasPlanning, isTrue);
    });

    test('detects hasClaudeMd when CLAUDE.md exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'claude-project'));
      await projectDir.create();
      await File(p.join(projectDir.path, 'CLAUDE.md')).writeAsString('# C');

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.hasClaudeMd, isTrue);
    });

    test('detects hasGitignore when .gitignore exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'gi-project'));
      await projectDir.create();
      await File(p.join(projectDir.path, '.gitignore')).writeAsString('*.log');

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.hasGitignore, isTrue);
    });

    test('detectedType uses inferProjectType', () async {
      final projectDir = Directory(p.join(tempDir.path, 'code-project'));
      await projectDir.create();
      await File(p.join(projectDir.path, 'pubspec.yaml')).writeAsString('x');

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.detectedType, ProjectType.code);
    });

    test('folderName is basename of path', () async {
      final projectDir = Directory(p.join(tempDir.path, 'my-folder'));
      await projectDir.create();

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.folderName, 'my-folder');
    });

    test('isInsideScanDir true when inside scan dir', () async {
      final projectDir = Directory(p.join(tempDir.path, 'inside'));
      await projectDir.create();

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.isInsideScanDir, isTrue);
      expect(analysis.containingScanDir, scanDir);
    });

    test('isInsideScanDir false when outside all scan dirs', () async {
      final otherDir = await Directory.systemTemp.createTemp('other_');
      addTearDown(() => otherDir.delete(recursive: true));

      final analysis = await analyzeFolder(otherDir.path, [scanDir]);
      expect(analysis.isInsideScanDir, isFalse);
      expect(analysis.containingScanDir, isNull);
    });

    test('isInsideScanDir handles trailing slashes', () async {
      final projectDir = Directory(p.join(tempDir.path, 'trail'));
      await projectDir.create();

      final analysis = await analyzeFolder(
        projectDir.path,
        ['$scanDir/'], // trailing slash
      );
      expect(analysis.isInsideScanDir, isTrue);
    });

    test('complete analysis for empty folder', () async {
      final projectDir = Directory(p.join(tempDir.path, 'empty'));
      await projectDir.create();

      final analysis = await analyzeFolder(projectDir.path, [scanDir]);
      expect(analysis.hasGit, isFalse);
      expect(analysis.hasPlanning, isFalse);
      expect(analysis.hasClaudeMd, isFalse);
      expect(analysis.hasGitignore, isFalse);
      expect(analysis.detectedType, ProjectType.research);
    });
  });

  // -------------------------------------------------------------------------
  // scaffoldProject
  // -------------------------------------------------------------------------

  group('scaffoldProject', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('importer_scaffold_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates .planning/ skeleton when gsdSkeleton=true and missing',
        () async {
      final projectDir = Directory(p.join(tempDir.path, 'new-project'));
      await projectDir.create();

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'New Project',
        gsdSkeleton: true,
      );

      expect(result.created, isNotEmpty);
      expect(
        Directory(p.join(projectDir.path, '.planning')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectDir.path, '.planning', 'PROJECT.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectDir.path, '.planning', 'STATE.md')).existsSync(),
        isTrue,
      );
    });

    test('skips .planning/ when already exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'existing-gsd'));
      await projectDir.create();
      final planningDir = Directory(p.join(projectDir.path, '.planning'));
      await planningDir.create();
      await File(p.join(planningDir.path, 'STATE.md'))
          .writeAsString('existing');

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'Existing',
        gsdSkeleton: true,
      );

      // Should not have created .planning files
      expect(result.created.where((f) => f.contains('.planning')), isEmpty);
      // Original content preserved
      final content =
          await File(p.join(planningDir.path, 'STATE.md')).readAsString();
      expect(content, 'existing');
    });

    test('creates CLAUDE.md when claudeMd=true and missing', () async {
      final projectDir = Directory(p.join(tempDir.path, 'no-claude'));
      await projectDir.create();

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'No Claude',
        claudeMd: true,
      );

      expect(result.created, contains('CLAUDE.md'));
      expect(
        File(p.join(projectDir.path, 'CLAUDE.md')).existsSync(),
        isTrue,
      );
    });

    test('skips CLAUDE.md when already exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'has-claude'));
      await projectDir.create();
      await File(p.join(projectDir.path, 'CLAUDE.md'))
          .writeAsString('original');

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'Has Claude',
        claudeMd: true,
      );

      expect(result.created.where((f) => f.contains('CLAUDE.md')), isEmpty);
      final content =
          await File(p.join(projectDir.path, 'CLAUDE.md')).readAsString();
      expect(content, 'original');
    });

    test('creates .gitignore from template when missing', () async {
      final projectDir = Directory(p.join(tempDir.path, 'no-gi'));
      await projectDir.create();

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'No GI',
        gitignoreTemplate: GitignoreTemplate.flutter,
      );

      expect(result.created, contains('.gitignore'));
      final content =
          await File(p.join(projectDir.path, '.gitignore')).readAsString();
      expect(content, contains('.dart_tool/'));
    });

    test('skips .gitignore when already exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'has-gi'));
      await projectDir.create();
      await File(p.join(projectDir.path, '.gitignore'))
          .writeAsString('my-rules');

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'Has GI',
        gitignoreTemplate: GitignoreTemplate.nodejs,
      );

      expect(result.created.where((f) => f.contains('.gitignore')), isEmpty);
      final content =
          await File(p.join(projectDir.path, '.gitignore')).readAsString();
      expect(content, 'my-rules');
    });

    test('runs git init when gitInit=true and .git missing', () async {
      final projectDir = Directory(p.join(tempDir.path, 'no-git'));
      await projectDir.create();
      await File(p.join(projectDir.path, 'README.md')).writeAsString('# Hi');

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'No Git',
        gitInit: true,
      );

      expect(Directory(p.join(projectDir.path, '.git')).existsSync(), isTrue);
      // No files created by scaffold, but git init happened
      expect(result.warnings, isEmpty);
    });

    test('skips git init when .git already exists', () async {
      final projectDir = Directory(p.join(tempDir.path, 'has-git'));
      await projectDir.create();
      // Pre-init git
      await Process.run('git', ['init'],
          workingDirectory: projectDir.path, runInShell: true);

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'Has Git',
        gitInit: true,
      );

      // Should not have any git-related warnings
      expect(result.warnings, isEmpty);
    });

    test('auto-commits when files created and git available', () async {
      final projectDir = Directory(p.join(tempDir.path, 'auto-commit'));
      await projectDir.create();
      // Pre-init git with config
      await Process.run('git', ['init'],
          workingDirectory: projectDir.path, runInShell: true);
      await Process.run('git', ['config', 'user.email', 'test@test.com'],
          workingDirectory: projectDir.path, runInShell: true);
      await Process.run('git', ['config', 'user.name', 'Test'],
          workingDirectory: projectDir.path, runInShell: true);

      await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'Auto Commit',
        claudeMd: true,
        gsdSkeleton: true,
      );

      // Verify commit was made
      final logResult = await Process.run('git', ['log', '--oneline', '-1'],
          workingDirectory: projectDir.path, runInShell: true);
      expect(logResult.stdout.toString(), contains('scaffold'));
    });

    test('does not commit when no files created', () async {
      final projectDir = Directory(p.join(tempDir.path, 'no-commit'));
      await projectDir.create();
      // Pre-create everything
      await Directory(p.join(projectDir.path, '.planning')).create();
      await File(p.join(projectDir.path, 'CLAUDE.md')).writeAsString('x');
      // Init git
      await Process.run('git', ['init'],
          workingDirectory: projectDir.path, runInShell: true);
      await Process.run('git', ['config', 'user.email', 'test@test.com'],
          workingDirectory: projectDir.path, runInShell: true);
      await Process.run('git', ['config', 'user.name', 'Test'],
          workingDirectory: projectDir.path, runInShell: true);
      await Process.run('git', ['add', '.'],
          workingDirectory: projectDir.path, runInShell: true);
      await Process.run('git', ['commit', '-m', 'init'],
          workingDirectory: projectDir.path, runInShell: true);

      await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'No Commit',
        claudeMd: true,
        gsdSkeleton: true,
      );

      // Should still only have one commit
      final logResult = await Process.run(
          'git', ['rev-list', '--count', 'HEAD'],
          workingDirectory: projectDir.path, runInShell: true);
      expect(logResult.stdout.toString().trim(), '1');
    });

    test('does not commit when git is not available', () async {
      final projectDir = Directory(p.join(tempDir.path, 'no-git-avail'));
      await projectDir.create();

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'No Git',
        claudeMd: true,
      );

      // File created but no git commit (no .git dir)
      expect(result.created, contains('CLAUDE.md'));
      expect(
        Directory(p.join(projectDir.path, '.git')).existsSync(),
        isFalse,
      );
    });

    test('returns empty created list when all options false', () async {
      final projectDir = Directory(p.join(tempDir.path, 'noop'));
      await projectDir.create();

      final result = await scaffoldProject(
        projectPath: projectDir.path,
        displayName: 'Noop',
      );

      expect(result.created, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
}
