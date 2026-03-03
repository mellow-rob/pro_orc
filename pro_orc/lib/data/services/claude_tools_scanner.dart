import 'dart:convert';
import 'dart:io';

import 'package:pro_orc/data/models/agent_category.dart';
import 'package:pro_orc/data/models/claude_tool_model.dart';

/// Pure Dart service that discovers Skills, Plugins, and MCP servers from
/// a `~/.claude/`-shaped directory.
///
/// No Flutter imports — safe for use in isolates and unit tests.
///
/// Mirrors the shape of [ProjectScanner]: three private scan methods,
/// top-level error fallback, injectable directory override for testing.
class ClaudeToolsScanner {
  /// Absolute path to the `.claude` directory being scanned.
  final String claudeDir;

  /// Creates a scanner targeting [claudeDirOverride] if provided, otherwise
  /// defaults to `$HOME/.claude`.
  ClaudeToolsScanner({String? claudeDirOverride})
      : claudeDir = claudeDirOverride ??
            '${Platform.environment['HOME'] ?? '/Users/rob'}/.claude';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Scans [claudeDir] and returns a [ClaudeToolsData] with all discovered
  /// tools. Returns [ClaudeToolsData.empty] with `hasError: true` on failure.
  Future<ClaudeToolsData> scanAll() async {
    try {
      final skills = await _scanSkills();
      final plugins = await _scanPlugins();
      final mcpServers = await _scanMcpServers();
      final agents = await _scanAgents();
      return ClaudeToolsData(
        skills: skills,
        plugins: plugins,
        mcpServers: mcpServers,
        agents: agents,
      );
    } catch (_) {
      return const ClaudeToolsData(
        skills: [],
        plugins: [],
        mcpServers: [],
        hasError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Skills
  // ---------------------------------------------------------------------------

  Future<List<SkillData>> _scanSkills() async {
    final seen = <String>{};
    final result = <SkillData>[];

    // Scan both ~/.claude/skills/ and ~/.agents/skills/
    final home = claudeDir.replaceFirst('/.claude', '');
    final dirs = [
      Directory('$claudeDir/skills'),
      Directory('$home/.agents/skills'),
    ];

    for (final skillsDir in dirs) {
      if (!await skillsDir.exists()) continue;

      await for (final entity in skillsDir.list(
        recursive: false,
        followLinks: true,
      )) {
        if (entity is! Directory) continue;

        final id = entity.path.split('/').last;
        if (id.startsWith('.') || seen.contains(id)) continue;
        seen.add(id);

        final skillData = await _readSkillDir(entity.path, id);
        result.add(skillData);
      }
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Reads a single skill directory and returns [SkillData].
  ///
  /// Tries `SKILL.md` first, then `skill.md`. If neither exists, falls back
  /// to using the folder name as the display name.
  Future<SkillData> _readSkillDir(String dirPath, String id) async {
    // Try SKILL.md, then skill.md (case-insensitive fallback)
    for (final filename in ['SKILL.md', 'skill.md']) {
      final file = File('$dirPath/$filename');
      try {
        final content = await file.readAsString();
        final frontmatter = _parseFrontmatter(content);
        return SkillData(
          id: id,
          name: frontmatter['name'] ?? id,
          description: frontmatter['description'],
          homepage: frontmatter['homepage'],
          path: dirPath,
        );
      } catch (_) {
        // File does not exist or is not readable — try next
      }
    }

    // No SKILL.md found — use folder name as display name
    return SkillData(
      id: id,
      name: id,
      path: dirPath,
    );
  }

  // ---------------------------------------------------------------------------
  // Plugins
  // ---------------------------------------------------------------------------

  Future<List<PluginData>> _scanPlugins() async {
    final installedPath = '$claudeDir/plugins/installed_plugins.json';
    final settingsPath = '$claudeDir/settings.json';
    final marketplacesPath = '$claudeDir/plugins/known_marketplaces.json';

    try {
      final installedRaw = await File(installedPath).readAsString();
      final settingsRaw = await File(settingsPath).readAsString();

      final installed = jsonDecode(installedRaw) as Map<String, dynamic>;
      final settings = jsonDecode(settingsRaw) as Map<String, dynamic>;
      final enabledPlugins =
          (settings['enabledPlugins'] as Map<String, dynamic>?) ?? {};
      final pluginsMap =
          (installed['plugins'] as Map<String, dynamic>?) ?? {};

      // Load marketplace URLs (optional — graceful if missing)
      Map<String, dynamic> marketplaces = {};
      try {
        final mRaw = await File(marketplacesPath).readAsString();
        marketplaces = jsonDecode(mRaw) as Map<String, dynamic>;
      } catch (_) {}

      final result = <PluginData>[];

      for (final entry in pluginsMap.entries) {
        final key = entry.key; // e.g. "context7@claude-plugins-official"
        final installs = entry.value as List<dynamic>;
        if (installs.isEmpty) continue;

        final first = installs[0] as Map<String, dynamic>;

        final atIndex = key.indexOf('@');
        final name = atIndex >= 0 ? key.substring(0, atIndex) : key;
        final marketplaceId =
            atIndex >= 0 ? key.substring(atIndex + 1) : '';

        final installPath = first['installPath'] as String? ?? '';
        final version = first['version'] as String?;
        final enabled = (enabledPlugins[key] as bool?) ?? false;

        // Description from plugin.json in install cache
        String? description;
        try {
          final pjPath = '$installPath/.claude-plugin/plugin.json';
          final pjRaw = await File(pjPath).readAsString();
          final pj = jsonDecode(pjRaw) as Map<String, dynamic>;
          description = pj['description'] as String?;
        } catch (_) {}

        // Marketplace URL derived from known_marketplaces.json
        String? marketplaceUrl;
        final mktInfo =
            marketplaces[marketplaceId] as Map<String, dynamic>?;
        final repo =
            (mktInfo?['source'] as Map<String, dynamic>?)?['repo'] as String?;
        if (repo != null) marketplaceUrl = 'https://github.com/$repo';

        result.add(PluginData(
          key: key,
          name: name,
          marketplace: marketplaceId,
          version: version,
          enabled: enabled,
          description: description,
          marketplaceUrl: marketplaceUrl,
        ));
      }

      result.sort((a, b) => a.name.compareTo(b.name));
      return result;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // MCP Servers
  // ---------------------------------------------------------------------------

  Future<List<McpServerData>> _scanMcpServers() async {
    final result = <McpServerData>[];

    // --- Source 1: Global MCP servers from settings.json ---
    Map<String, dynamic> settings = {};
    try {
      final raw = await File('$claudeDir/settings.json').readAsString();
      settings = jsonDecode(raw) as Map<String, dynamic>;
      final mcpServers =
          (settings['mcpServers'] as Map<String, dynamic>?) ?? {};

      for (final entry in mcpServers.entries) {
        result.add(_parseMcpEntry(entry.key, entry.value as Map<String, dynamic>));
      }
    } catch (_) {}

    // --- Source 2: Plugin-provided MCP servers from .mcp.json files ---
    final enabledPlugins =
        (settings['enabledPlugins'] as Map<String, dynamic>?) ?? {};

    try {
      final installedPath = '$claudeDir/plugins/installed_plugins.json';
      final installedRaw = await File(installedPath).readAsString();
      final installed = jsonDecode(installedRaw) as Map<String, dynamic>;
      final pluginsMap =
          (installed['plugins'] as Map<String, dynamic>?) ?? {};

      for (final entry in pluginsMap.entries) {
        final key = entry.key;
        final installs = entry.value as List<dynamic>;
        if (installs.isEmpty) continue;

        final first = installs[0] as Map<String, dynamic>;
        final installPath = first['installPath'] as String? ?? '';
        if (installPath.isEmpty) continue;

        final atIndex = key.indexOf('@');
        final pluginName = atIndex >= 0 ? key.substring(0, atIndex) : key;
        final isEnabled = (enabledPlugins[key] as bool?) ?? false;

        // Read .mcp.json from the plugin install path
        try {
          final mcpFile = File('$installPath/.mcp.json');
          final mcpRaw = await mcpFile.readAsString();
          final mcpJson = jsonDecode(mcpRaw) as Map<String, dynamic>;

          // Two format variants:
          // 1) { "mcpServers": { "name": { ... } } }
          // 2) { "name": { "command": "...", "args": [...] } }
          final Map<String, dynamic> servers;
          if (mcpJson.containsKey('mcpServers')) {
            servers =
                (mcpJson['mcpServers'] as Map<String, dynamic>?) ?? {};
          } else {
            servers = mcpJson;
          }

          for (final sEntry in servers.entries) {
            final config = sEntry.value;
            if (config is! Map<String, dynamic>) continue;
            result.add(_parseMcpEntry(
              sEntry.key,
              config,
              source: pluginName,
              enabled: isEnabled,
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Parses a single MCP server config entry into [McpServerData].
  McpServerData _parseMcpEntry(
    String name,
    Map<String, dynamic> config, {
    String? source,
    bool enabled = true,
  }) {
    final typeStr = config['type'] as String?;

    McpServerType type;
    String command;
    List<String>? argsList;

    if (typeStr == 'http') {
      type = McpServerType.http;
      command = config['url'] as String? ?? '';
    } else if (typeStr == 'sse') {
      type = McpServerType.sse;
      command = config['url'] as String? ?? '';
    } else {
      type = McpServerType.stdio;
      final cmd = config['command'] as String? ?? '';
      argsList = (config['args'] as List<dynamic>?)
          ?.map((a) => a.toString())
          .toList();
      final argsStr = argsList?.join(' ') ?? '';
      command = argsStr.isNotEmpty ? '$cmd $argsStr' : cmd;
    }

    return McpServerData(
      name: name,
      command: command,
      type: type,
      source: source,
      enabled: enabled,
      args: argsList,
    );
  }

  // ---------------------------------------------------------------------------
  // Agents
  // ---------------------------------------------------------------------------

  Future<List<AgentData>> _scanAgents() async {
    final agentsDir = Directory('$claudeDir/agents');
    if (!await agentsDir.exists()) return [];

    final result = <AgentData>[];

    await for (final entity in agentsDir.list(recursive: false)) {
      if (entity is! File) continue;
      final filename = entity.path.split('/').last;
      if (!filename.endsWith('.md')) continue;

      final id = filename.substring(0, filename.length - 3);

      try {
        final content = await entity.readAsString();
        final frontmatter = _parseFrontmatter(content);

        final toolsRaw = frontmatter['tools'] ?? '';
        final tools = toolsRaw
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        final name = frontmatter['name'] ?? id;
        final category = name.startsWith('gsd-') ? AgentCategory.gsd : AgentCategory.general;

        result.add(AgentData(
          id: id,
          name: name,
          description: frontmatter['description'],
          color: frontmatter['color'] ?? 'cyan',
          model: frontmatter['model'],
          tools: tools,
          path: entity.path,
          category: category,
        ));
      } catch (_) {
        // Unreadable file — skip
      }
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Frontmatter parser
  // ---------------------------------------------------------------------------

  /// Parses YAML frontmatter from [content] and returns a key→value map.
  ///
  /// Handles:
  /// - `---` delimiters
  /// - Quoted values (strips surrounding double quotes)
  /// - Values containing colons (splits only at first `:`)
  Map<String, String> _parseFrontmatter(String content) {
    final result = <String, String>{};
    final lines = content.split('\n');
    bool inFrontmatter = false;
    int dashCount = 0;

    for (final line in lines) {
      if (line.trim() == '---') {
        dashCount++;
        inFrontmatter = dashCount == 1;
        if (dashCount == 2) break;
        continue;
      }
      if (!inFrontmatter) continue;

      final colonIdx = line.indexOf(':');
      if (colonIdx < 0) continue;

      final key = line.substring(0, colonIdx).trim();
      var value = line.substring(colonIdx + 1).trim();

      // Strip surrounding double quotes
      if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }

      if (key.isNotEmpty) {
        result[key] = value;
      }
    }

    return result;
  }
}
