// Pure Dart data models for Claude Tools discovery.
// No Flutter imports — safe for use in isolates and unit tests.

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

  const SkillData({
    required this.id,
    required this.name,
    this.description,
    this.homepage,
    required this.path,
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

  const PluginData({
    required this.key,
    required this.name,
    required this.marketplace,
    this.version,
    required this.enabled,
    this.description,
    this.marketplaceUrl,
  });
}

// ---------------------------------------------------------------------------
// McpServerData
// ---------------------------------------------------------------------------

/// Represents a single MCP server entry from `~/.claude/settings.json` `mcpServers`.
class McpServerData {
  /// Server name — the key from the `mcpServers` map.
  final String name;

  /// Command string (stdio: `"npx arg1 arg2"`) or URL (http/sse: `"https://..."`).
  final String command;

  /// Transport type: stdio, http, or sse.
  final McpServerType type;

  const McpServerData({
    required this.name,
    required this.command,
    required this.type,
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

  /// True if a top-level error occurred during scanning.
  final bool hasError;

  const ClaudeToolsData({
    required this.skills,
    required this.plugins,
    required this.mcpServers,
    this.hasError = false,
  });

  /// Empty result with no tools — used as the error fallback.
  static const empty = ClaudeToolsData(
    skills: [],
    plugins: [],
    mcpServers: [],
  );

  /// True if all three tool lists are empty.
  bool get isEmpty =>
      skills.isEmpty && plugins.isEmpty && mcpServers.isEmpty;
}
