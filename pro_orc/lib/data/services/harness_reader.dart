import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/harness_data.dart';

/// Reads the Claude Code "harness" — hooks, permissions, env vars, rules and
/// MCP servers — across the three configuration levels (global / project /
/// local), strictly read-only.
///
/// No Flutter imports — pure Dart, safe for isolates and unit tests (AD-3).
///
/// Per AD-2 nothing is merged: every entry carries the [HarnessLevel] it was
/// declared at so the UI can show each source separately with an origin badge
/// rather than reimplementing Claude Code's own precedence, which would drift.
///
/// Defensive throughout: a missing file or malformed JSON yields empty results
/// for that source and a log line — it never throws.
class HarnessReader {
  /// Absolute path to the global `.claude` directory. Defaults to
  /// `$HOME/.claude`; overridable for tests.
  final String claudeHomeDir;

  HarnessReader({String? claudeHomeDirOverride})
      : claudeHomeDir = claudeHomeDirOverride ??
            p.join(Platform.environment['HOME']!, '.claude');

  /// Reads harness config for [projectPath]. If [projectPath] is null, only
  /// the global level is read (used when no project is selected).
  Future<HarnessData> read(String? projectPath) async {
    try {
      final hooks = <HarnessHook>[];
      final permissions = <HarnessPermission>[];
      final envVars = <HarnessEnvVar>[];
      final mcpServers = <HarnessMcpServer>[];

      final globalSettings = p.join(claudeHomeDir, 'settings.json');
      final projectSettings = projectPath == null
          ? null
          : p.join(projectPath, '.claude', 'settings.json');
      final localSettings = projectPath == null
          ? null
          : p.join(projectPath, '.claude', 'settings.local.json');
      final projectMcp =
          projectPath == null ? null : p.join(projectPath, '.mcp.json');
      final rulesRoot = p.join(claudeHomeDir, 'rules');

      await _readSettingsFile(
        globalSettings,
        HarnessLevel.global,
        hooks: hooks,
        permissions: permissions,
        envVars: envVars,
        mcpServers: mcpServers,
      );
      if (projectSettings != null) {
        await _readSettingsFile(
          projectSettings,
          HarnessLevel.project,
          hooks: hooks,
          permissions: permissions,
          envVars: envVars,
          mcpServers: mcpServers,
        );
      }
      if (localSettings != null) {
        await _readSettingsFile(
          localSettings,
          HarnessLevel.local,
          hooks: hooks,
          permissions: permissions,
          envVars: envVars,
          mcpServers: mcpServers,
        );
      }
      if (projectMcp != null) {
        await _readMcpFile(projectMcp, HarnessLevel.project, mcpServers);
      }

      final rules = await _readRules(rulesRoot);

      return HarnessData(
        hooks: hooks,
        permissions: permissions,
        envVars: envVars,
        rules: rules,
        mcpServers: mcpServers,
        sources: HarnessSources(
          globalSettingsPath:
              await _existingPath(globalSettings),
          projectSettingsPath: projectSettings == null
              ? null
              : await _existingPath(projectSettings),
          localSettingsPath: localSettings == null
              ? null
              : await _existingPath(localSettings),
          rulesRootPath: await _existingDirPath(rulesRoot),
        ),
      );
    } catch (e) {
      developer.log('Failed to read harness config: $e', name: 'harness_reader');
      return HarnessData.empty;
    }
  }

  /// Parses one settings.json file, appending its hooks, permissions, env vars
  /// and (inline) MCP servers tagged with [level]. Missing or malformed files
  /// are skipped silently (logged).
  Future<void> _readSettingsFile(
    String path,
    HarnessLevel level, {
    required List<HarnessHook> hooks,
    required List<HarnessPermission> permissions,
    required List<HarnessEnvVar> envVars,
    required List<HarnessMcpServer> mcpServers,
  }) async {
    final Map<String, dynamic> json;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      json = decoded;
    } catch (e) {
      developer.log('Skipping unreadable settings $path: $e', name: 'harness_reader');
      return;
    }

    _extractHooks(json['hooks'], level, hooks);
    _extractPermissions(json['permissions'], level, permissions);
    _extractEnv(json['env'], level, envVars);
    _extractInlineMcp(json['mcpServers'], level, mcpServers);
  }

  void _extractHooks(Object? raw, HarnessLevel level, List<HarnessHook> out) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final event = entry.key.toString();
      final groups = entry.value;
      if (groups is! List) continue;
      for (final group in groups) {
        if (group is! Map) continue;
        final matcher = (group['matcher'] as String?) ?? '';
        final inner = group['hooks'];
        if (inner is! List) continue;
        final commands = <String>[];
        for (final h in inner) {
          if (h is Map && h['command'] is String) {
            commands.add(h['command'] as String);
          }
        }
        if (commands.isEmpty) continue;
        out.add(HarnessHook(
          event: event,
          matcher: matcher,
          command: commands.join('; '),
          level: level,
        ));
      }
    }
  }

  void _extractPermissions(
    Object? raw,
    HarnessLevel level,
    List<HarnessPermission> out,
  ) {
    if (raw is! Map) return;
    for (final kind in const ['allow', 'ask', 'deny']) {
      final rules = raw[kind];
      if (rules is! List) continue;
      for (final rule in rules) {
        if (rule is String && rule.isNotEmpty) {
          out.add(HarnessPermission(kind: kind, rule: rule, level: level));
        }
      }
    }
  }

  void _extractEnv(Object? raw, HarnessLevel level, List<HarnessEnvVar> out) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      out.add(HarnessEnvVar(
        key: entry.key.toString(),
        value: entry.value?.toString() ?? '',
        level: level,
      ));
    }
  }

  void _extractInlineMcp(
    Object? raw,
    HarnessLevel level,
    List<HarnessMcpServer> out,
  ) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final config = entry.value;
      out.add(HarnessMcpServer(
        name: entry.key.toString(),
        detail: _mcpDetail(config),
        level: level,
      ));
    }
  }

  /// Reads a standalone `.mcp.json` (project-level). Supports both the
  /// `{ "mcpServers": {...} }` and the bare `{ "name": {...} }` shapes, as the
  /// existing tools scanner does.
  Future<void> _readMcpFile(
    String path,
    HarnessLevel level,
    List<HarnessMcpServer> out,
  ) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final servers = decoded.containsKey('mcpServers')
          ? decoded['mcpServers']
          : decoded;
      _extractInlineMcp(servers, level, out);
    } catch (e) {
      developer.log('Skipping unreadable .mcp.json $path: $e', name: 'harness_reader');
    }
  }

  String _mcpDetail(Object? config) {
    if (config is! Map) return '';
    final url = config['url'];
    if (url is String && url.isNotEmpty) return url;
    final command = config['command'];
    if (command is String && command.isNotEmpty) {
      final args = config['args'];
      if (args is List && args.isNotEmpty) {
        return '$command ${args.join(' ')}';
      }
      return command;
    }
    return '';
  }

  /// Reads `~/.claude/rules/**/*.md`, extracting each file's H1 title (or its
  /// filename as fallback), sorted by relative path.
  Future<List<HarnessRule>> _readRules(String rulesRoot) async {
    final out = <HarnessRule>[];
    try {
      final dir = Directory(rulesRoot);
      if (!await dir.exists()) return out;

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.md')) continue;
        final relative = p.relative(entity.path, from: rulesRoot);
        String? title;
        try {
          title = await _firstH1(entity);
        } catch (e) {
          developer.log('Failed to read rule ${entity.path}: $e', name: 'harness_reader');
        }
        out.add(HarnessRule(
          title: (title != null && title.isNotEmpty)
              ? title
              : p.basename(entity.path),
          relativePath: relative,
          absolutePath: entity.path,
        ));
      }
    } catch (e) {
      developer.log('Failed to list rules under $rulesRoot: $e', name: 'harness_reader');
    }
    out.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return out;
  }

  /// Returns the text of the first `# ` H1 heading in [file], streaming so we
  /// stop at the first match rather than loading the whole file.
  Future<String?> _firstH1(File file) async {
    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      }
    }
    return null;
  }

  Future<String?> _existingPath(String path) async =>
      await File(path).exists() ? path : null;

  Future<String?> _existingDirPath(String path) async =>
      await Directory(path).exists() ? path : null;
}
