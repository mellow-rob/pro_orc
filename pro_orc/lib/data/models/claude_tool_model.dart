// Pure Dart data models for Claude Tools discovery.
// No Flutter imports — safe for use in isolates and unit tests.

import 'package:pro_orc/data/models/agent_category.dart';

// ---------------------------------------------------------------------------
// McpServerType
// ---------------------------------------------------------------------------

/// Transport type for an MCP server entry.
enum McpServerType { stdio, http, sse }

// ---------------------------------------------------------------------------
// SkillData
// ---------------------------------------------------------------------------

/// Represents a single Claude skill discovered in `~/.claude/skills/`.
class SkillData {
  /// Folder name — canonical identifier.
  final String id;

  /// Display name from YAML frontmatter `name:` field, or folder name fallback.
  final String name;

  /// Optional description from YAML frontmatter `description:` field.
  final String? description;

  /// Optional homepage URL from YAML frontmatter `homepage:` field.
  final String? homepage;

  /// Absolute path to the skill directory.
  final String path;

  /// Scope: `'global'` for `~/.claude/skills/`, `'project'` for per-project.
  final String scope;

  const SkillData({
    required this.id,
    required this.name,
    this.description,
    this.homepage,
    required this.path,
    this.scope = 'global',
  });
}

// ---------------------------------------------------------------------------
// PluginData
// ---------------------------------------------------------------------------

/// Represents a single Claude plugin discovered in `~/.claude/plugins/`.
class PluginData {
  /// Full plugin key from `installed_plugins.json` (e.g. `"context7@claude-plugins-official"`).
  final String key;

  /// Plugin name — left side of `@` in the key.
  final String name;

  /// Marketplace identifier — right side of `@` in the key.
  final String marketplace;

  /// Installed version from `installed_plugins.json`, if available.
  final String? version;

  /// Whether the plugin is enabled in `settings.json` `enabledPlugins` map.
  final bool enabled;

  /// Optional description from the plugin's `plugin.json` metadata file.
  final String? description;

  /// Optional GitHub URL derived from `known_marketplaces.json` → `source.repo`.
  final String? marketplaceUrl;

  /// Plugin author name from `plugin.json` `author.name` field.
  final String? author;

  /// Timestamp when the plugin was first installed.
  final DateTime? installedAt;

  /// Timestamp when the plugin was last updated.
  final DateTime? lastUpdated;

  const PluginData({
    required this.key,
    required this.name,
    required this.marketplace,
    this.version,
    required this.enabled,
    this.description,
    this.marketplaceUrl,
    this.author,
    this.installedAt,
    this.lastUpdated,
  });
}

// ---------------------------------------------------------------------------
// McpServerData
// ---------------------------------------------------------------------------

/// Represents a single MCP server entry from settings.json or a plugin `.mcp.json`.
class McpServerData {
  /// Server name — the key from the `mcpServers` map.
  final String name;

  /// Command string (stdio: `"npx arg1 arg2"`) or URL (http/sse: `"https://..."`).
  final String command;

  /// Transport type: stdio, http, or sse.
  final McpServerType type;

  /// Source plugin name, or `null` for global (settings.json) servers.
  final String? source;

  /// Whether the server is enabled. Global servers are always true;
  /// plugin servers derive from `enabledPlugins` in settings.json.
  final bool enabled;

  /// Separate args list for display (stdio only).
  final List<String>? args;

  /// Scope: `'global'` for `~/.claude/settings.json`, `'project'` for per-project.
  final String scope;

  const McpServerData({
    required this.name,
    required this.command,
    required this.type,
    this.source,
    this.enabled = true,
    this.args,
    this.scope = 'global',
  });
}

// ---------------------------------------------------------------------------
// AgentData
// ---------------------------------------------------------------------------

/// Represents a single Claude agent discovered in `~/.claude/agents/`.
class AgentData {
  /// Filename without `.md` extension — canonical identifier.
  final String id;

  /// Display name from YAML frontmatter `name:` field.
  final String name;

  /// Optional description from YAML frontmatter `description:` field.
  final String? description;

  /// Color string from frontmatter (e.g. "green", "cyan", "orange").
  final String color;

  /// Optional model preference (e.g. "opus", "haiku").
  final String? model;

  /// List of allowed tools (e.g. ["Read", "Write", "Bash"]).
  final List<String> tools;

  /// Absolute path to the `.md` file.
  final String path;

  /// Category derived from name prefix.
  final AgentCategory category;

  /// Scope: `'global'` for `~/.claude/agents/`, `'project'` for per-project
  /// `<project>/.claude/agents/`.
  final String scope;

  /// Display name of the owning project when [scope] is `'project'`, else null.
  final String? projectName;

  const AgentData({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.model,
    required this.tools,
    required this.path,
    required this.category,
    this.scope = 'global',
    this.projectName,
  });
}

// ---------------------------------------------------------------------------
// ClaudeToolsData
// ---------------------------------------------------------------------------

/// Aggregated result from [ClaudeToolsScanner.scanAll].
class ClaudeToolsData {
  final List<SkillData> skills;
  final List<PluginData> plugins;
  final List<McpServerData> mcpServers;
  final List<AgentData> agents;

  /// True if a top-level error occurred during scanning.
  final bool hasError;

  const ClaudeToolsData({
    required this.skills,
    required this.plugins,
    required this.mcpServers,
    this.agents = const [],
    this.hasError = false,
  });

  /// Empty result with no tools — used as the error fallback.
  static const empty = ClaudeToolsData(
    skills: [],
    plugins: [],
    mcpServers: [],
    agents: [],
  );

  /// True if all four tool lists are empty.
  bool get isEmpty =>
      skills.isEmpty && plugins.isEmpty && mcpServers.isEmpty && agents.isEmpty;
}
