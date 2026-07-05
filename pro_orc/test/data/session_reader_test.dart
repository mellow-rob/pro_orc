import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/data/services/memory_reader.dart' show encodeProjectPath;
import 'package:pro_orc/data/services/session_reader.dart';

void main() {
  group('SessionReader', () {
    group('readProjectSessions', () {
      test('finds sessions via exact encoded path match', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/test-project';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await projectDir.create(recursive: true);
        await File(p.join(projectDir.path, 'session-abc.jsonl'))
            .writeAsString('{"type":"user","timestamp":"2026-01-01T00:00:00Z"}\n');

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions, hasLength(1));
        expect(result.sessions.first.id, 'session-abc');
      });

      test('finds sessions via fuzzy suffix match (dotted project name)', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/n3ural.a1';
        // Simulate Claude's actual dir naming inconsistency: a longer
        // encoded prefix than a naive encode would produce, but still
        // ending with the encoded project basename.
        final encodedName = encodeProjectPath('n3ural.a1');
        final actualDirName = '-Users-rob-code-$encodedName';
        final projectDir = Directory(p.join(claudeHome.path, 'projects', actualDirName));
        await projectDir.create(recursive: true);
        await File(p.join(projectDir.path, 'sess-1.jsonl')).writeAsString('{}\n');

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions, hasLength(1));
      });

      test('returns empty when no matching Claude project directory exists',
          () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions('/Users/rob/code/nope');

        expect(result.sessions, isEmpty);
        expect(result.hasActiveSession, isFalse);
      });

      test(
          'does not fall back to fuzzy match when the exact encoded dir exists '
          'but has no sessions yet (code review MINOR fix)', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/empty-exact-dir';
        final encoded = encodeProjectPath(projectPath);

        // Exact dir exists (e.g. only a memory/ subfolder, no sessions yet).
        final exactDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await exactDir.create(recursive: true);

        // A differently-named dir that merely happens to end with the same
        // encoded suffix — must NOT be picked up now that the exact dir exists.
        final decoyDir = Directory(
          p.join(claudeHome.path, 'projects', '-Users-rob-other-parent-$encoded'),
        );
        await decoyDir.create(recursive: true);
        await File(p.join(decoyDir.path, 'decoy-session.jsonl')).writeAsString('{}\n');

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions, isEmpty);
      });

      test('returns empty for nonexistent claudeHome (never throws)', () async {
        final reader = SessionReader(
          claudeHomeDirOverride: '/tmp/nonexistent_claude_home_xyz_999',
        );
        final result = await reader.readProjectSessions('/Users/rob/code/whatever');

        expect(result.sessions, isEmpty);
      });

      test('ignores non-.jsonl files in the project directory', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/mixed-files';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await projectDir.create(recursive: true);
        await File(p.join(projectDir.path, 'session.jsonl')).writeAsString('{}\n');
        await Directory(p.join(projectDir.path, 'memory')).create();
        await File(p.join(projectDir.path, 'settings.json')).writeAsString('{}');

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions, hasLength(1));
        expect(result.sessions.first.id, 'session');
      });

      test('marks a recently modified session as active', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/active-session-project';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await projectDir.create(recursive: true);
        await File(p.join(projectDir.path, 'fresh.jsonl')).writeAsString('{}\n');

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions.first.isActive, isTrue);
        expect(result.hasActiveSession, isTrue);
      });

      test('marks an old session as inactive', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/stale-session-project';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await projectDir.create(recursive: true);
        final sessionFile = File(p.join(projectDir.path, 'old.jsonl'));
        await sessionFile.writeAsString('{}\n');

        final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
        await Process.run('touch', ['-t', _touchFormat(tenMinutesAgo), sessionFile.path]);

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions.first.isActive, isFalse);
        expect(result.hasActiveSession, isFalse);
      });

      test('sorts sessions by lastActivity descending', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/multi-session-project';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await projectDir.create(recursive: true);

        final older = File(p.join(projectDir.path, 'older.jsonl'));
        await older.writeAsString('{}\n');
        await Process.run(
          'touch',
          ['-t', _touchFormat(DateTime.now().subtract(const Duration(hours: 2))), older.path],
        );

        final newer = File(p.join(projectDir.path, 'newer.jsonl'));
        await newer.writeAsString('{}\n');

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions, hasLength(2));
        expect(result.sessions.first.id, 'newer');
        expect(result.sessions.last.id, 'older');
      });

      test('recentFive caps at 5 even with more sessions', () async {
        final claudeHome = await Directory.systemTemp.createTemp('claude_home_');
        addTearDown(() => claudeHome.delete(recursive: true));

        final projectPath = '/Users/rob/code/many-sessions-project';
        final encoded = encodeProjectPath(projectPath);
        final projectDir = Directory(p.join(claudeHome.path, 'projects', encoded));
        await projectDir.create(recursive: true);

        for (var i = 0; i < 8; i++) {
          await File(p.join(projectDir.path, 'sess-$i.jsonl')).writeAsString('{}\n');
        }

        final reader = SessionReader(claudeHomeDirOverride: claudeHome.path);
        final result = await reader.readProjectSessions(projectPath);

        expect(result.sessions, hasLength(8));
        expect(result.recentFive, hasLength(5));
      });
    });

    group('readSessionDetail', () {
      test('counts user/assistant messages and finds earliest timestamp',
          () async {
        final tempDir = await Directory.systemTemp.createTemp('session_detail_');
        addTearDown(() => tempDir.delete(recursive: true));

        final file = File(p.join(tempDir.path, 'sess.jsonl'));
        await file.writeAsString([
          '{"type":"last-prompt","sessionId":"x"}',
          '{"type":"user","timestamp":"2026-01-01T10:00:00Z"}',
          '{"type":"assistant","timestamp":"2026-01-01T10:00:05Z"}',
          '{"type":"user","timestamp":"2026-01-01T09:59:00Z"}',
          '{"type":"file-history-snapshot","messageId":"y"}',
        ].join('\n'));

        final baseSession = SessionInfo(
          id: 'sess',
          path: file.path,
          lastActivity: DateTime.now(),
          isActive: true,
        );

        final reader = SessionReader();
        final detail = await reader.readSessionDetail(baseSession);

        expect(detail.messageCount, 3);
        expect(detail.startedAt, DateTime.parse('2026-01-01T09:59:00Z'));
      });

      test('skips malformed lines without throwing', () async {
        final tempDir = await Directory.systemTemp.createTemp('session_detail_bad_');
        addTearDown(() => tempDir.delete(recursive: true));

        final file = File(p.join(tempDir.path, 'sess.jsonl'));
        await file.writeAsString([
          '{"type":"user","timestamp":"2026-01-01T10:00:00Z"}',
          'not even json {{{',
          '{"type":"assistant","timestamp":"2026-01-01T10:00:05Z"}',
        ].join('\n'));

        final baseSession = SessionInfo(
          id: 'sess',
          path: file.path,
          lastActivity: DateTime.now(),
          isActive: true,
        );

        final reader = SessionReader();
        final detail = await reader.readSessionDetail(baseSession);

        expect(detail.messageCount, 2);
      });

      test('returns the session unchanged if the file no longer exists', () async {
        final missing = SessionInfo(
          id: 'gone',
          path: '/tmp/nonexistent_session_file_xyz.jsonl',
          lastActivity: DateTime.now(),
          isActive: false,
        );

        final reader = SessionReader();
        final detail = await reader.readSessionDetail(missing);

        expect(detail.messageCount, isNull);
        expect(detail.startedAt, isNull);
      });
    });
  });
}

/// Formats a DateTime for the macOS `touch -t` command (YYYYMMDDhhmm.ss).
String _touchFormat(DateTime dt) {
  return '${dt.year}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '.${dt.second.toString().padLeft(2, '0')}';
}
