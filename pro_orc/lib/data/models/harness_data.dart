/// The configuration level a harness entry originates from. Kept explicit
/// per AD-2: the UI shows each level separately with an origin badge instead
/// of merging them (which would drift from Claude Code's own precedence rules).
enum HarnessLevel {
  /// `~/.claude/settings.json` and `~/.claude/rules/**`.
  global,

  /// `<project>/.claude/settings.json` and `<project>/.mcp.json`.
  project,

  /// `<project>/.claude/settings.local.json`.
  local,
}

extension HarnessLevelLabel on HarnessLevel {
  /// German label for the origin badge.
  String get label => switch (this) {
    HarnessLevel.global => 'Global',
    HarnessLevel.project => 'Projekt',
    HarnessLevel.local => 'Local',
  };
}

/// A single hook entry — one matcher/command pair under a hook event, tagged
/// with the level it was declared at.
class HarnessHook {
  /// The hook event name (e.g. `PreToolUse`, `Stop`).
  final String event;

  /// The matcher string, if present (e.g. `Bash`, `*`). Empty when the hook
  /// declares no matcher.
  final String matcher;

  /// The command(s) run by this hook, joined for display.
  final String command;

  final HarnessLevel level;

  const HarnessHook({
    required this.event,
    required this.matcher,
    required this.command,
    required this.level,
  });
}

/// A permission rule (allow/ask/deny) at a given level.
class HarnessPermission {
  /// One of `allow`, `ask`, `deny`.
  final String kind;

  /// The rule pattern (e.g. `Bash(git *)`, `Read`).
  final String rule;

  final HarnessLevel level;

  const HarnessPermission({
    required this.kind,
    required this.rule,
    required this.level,
  });
}

/// An environment variable declared in a settings.json `env` block.
class HarnessEnvVar {
  final String key;
  final String value;
  final HarnessLevel level;

  const HarnessEnvVar({
    required this.key,
    required this.value,
    required this.level,
  });
}

/// A rules markdown file under `~/.claude/rules/**`.
class HarnessRule {
  /// H1 title (first `# ` heading), or the filename if none was found.
  final String title;

  /// Path relative to the rules root, for display (e.g. `common/testing.md`).
  final String relativePath;

  /// Absolute path — used for "Im Finder zeigen".
  final String absolutePath;

  const HarnessRule({
    required this.title,
    required this.relativePath,
    required this.absolutePath,
  });
}

/// An MCP server entry, tagged with the level it was declared at.
class HarnessMcpServer {
  final String name;

  /// The command or URL that launches the server, for display.
  final String detail;

  final HarnessLevel level;

  const HarnessMcpServer({
    required this.name,
    required this.detail,
    required this.level,
  });
}

/// Absolute paths of the settings files that back the harness view, so the UI
/// can offer "Im Finder zeigen" per source. Null when a file does not exist.
class HarnessSources {
  final String? globalSettingsPath;
  final String? projectSettingsPath;
  final String? localSettingsPath;
  final String? rulesRootPath;

  const HarnessSources({
    this.globalSettingsPath,
    this.projectSettingsPath,
    this.localSettingsPath,
    this.rulesRootPath,
  });

  static const empty = HarnessSources();
}

/// Aggregated, read-only harness configuration across all levels. Produced by
/// `HarnessReader.read`. Every list is level-tagged; nothing is merged (AD-2).
class HarnessData {
  final List<HarnessHook> hooks;
  final List<HarnessPermission> permissions;
  final List<HarnessEnvVar> envVars;
  final List<HarnessRule> rules;
  final List<HarnessMcpServer> mcpServers;
  final HarnessSources sources;

  const HarnessData({
    this.hooks = const [],
    this.permissions = const [],
    this.envVars = const [],
    this.rules = const [],
    this.mcpServers = const [],
    this.sources = HarnessSources.empty,
  });

  static const empty = HarnessData();

  bool get isEmpty =>
      hooks.isEmpty &&
      permissions.isEmpty &&
      envVars.isEmpty &&
      rules.isEmpty &&
      mcpServers.isEmpty;
}
