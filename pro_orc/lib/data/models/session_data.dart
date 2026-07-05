/// Metadata for a single Claude Code session file
/// (`~/.claude/projects/<encoded>/<session-id>.jsonl`).
///
/// Cheap fields (id, path, lastActivity, isActive) are populated from a file
/// stat alone — no JSONL parsing required. [messageCount] and [startedAt]
/// require reading the file content and are only populated when the caller
/// explicitly asks for full detail (see `SessionReader.readSessionDetail`).
class SessionInfo {
  /// Filename without `.jsonl` extension.
  final String id;

  /// Absolute path to the `.jsonl` file.
  final String path;

  /// Last-modified time of the file — used as the "last activity" signal.
  /// Cheap to obtain (file stat only), always populated.
  final DateTime lastActivity;

  /// True if [lastActivity] is less than 5 minutes old.
  final bool isActive;

  /// Timestamp of the first parsed message, if content was read. Null when
  /// only a cheap stat-based scan was performed.
  final DateTime? startedAt;

  /// Rough count of `user` + `assistant` message lines. Null when only a
  /// cheap stat-based scan was performed.
  final int? messageCount;

  const SessionInfo({
    required this.id,
    required this.path,
    required this.lastActivity,
    required this.isActive,
    this.startedAt,
    this.messageCount,
  });

  /// Returns a copy with detail fields ([startedAt], [messageCount]) filled in.
  SessionInfo withDetail({DateTime? startedAt, int? messageCount}) {
    return SessionInfo(
      id: id,
      path: path,
      lastActivity: lastActivity,
      isActive: isActive,
      startedAt: startedAt ?? this.startedAt,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

/// Aggregated session data for a project — used by [SessionReader].
class ProjectSessionData {
  /// All discovered sessions, sorted by [SessionInfo.lastActivity] descending
  /// (most recent first).
  final List<SessionInfo> sessions;

  const ProjectSessionData({this.sessions = const []});

  static const empty = ProjectSessionData();

  /// True if any session's [SessionInfo.isActive] is true.
  bool get hasActiveSession => sessions.any((s) => s.isActive);

  /// The most recent 5 sessions (already sorted descending).
  List<SessionInfo> get recentFive => sessions.take(5).toList();
}
