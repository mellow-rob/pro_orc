import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

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

  /// Caches [scanProjectTools] results per project path, keyed by the mtime
  /// of that project's `.claude/agents` directory (the fastest-changing of
  /// the three per-project sources). Mirrors the mtime-caching pattern from
  /// [ProjectScanner] (M1) — without it, a single FS event under
  /// `~/.claude/` would force a full re-scan of every project's local
  /// agents/skills/MCP config, which is unnecessary when nothing there
  /// changed.
  final Map<String, ({DateTime? signature, ClaudeToolsData data})>
  _projectCache = {};

  /// Creates a scanner targeting [claudeDirOverride] if provided, otherwise
  /// defaults to `$HOME/.claude`.
  ClaudeToolsScanner({String? claudeDirOverride})
    : claudeDir =
          claudeDirOverride ?? '${Platform.environment['HOME']!}/.claude';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Scans [claudeDir] and returns a [ClaudeToolsData] with all discovered
  /// tools. Returns [ClaudeToolsData.empty] with `hasError: true` on failure.
  Future<ClaudeToolsData> scanAll() async {
    try {
      final skills = await _scanSkills();
      final pluginSkills = await _scanPluginSkills();
      final plugins = await _scanPlugins();
      final mcpServers = await _scanMcpServers();
      final agents = await _scanAgents();
      return ClaudeToolsData(
        skills: [...skills, ...pluginSkills],
        plugins: plugins,
        mcpServers: mcpServers,
        agents: agents,
      );
    } catch (e) {
      developer.log(
        'Failed to scan claude tools: $e',
        name: 'claude_tools_scanner',
      );
      return const ClaudeToolsData(
        skills: [],
        plugins: [],
        mcpServers: [],
        hasError: true,
      );
    }
  }

  /// Scans per-project Claude tools at [projectPath].
  /// Returns skills from `<project>/.claude/skills/`, agents from
  /// `<project>/.claude/agents/`, and MCP servers from `<project>/.mcp.json`.
  /// Plugins are always global -- returned as empty list.
  ///
  /// [projectName] is attached to each returned [AgentData.projectName] for
  /// display (e.g. "niimo-qa (Niimo)"); pass the project's display name.
  ///
  /// Cached per [projectPath] using the mtime of `<project>/.claude` as a
  /// cheap change signature — call sites that scan many projects on every
  /// FS event (e.g. an "all agents across all projects" view) stay cheap
  /// for projects whose `.claude/` config hasn't changed.
  Future<ClaudeToolsData> scanProjectTools(
    String projectPath, {
    String? projectName,
  }) async {
    final signature = await _projectClaudeDirSignature(projectPath);
    final cached = _projectCache[projectPath];
    if (cached != null && signature != null && cached.signature == signature) {
      return cached.data;
    }

    final result = await _scanProjectToolsUncached(projectPath, projectName);

    if (signature != null) {
      _projectCache[projectPath] = (signature: signature, data: result);
    }
    return result;
  }

  Future<ClaudeToolsData> _scanProjectToolsUncached(
    String projectPath,
    String? projectName,
  ) async {
    try {
      final skills = await _scanProjectSkills(projectPath);
      final mcpServers = await _scanProjectMcpServers(projectPath);
      final agents = await _scanProjectAgents(
        projectPath,
        projectName: projectName,
      );
      return ClaudeToolsData(
        skills: skills,
        plugins: const [],
        mcpServers: mcpServers,
        agents: agents,
      );
    } catch (e) {
      developer.log(
        'Failed to scan project tools for $projectPath: $e',
        name: 'claude_tools_scanner',
      );
      return ClaudeToolsData.empty;
    }
  }

  /// Returns the mtime of `<projectPath>/.claude`, used as the cache
  /// signature for [scanProjectTools]. Returns null if the directory does
  /// not exist (uncached — always re-scan, cheap since there's nothing to
  /// read anyway).
  Future<DateTime?> _projectClaudeDirSignature(String projectPath) async {
    try {
      final dir = Directory('$projectPath/.claude');
      if (!await dir.exists()) return null;
      return (await dir.stat()).modified;
    } catch (e) {
      developer.log(
        'Failed to stat .claude dir for $projectPath: $e',
        name: 'claude_tools_scanner',
      );
      return null;
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
      } catch (e) {
        // File does not exist or is not readable — try next
        developer.log(
          'Failed to read $filename in $dirPath: $e',
          name: 'claude_tools_scanner',
        );
      }
    }

    // No SKILL.md found — use folder name as display name
    return SkillData(id: id, name: id, path: dirPath);
  }

  // ---------------------------------------------------------------------------
  // Plugin-bundled Skills (AD-3)
  // ---------------------------------------------------------------------------

  /// Max directory depth (below `~/.claude/plugins/`) at which a `SKILL.md`
  /// is still considered. Real layouts nest a skill's `SKILL.md` up to ~5
  /// levels deep (e.g. `marketplaces/<mkt>/<plugin>/skills/<skill>/SKILL.md`);
  /// the limit keeps the recursive walk bounded and cheap without a full
  /// unbounded tree scan.
  static const _pluginSkillMaxDepth = 8;

  /// Discovers skills bundled inside installed plugins by walking
  /// `~/.claude/plugins/**` for `skills/<name>/SKILL.md` files (AD-3).
  ///
  /// Deliberately narrow: it reads ONLY this documented-stable layout and does
  /// not parse plugin manifests. On a missing `plugins/` directory it returns
  /// an empty list (silent empty state). Each result carries
  /// `scope = 'plugin'` and the owning plugin's name derived from the path
  /// segment that directly contains the top-level `skills/` folder.
  Future<List<SkillData>> _scanPluginSkills() async {
    final pluginsDir = Directory('$claudeDir/plugins');
    if (!await pluginsDir.exists()) return [];

    final result = <SkillData>[];
    final seenPaths = <String>{};

    try {
      await for (final entity in pluginsDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (p.basename(entity.path) != 'SKILL.md') continue;

        // The skill directory is the parent of SKILL.md; its parent must be a
        // `skills` folder for this to be a plugin-skill in the AD-3 layout.
        final skillDir = p.dirname(entity.path);
        final skillsParent = p.dirname(skillDir);
        if (p.basename(skillsParent) != 'skills') continue;

        // Depth guard relative to the plugins/ root.
        final rel = p.relative(entity.path, from: pluginsDir.path);
        if (p.split(rel).length > _pluginSkillMaxDepth) continue;

        if (!seenPaths.add(skillDir)) continue;

        final id = p.basename(skillDir);
        final pluginName = _pluginNameFromSkillPath(skillsParent);

        final base = await _readSkillDir(skillDir, id);
        result.add(
          SkillData(
            id: base.id,
            name: base.name,
            description: base.description,
            homepage: base.homepage,
            path: base.path,
            scope: 'plugin',
            pluginName: pluginName,
          ),
        );
      }
    } catch (e) {
      developer.log(
        'Failed to scan plugin skills: $e',
        name: 'claude_tools_scanner',
      );
    }

    result.sort((a, b) {
      final byPlugin = (a.pluginName ?? '').compareTo(b.pluginName ?? '');
      return byPlugin != 0 ? byPlugin : a.name.compareTo(b.name);
    });
    return result;
  }

  /// Derives the owning plugin's name from the absolute path of the `skills`
  /// folder that contains a plugin skill. The plugin is the directory holding
  /// that `skills` folder (e.g. `.../obsidian-skills/skills` -> `obsidian-skills`,
  /// `.../autoresearch/claude-plugin/skills` -> `claude-plugin`). Falls back to
  /// `'Plugin'` if the path is unexpectedly shallow.
  String _pluginNameFromSkillPath(String skillsParentDir) {
    final owner = p.basename(p.dirname(skillsParentDir));
    return owner.isEmpty ? 'Plugin' : owner;
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
      final pluginsMap = (installed['plugins'] as Map<String, dynamic>?) ?? {};

      // Load marketplace URLs (optional — graceful if missing)
      Map<String, dynamic> marketplaces = {};
      try {
        final mRaw = await File(marketplacesPath).readAsString();
        marketplaces = jsonDecode(mRaw) as Map<String, dynamic>;
      } catch (e) {
        developer.log(
          'Failed to read known_marketplaces.json: $e',
          name: 'claude_tools_scanner',
        );
      }

      final result = <PluginData>[];

      for (final entry in pluginsMap.entries) {
        final key = entry.key; // e.g. "context7@claude-plugins-official"
        final installs = entry.value as List<dynamic>;
        if (installs.isEmpty) continue;

        final first = installs[0] as Map<String, dynamic>;

        final atIndex = key.indexOf('@');
        final name = atIndex >= 0 ? key.substring(0, atIndex) : key;
        final marketplaceId = atIndex >= 0 ? key.substring(atIndex + 1) : '';

        final installPath = first['installPath'] as String? ?? '';
        final version = first['version'] as String?;
        final enabled = (enabledPlugins[key] as bool?) ?? false;

        // Description and author from plugin.json in install cache
        String? description;
        String? author;
        try {
          final pjPath = '$installPath/.claude-plugin/plugin.json';
          final pjRaw = await File(pjPath).readAsString();
          final pj = jsonDecode(pjRaw) as Map<String, dynamic>;
          description = pj['description'] as String?;
          author = (pj['author'] as Map<String, dynamic>?)?['name'] as String?;
        } catch (e) {
          developer.log(
            'Failed to read plugin.json for $key: $e',
            name: 'claude_tools_scanner',
          );
        }

        // Parse install/update timestamps from installed_plugins.json
        final installedAt = DateTime.tryParse(
          first['installedAt'] as String? ?? '',
        );
        final lastUpdated = DateTime.tryParse(
          first['lastUpdated'] as String? ?? '',
        );

        // Marketplace URL derived from known_marketplaces.json
        String? marketplaceUrl;
        final mktInfo = marketplaces[marketplaceId] as Map<String, dynamic>?;
        final repo =
            (mktInfo?['source'] as Map<String, dynamic>?)?['repo'] as String?;
        if (repo != null) marketplaceUrl = 'https://github.com/$repo';

        result.add(
          PluginData(
            key: key,
            name: name,
            marketplace: marketplaceId,
            version: version,
            enabled: enabled,
            description: description,
            marketplaceUrl: marketplaceUrl,
            author: author,
            installedAt: installedAt,
            lastUpdated: lastUpdated,
          ),
        );
      }

      result.sort((a, b) => a.name.compareTo(b.name));
      return result;
    } catch (e) {
      developer.log('Failed to scan plugins: $e', name: 'claude_tools_scanner');
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
        result.add(
          _parseMcpEntry(entry.key, entry.value as Map<String, dynamic>),
        );
      }
    } catch (e) {
      developer.log(
        'Failed to read global settings.json mcpServers: $e',
        name: 'claude_tools_scanner',
      );
    }

    // --- Source 2: Plugin-provided MCP servers from .mcp.json files ---
    final enabledPlugins =
        (settings['enabledPlugins'] as Map<String, dynamic>?) ?? {};

    try {
      final installedPath = '$claudeDir/plugins/installed_plugins.json';
      final installedRaw = await File(installedPath).readAsString();
      final installed = jsonDecode(installedRaw) as Map<String, dynamic>;
      final pluginsMap = (installed['plugins'] as Map<String, dynamic>?) ?? {};

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
            servers = (mcpJson['mcpServers'] as Map<String, dynamic>?) ?? {};
          } else {
            servers = mcpJson;
          }

          for (final sEntry in servers.entries) {
            final config = sEntry.value;
            if (config is! Map<String, dynamic>) continue;
            result.add(
              _parseMcpEntry(
                sEntry.key,
                config,
                source: pluginName,
                enabled: isEnabled,
              ),
            );
          }
        } catch (e) {
          developer.log(
            'Failed to read .mcp.json for plugin $key: $e',
            name: 'claude_tools_scanner',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Failed to scan plugin MCP servers: $e',
        name: 'claude_tools_scanner',
      );
    }

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
  // Per-project Skills
  // ---------------------------------------------------------------------------

  Future<List<SkillData>> _scanProjectSkills(String projectPath) async {
    final skillsDir = Directory('$projectPath/.claude/skills');
    if (!await skillsDir.exists()) return [];

    final result = <SkillData>[];

    await for (final entity in skillsDir.list(
      recursive: false,
      followLinks: true,
    )) {
      if (entity is! Directory) continue;

      final id = entity.path.split('/').last;
      if (id.startsWith('.')) continue;

      final skillData = await _readSkillDir(entity.path, id);
      result.add(
        SkillData(
          id: skillData.id,
          name: skillData.name,
          description: skillData.description,
          homepage: skillData.homepage,
          path: skillData.path,
          scope: 'project',
        ),
      );
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Per-project MCP Servers
  // ---------------------------------------------------------------------------

  Future<List<McpServerData>> _scanProjectMcpServers(String projectPath) async {
    final mcpFile = File('$projectPath/.mcp.json');
    if (!await mcpFile.exists()) return [];

    try {
      final raw = await mcpFile.readAsString();
      final mcpJson = jsonDecode(raw) as Map<String, dynamic>;

      final Map<String, dynamic> servers;
      if (mcpJson.containsKey('mcpServers')) {
        servers = (mcpJson['mcpServers'] as Map<String, dynamic>?) ?? {};
      } else {
        servers = mcpJson;
      }

      final result = <McpServerData>[];
      for (final entry in servers.entries) {
        final config = entry.value;
        if (config is! Map<String, dynamic>) continue;
        final server = _parseMcpEntry(entry.key, config, source: 'Projekt');
        result.add(
          McpServerData(
            name: server.name,
            command: server.command,
            type: server.type,
            source: server.source,
            enabled: server.enabled,
            args: server.args,
            scope: 'project',
          ),
        );
      }

      result.sort((a, b) => a.name.compareTo(b.name));
      return result;
    } catch (e) {
      developer.log(
        'Failed to scan project MCP servers: $e',
        name: 'claude_tools_scanner',
      );
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Agents
  // ---------------------------------------------------------------------------

  Future<List<AgentData>> _scanAgents() async {
    final agentsDir = Directory('$claudeDir/agents');
    if (!await agentsDir.exists()) return [];

    final result = await _readAgentsFromDir(agentsDir, scope: 'global');
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Scans per-project agents at `<projectPath>/.claude/agents/*.md`.
  /// Returns an empty list if the directory does not exist. Individual
  /// unreadable files are skipped and logged, never thrown.
  Future<List<AgentData>> _scanProjectAgents(
    String projectPath, {
    String? projectName,
  }) async {
    final agentsDir = Directory('$projectPath/.claude/agents');
    if (!await agentsDir.exists()) return [];

    final result = await _readAgentsFromDir(
      agentsDir,
      scope: 'project',
      projectName: projectName,
    );
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Reads all `*.md` agent files directly inside [agentsDir] (non-recursive)
  /// and parses their YAML frontmatter into [AgentData]. Unreadable or
  /// malformed files are skipped (logged), never thrown — a single bad file
  /// must not break discovery of the rest.
  Future<List<AgentData>> _readAgentsFromDir(
    Directory agentsDir, {
    required String scope,
    String? projectName,
  }) async {
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

        result.add(
          AgentData(
            id: id,
            name: name,
            description: frontmatter['description'],
            color: frontmatter['color'] ?? 'cyan',
            model: frontmatter['model'],
            tools: tools,
            path: entity.path,
            scope: scope,
            projectName: projectName,
          ),
        );
      } catch (e) {
        developer.log(
          'Failed to parse agent file ${entity.path}: $e',
          name: 'claude_tools_scanner',
        );
      }
    }

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
  /// - Block scalars: `key: >` (folded — newlines become spaces) and
  ///   `key: |` (literal — newlines preserved), both common in SKILL.md/agent
  ///   frontmatter for multi-line descriptions
  Map<String, String> _parseFrontmatter(String content) =>
      parseYamlFrontmatter(content);
}

/// Parses simple single-file YAML frontmatter (delimited by `---` lines)
/// into a key -> value map. This is NOT a general YAML parser — it only
/// handles the subset actually used across `~/.claude/agents/*.md` and
/// `~/.claude/skills/*/SKILL.md`: scalar `key: value` pairs (optionally
/// double-quoted) and block scalars (`key: >` folded, `key: |` literal).
///
/// Shared by [ClaudeToolsScanner] (agents/skills) so both readers handle
/// multi-line descriptions identically.
Map<String, String> parseYamlFrontmatter(String content) {
  final result = <String, String>{};
  final lines = content.split('\n');
  bool inFrontmatter = false;
  int dashCount = 0;

  String? blockKey;
  bool blockFolded = false; // true for `>`, false for `|`
  int? blockIndent;
  final blockLines = <String>[];

  void flushBlock() {
    if (blockKey == null) return;
    final joined = blockFolded ? blockLines.join(' ') : blockLines.join('\n');
    result[blockKey!] = joined.trim();
    blockKey = null;
    blockIndent = null;
    blockLines.clear();
  }

  for (final line in lines) {
    if (line.trim() == '---') {
      dashCount++;
      if (dashCount == 1) {
        inFrontmatter = true;
        continue;
      }
      // Second '---' ends the frontmatter block.
      flushBlock();
      break;
    }
    if (!inFrontmatter) continue;

    // Inside an active block scalar: collect indented continuation lines.
    if (blockKey != null) {
      if (line.trim().isEmpty) {
        blockLines.add('');
        continue;
      }
      final indent = line.length - line.trimLeft().length;
      blockIndent ??= indent;
      if (indent >= blockIndent!) {
        blockLines.add(line.trimLeft());
        continue;
      }
      // Dedent below the block's indent level — block scalar ends here.
      flushBlock();
      // Fall through to process this line as a normal key: value pair.
    }

    final colonIdx = line.indexOf(':');
    if (colonIdx < 0) continue;

    final key = line.substring(0, colonIdx).trim();
    var value = line.substring(colonIdx + 1).trim();
    if (key.isEmpty) continue;

    if (value == '>' || value == '|') {
      blockKey = key;
      blockFolded = value == '>';
      blockIndent = null;
      blockLines.clear();
      continue;
    }

    // Strip surrounding double quotes
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }

    result[key] = value;
  }

  flushBlock();
  return result;
}
