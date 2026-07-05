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

  /// The model id last seen on an `assistant` line (e.g. `claude-opus-4-8`),
  /// if the log recorded one. Null when detail was not parsed or no model
  /// appeared in the log.
  final String? model;

  /// Skills invoked in this session (via the `Skill` tool), in first-seen
  /// order, de-duplicated. Empty when detail was not parsed or none were
  /// invoked.
  final List<String> skills;

  /// Subagents spawned in this session (via the `Agent` tool), identified by
  /// their `subagent_type`, in first-seen order, de-duplicated. Empty when
  /// detail was not parsed or none were spawned.
  final List<String> subagents;

  /// Short excerpt of the most recent parsed user/assistant text, if any —
  /// used as a "last activity" preview. Null when detail was not parsed or no
  /// textual content was found.
  final String? lastActivityText;

  const SessionInfo({
    required this.id,
    required this.path,
    required this.lastActivity,
    required this.isActive,
    this.startedAt,
    this.messageCount,
    this.model,
    this.skills = const [],
    this.subagents = const [],
    this.lastActivityText,
  });

  /// Returns a copy with detail fields filled in. All parameters are additive:
  /// omitted arguments preserve the existing value.
  SessionInfo withDetail({
    DateTime? startedAt,
    int? messageCount,
    String? model,
    List<String>? skills,
    List<String>? subagents,
    String? lastActivityText,
  }) {
    return SessionInfo(
      id: id,
      path: path,
      lastActivity: lastActivity,
      isActive: isActive,
      startedAt: startedAt ?? this.startedAt,
      messageCount: messageCount ?? this.messageCount,
      model: model ?? this.model,
      skills: skills ?? this.skills,
      subagents: subagents ?? this.subagents,
      lastActivityText: lastActivityText ?? this.lastActivityText,
    );
  }

  /// Equality based on [path] + [lastActivity] — sufficient to distinguish
  /// sessions and to detect a stale cache entry after a file is rewritten.
  /// Used as a Riverpod `family` provider key (see `sessionDetailProvider`).
  @override
  bool operator ==(Object other) =>
      other is SessionInfo && other.path == path && other.lastActivity == lastActivity;

  @override
  int get hashCode => Object.hash(path, lastActivity);
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
