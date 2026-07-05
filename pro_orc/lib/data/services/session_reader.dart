import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/data/services/memory_reader.dart' show encodeProjectPath;

/// A session is considered "active" if its `.jsonl` file was modified within
/// this window.
const _activeThreshold = Duration(minutes: 5);

/// Reads Claude Code session metadata for a project from
/// `~/.claude/projects/<encoded>/<session-id>.jsonl`.
///
/// No Flutter imports — pure Dart, safe for isolates and unit tests.
///
/// Reuses the same path-encoding fuzzy-match strategy as [readMemoryData]
/// (memory_reader.dart) since Claude creates project directories with the
/// same inconsistent naming for both memory and session storage: exact
/// encoded match first, then a fuzzy suffix match bounded by a length
/// constraint to avoid picking up an unrelated parent project's directory.
///
/// Performance: [readProjectSessions] only stats `.jsonl` files (cheap) — it
/// never parses JSONL content. Content parsing (message count, start time)
/// is done lazily per-session via [readSessionDetail], intended to be called
/// only when a session's detail is actually shown (e.g. expanding a row in
/// the project detail panel).
class SessionReader {
  final String? claudeHomeDirOverride;

  const SessionReader({this.claudeHomeDirOverride});

  /// Scans for session files belonging to [projectPath] and returns cheap
  /// metadata (id, path, lastActivity, isActive) for each, sorted by
  /// [SessionInfo.lastActivity] descending. Returns
  /// [ProjectSessionData.empty] if no matching Claude project directory is
  /// found or on any error.
  Future<ProjectSessionData> readProjectSessions(String projectPath) async {
    try {
      final claudeHome = claudeHomeDirOverride ??
          p.join(Platform.environment['HOME']!, '.claude');
      final projectsDir = p.join(claudeHome, 'projects');
      final encodedPath = encodeProjectPath(projectPath);

      // Strategy 1: exact encoded path match.
      final exactDir = Directory(p.join(projectsDir, encodedPath));
      if (await exactDir.exists()) {
        final sessions = await _readSessionsAt(exactDir);
        if (sessions.isNotEmpty) return ProjectSessionData(sessions: sessions);
      }

      // Strategy 2: fuzzy suffix match, bounded by length (mirrors
      // readMemoryData's approach for the same directory-naming quirks).
      final projectsDirEntity = Directory(projectsDir);
      if (!await projectsDirEntity.exists()) return ProjectSessionData.empty;

      final encodedName = encodeProjectPath(p.basename(projectPath));
      final maxDirLen = encodedPath.length + 10;

      await for (final entity in projectsDirEntity.list()) {
        if (entity is! Directory) continue;
        final dirName = p.basename(entity.path);
        if (!dirName.endsWith(encodedName)) continue;
        if (dirName.length > maxDirLen) continue;

        final sessions = await _readSessionsAt(entity);
        if (sessions.isNotEmpty) return ProjectSessionData(sessions: sessions);
      }

      return ProjectSessionData.empty;
    } catch (e) {
      developer.log('Failed to read sessions for $projectPath: $e', name: 'session_reader');
      return ProjectSessionData.empty;
    }
  }

  /// Lists `*.jsonl` files directly inside [dir] (non-recursive) and builds
  /// cheap [SessionInfo] entries from file stats only.
  Future<List<SessionInfo>> _readSessionsAt(Directory dir) async {
    final result = <SessionInfo>[];

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.jsonl')) continue;

      try {
        final stat = await entity.stat();
        final lastActivity = stat.modified;
        result.add(SessionInfo(
          id: name.substring(0, name.length - '.jsonl'.length),
          path: entity.path,
          lastActivity: lastActivity,
          isActive: DateTime.now().difference(lastActivity) < _activeThreshold,
        ));
      } catch (e) {
        developer.log('Failed to stat session file ${entity.path}: $e', name: 'session_reader');
      }
    }

    result.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return result;
  }

  /// Lazily parses [session]'s JSONL content to fill in [startedAt] and
  /// [messageCount]. Parses line by line, skipping malformed lines — never
  /// throws. The inoffizielle JSONL format varies by `type` field (user,
  /// assistant, system, attachment, etc.); only `user`/`assistant` lines with
  /// a `timestamp` field count toward [messageCount] and [startedAt].
  Future<SessionInfo> readSessionDetail(SessionInfo session) async {
    try {
      final file = File(session.path);
      if (!await file.exists()) return session;

      final lines = await file.readAsLines();
      DateTime? startedAt;
      int messageCount = 0;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is! Map<String, dynamic>) continue;

          final type = decoded['type'] as String?;
          if (type != 'user' && type != 'assistant') continue;

          messageCount++;

          final tsRaw = decoded['timestamp'] as String?;
          if (tsRaw == null) continue;
          final ts = DateTime.tryParse(tsRaw);
          if (ts == null) continue;

          if (startedAt == null || ts.isBefore(startedAt)) {
            startedAt = ts;
          }
        } catch (e) {
          // Malformed line — skip, never let one bad line abort the scan.
          developer.log('Skipping malformed session line in ${session.path}: $e', name: 'session_reader');
        }
      }

      return session.withDetail(startedAt: startedAt, messageCount: messageCount);
    } catch (e) {
      developer.log('Failed to read session detail for ${session.path}: $e', name: 'session_reader');
      return session;
    }
  }
}
