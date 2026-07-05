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

      // Strategy 1: exact encoded path match. If this directory exists at
      // all, it is unambiguously "the" Claude project dir for this project —
      // return its sessions (possibly none) without falling back to the
      // fuzzy match, which could otherwise pick up an unrelated project's
      // sessions just because this one happens to have no .jsonl files yet.
      final exactDir = Directory(p.join(projectsDir, encodedPath));
      if (await exactDir.exists()) {
        return ProjectSessionData(sessions: await _readSessionsAt(exactDir));
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
  /// [messageCount]. Streams the file line by line (rather than loading it
  /// fully into memory via `readAsLines`) since session files can grow large
  /// (observed 1000+ lines in real usage). Skips malformed lines — never
  /// throws. The inoffizielle JSONL format varies by `type` field (user,
  /// assistant, system, attachment, etc.); only `user`/`assistant` lines with
  /// a `timestamp` field count toward [messageCount] and [startedAt].
  Future<SessionInfo> readSessionDetail(SessionInfo session) async {
    try {
      final file = File(session.path);
      if (!await file.exists()) return session;

      DateTime? startedAt;
      int messageCount = 0;
      String? model;
      // Insertion-ordered sets to keep first-seen order and de-duplicate.
      final skills = <String>{};
      final subagents = <String>{};
      String? lastActivityText;

      // Token usage estimate (AD-4) — summed across all assistant `usage`
      // blocks. `sawUsage` tracks whether the log carried usage at all, so a
      // log with none reports null tokens (not a misleading 0).
      var inputTokens = 0;
      var outputTokens = 0;
      var cacheTokens = 0;
      var sawUsage = false;

      final lineStream = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is! Map<String, dynamic>) continue;

          final type = decoded['type'] as String?;
          if (type != 'user' && type != 'assistant') continue;

          messageCount++;

          final message = decoded['message'];
          if (message is Map<String, dynamic>) {
            // Model is recorded on assistant lines under `message.model`.
            final m = message['model'];
            if (m is String && m.isNotEmpty) model = m;

            // Token usage estimate (AD-4). Present only on assistant lines,
            // and only when the log recorded it — read defensively.
            final usage = message['usage'];
            if (usage is Map<String, dynamic>) {
              sawUsage = true;
              inputTokens += _asInt(usage['input_tokens']);
              outputTokens += _asInt(usage['output_tokens']);
              cacheTokens += _asInt(usage['cache_creation_input_tokens']);
              cacheTokens += _asInt(usage['cache_read_input_tokens']);
            }

            _extractFromContent(
              message['content'],
              skills: skills,
              subagents: subagents,
              onText: (text) => lastActivityText = text,
            );
          }

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

      return session.withDetail(
        startedAt: startedAt,
        messageCount: messageCount,
        model: model,
        skills: skills.toList(),
        subagents: subagents.toList(),
        lastActivityText: lastActivityText,
        inputTokens: sawUsage ? inputTokens : null,
        outputTokens: sawUsage ? outputTokens : null,
        cacheTokens: sawUsage ? cacheTokens : null,
      );
    } catch (e) {
      developer.log('Failed to read session detail for ${session.path}: $e', name: 'session_reader');
      return session;
    }
  }

  /// Inspects a message `content` field (which may be a plain string or a list
  /// of content blocks) and pulls out skill invocations, subagent spawns, and
  /// the latest textual snippet. Never throws — unknown shapes are ignored, in
  /// line with AD-1 (parser tolerates arbitrary JSONL variants).
  void _extractFromContent(
    Object? content, {
    required Set<String> skills,
    required Set<String> subagents,
    required void Function(String) onText,
  }) {
    if (content is String) {
      final snippet = _snippet(content);
      if (snippet != null) onText(snippet);
      return;
    }
    if (content is! List) return;

    for (final block in content) {
      if (block is! Map<String, dynamic>) continue;
      final blockType = block['type'] as String?;

      if (blockType == 'text') {
        final snippet = _snippet(block['text']);
        if (snippet != null) onText(snippet);
      } else if (blockType == 'tool_use') {
        final name = block['name'] as String?;
        final input = block['input'];
        if (input is! Map<String, dynamic>) continue;

        if (name == 'Skill') {
          final skill = input['skill'];
          if (skill is String && skill.isNotEmpty) skills.add(skill);
        } else if (name == 'Agent' || name == 'Task') {
          final subagentType = input['subagent_type'];
          if (subagentType is String && subagentType.isNotEmpty) {
            subagents.add(subagentType);
          }
        }
      }
    }
  }

  /// Coerces a JSON usage value to a non-negative int, tolerating ints,
  /// doubles, numeric strings, and nulls (all unknown shapes → 0). Keeps the
  /// token summation defensive per AD-4 (usage fields are often missing or
  /// vary in type across log versions).
  int _asInt(Object? value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value < 0 ? 0 : value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return (parsed == null || parsed < 0) ? 0 : parsed;
    }
    return 0;
  }

  /// Trims and truncates a text snippet for the last-activity preview.
  /// Returns null for empty/whitespace-only input.
  String? _snippet(Object? text) {
    if (text is! String) return null;
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return null;
    const maxLen = 140;
    return collapsed.length <= maxLen
        ? collapsed
        : '${collapsed.substring(0, maxLen)}…';
  }
}
