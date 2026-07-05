import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/services/memory_reader.dart';

void main() {
  group('MemoryReader', () {
    group('encodeProjectPath', () {
      test('converts absolute path to dash-separated format', () {
        expect(
          encodeProjectPath('/Users/rob/code/foo'),
          equals('-Users-rob-code-foo'),
        );
      });

      test('converts root path to single dash', () {
        expect(encodeProjectPath('/'), equals('-'));
      });

      test('replaces spaces with dashes (matching Claude behavior)', () {
        expect(
          encodeProjectPath('/Users/rob/code/my project'),
          equals('-Users-rob-code-my-project'),
        );
      });

      test('replaces dots with dashes (matching Claude behavior)', () {
        expect(
          encodeProjectPath('/Users/rob/code/n3ural.a1'),
          equals('-Users-rob-code-n3ural-a1'),
        );
      });
    });

    group('readMemoryData', () {
      test('returns hasMemory=true when MEMORY.md exists', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/test-project';
        final encoded = encodeProjectPath(projectPath);
        final memoryDir = Directory(
          p.join(claudeHome.path, 'projects', encoded, 'memory'),
        );
        await memoryDir.create(recursive: true);
        await File(p.join(memoryDir.path, 'MEMORY.md'))
            .writeAsString('# Memory\nSome consolidated content.');

        final result = await readMemoryData(
          projectPath,
          claudeHomeDirOverride: claudeHome.path,
        );

        expect(result.hasMemory, isTrue);
        expect(result.lastConsolidated, isNotNull);
        expect(result.isStale, isFalse);
      });

      test('returns hasMemory=false when no memory dir exists', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final result = await readMemoryData(
          '/Users/rob/code/no-memory-project',
          claudeHomeDirOverride: claudeHome.path,
        );

        expect(result.hasMemory, isFalse);
        expect(result.lastConsolidated, isNull);
        expect(result.isStale, isFalse);
      });

      test('returns hasMemory=false when project dir exists but no MEMORY.md', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/partial-project';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(
          p.join(claudeHome.path, 'projects', encoded),
        );
        await projectDir.create(recursive: true);

        final result = await readMemoryData(
          projectPath,
          claudeHomeDirOverride: claudeHome.path,
        );

        expect(result.hasMemory, isFalse);
        expect(result.lastConsolidated, isNull);
      });

      test('returns isStale=true when MEMORY.md is older than 7 days', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/stale-project';
        final encoded = encodeProjectPath(projectPath);
        final memoryDir = Directory(
          p.join(claudeHome.path, 'projects', encoded, 'memory'),
        );
        await memoryDir.create(recursive: true);
        final memoryFile = File(p.join(memoryDir.path, 'MEMORY.md'));
        await memoryFile.writeAsString('# Old memory');

        // Set mtime to 10 days ago
        final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
        await Process.run('touch', [
          '-t',
          _formatTouchDate(tenDaysAgo),
          memoryFile.path,
        ]);

        final result = await readMemoryData(
          projectPath,
          claudeHomeDirOverride: claudeHome.path,
        );

        expect(result.hasMemory, isTrue);
        expect(result.lastConsolidated, isNotNull);
        expect(result.isStale, isTrue);
      });

      test('finds memory for a project with a dot in its name (fuzzy match)',
          () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/n3ural.a1';
        final encoded = encodeProjectPath(projectPath);
        final memoryDir = Directory(
          p.join(claudeHome.path, 'projects', encoded, 'memory'),
        );
        await memoryDir.create(recursive: true);
        await File(p.join(memoryDir.path, 'MEMORY.md'))
            .writeAsString('# Memory\nDotted project name.');

        final result = await readMemoryData(
          projectPath,
          claudeHomeDirOverride: claudeHome.path,
        );

        expect(result.hasMemory, isTrue);
      });

      test('returns MemoryData.empty for nonexistent claudeHome', () async {
        final result = await readMemoryData(
          '/Users/rob/code/whatever',
          claudeHomeDirOverride: '/tmp/nonexistent_claude_home_xyz_999',
        );

        expect(result.hasMemory, isFalse);
        expect(result.lastConsolidated, isNull);
        expect(result.isStale, isFalse);
      });
    });
  });
}

/// Formats a DateTime for the macOS `touch -t` command (YYYYMMDDhhmm.ss).
String _formatTouchDate(DateTime dt) {
  return '${dt.year}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '.${dt.second.toString().padLeft(2, '0')}';
}
