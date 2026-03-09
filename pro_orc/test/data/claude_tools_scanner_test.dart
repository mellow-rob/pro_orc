import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/data/services/claude_tools_scanner.dart';

/// Creates a temporary directory mimicking `~/.claude/` structure for testing.
///
/// Returns the path to the temp claude directory.
Future<String> createTempClaudeDir({
  bool includePluginAuthor = true,
  bool includeMalformedDates = false,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('claude_test_');
  final claudeDir = tempDir.path;

  // --- settings.json ---
  final settings = {
    'enabledPlugins': {
      'test-plugin@test-marketplace': true,
      'disabled-plugin@test-marketplace': false,
    },
  };
  await File('$claudeDir/settings.json')
      .writeAsString(jsonEncode(settings));

  // --- plugins/installed_plugins.json ---
  final pluginsDir = Directory('$claudeDir/plugins');
  await pluginsDir.create(recursive: true);

  final installedPlugins = {
    'plugins': {
      'test-plugin@test-marketplace': [
        {
          'installPath': '$claudeDir/plugins/cache/test-plugin',
          'version': '1.0.0',
          'installedAt':
              includeMalformedDates ? 'not-a-date' : '2026-01-15T10:30:00Z',
          'lastUpdated':
              includeMalformedDates ? 'also-bad' : '2026-02-20T14:00:00Z',
        }
      ],
      'disabled-plugin@test-marketplace': [
        {
          'installPath': '$claudeDir/plugins/cache/disabled-plugin',
          'version': '2.0.0',
          'installedAt': '2026-03-01T08:00:00Z',
          'lastUpdated': '2026-03-05T12:00:00Z',
        }
      ],
    },
  };
  await File('$claudeDir/plugins/installed_plugins.json')
      .writeAsString(jsonEncode(installedPlugins));

  // --- plugin.json with author ---
  final pluginCacheDir =
      Directory('$claudeDir/plugins/cache/test-plugin/.claude-plugin');
  await pluginCacheDir.create(recursive: true);

  final pluginJson = includePluginAuthor
      ? {'description': 'A test plugin', 'author': {'name': 'TestAuthor'}}
      : {'description': 'A plugin without author'};
  await File('${pluginCacheDir.path}/plugin.json')
      .writeAsString(jsonEncode(pluginJson));

  // --- disabled plugin without plugin.json (missing author) ---
  final disabledCacheDir =
      Directory('$claudeDir/plugins/cache/disabled-plugin/.claude-plugin');
  await disabledCacheDir.create(recursive: true);
  await File('${disabledCacheDir.path}/plugin.json')
      .writeAsString(jsonEncode({'description': 'Disabled plugin'}));

  // --- skills/test-skill/SKILL.md ---
  final skillDir = Directory('$claudeDir/skills/test-skill');
  await skillDir.create(recursive: true);
  await File('${skillDir.path}/SKILL.md').writeAsString('''---
name: Test Skill
description: A skill for testing
homepage: https://example.com/skill
---
# Test Skill
Some content here.
''');

  return claudeDir;
}

void main() {
  group('Plugin metadata parsing', () {
    test('PluginData can be constructed with author, installedAt, lastUpdated',
        () {
      final plugin = PluginData(
        key: 'test@marketplace',
        name: 'test',
        marketplace: 'marketplace',
        enabled: true,
        author: 'TestAuthor',
        installedAt: DateTime.parse('2026-01-15T10:30:00Z'),
        lastUpdated: DateTime.parse('2026-02-20T14:00:00Z'),
      );

      expect(plugin.author, 'TestAuthor');
      expect(plugin.installedAt, isNotNull);
      expect(plugin.lastUpdated, isNotNull);
    });

    test('PluginData nullable metadata fields default to null', () {
      final plugin = PluginData(
        key: 'test@marketplace',
        name: 'test',
        marketplace: 'marketplace',
        enabled: true,
      );

      expect(plugin.author, isNull);
      expect(plugin.installedAt, isNull);
      expect(plugin.lastUpdated, isNull);
    });

    test('Scanner parses author from plugin.json', () async {
      final claudeDir = await createTempClaudeDir();
      try {
        final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
        final result = await scanner.scanAll();

        final testPlugin =
            result.plugins.where((p) => p.name == 'test-plugin').first;
        expect(testPlugin.author, 'TestAuthor');
      } finally {
        await Directory(claudeDir).delete(recursive: true);
      }
    });

    test('Scanner parses installedAt and lastUpdated ISO 8601 dates',
        () async {
      final claudeDir = await createTempClaudeDir();
      try {
        final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
        final result = await scanner.scanAll();

        final testPlugin =
            result.plugins.where((p) => p.name == 'test-plugin').first;
        expect(testPlugin.installedAt, DateTime.parse('2026-01-15T10:30:00Z'));
        expect(testPlugin.lastUpdated, DateTime.parse('2026-02-20T14:00:00Z'));
      } finally {
        await Directory(claudeDir).delete(recursive: true);
      }
    });

    test('Malformed dates fall back to null', () async {
      final claudeDir =
          await createTempClaudeDir(includeMalformedDates: true);
      try {
        final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
        final result = await scanner.scanAll();

        final testPlugin =
            result.plugins.where((p) => p.name == 'test-plugin').first;
        expect(testPlugin.installedAt, isNull);
        expect(testPlugin.lastUpdated, isNull);
      } finally {
        await Directory(claudeDir).delete(recursive: true);
      }
    });

    test('Missing plugin.json author falls back to null', () async {
      final claudeDir =
          await createTempClaudeDir(includePluginAuthor: false);
      try {
        final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
        final result = await scanner.scanAll();

        final testPlugin =
            result.plugins.where((p) => p.name == 'test-plugin').first;
        expect(testPlugin.author, isNull);
      } finally {
        await Directory(claudeDir).delete(recursive: true);
      }
    });
  });

  group('Scope fields', () {
    test('SkillData has scope field defaulting to global', () {
      final skill = SkillData(
        id: 'test',
        name: 'Test',
        path: '/tmp/test',
      );
      expect(skill.scope, 'global');
    });

    test('SkillData can be created with project scope', () {
      final skill = SkillData(
        id: 'test',
        name: 'Test',
        path: '/tmp/test',
        scope: 'project',
      );
      expect(skill.scope, 'project');
    });

    test('McpServerData has scope field defaulting to global', () {
      final server = McpServerData(
        name: 'test',
        command: 'npx test',
        type: McpServerType.stdio,
      );
      expect(server.scope, 'global');
    });

    test('McpServerData can be created with project scope', () {
      final server = McpServerData(
        name: 'test',
        command: 'npx test',
        type: McpServerType.stdio,
        scope: 'project',
      );
      expect(server.scope, 'project');
    });

    test('Scanner returns global scope for skills from claudeDir', () async {
      final claudeDir = await createTempClaudeDir();
      try {
        final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
        final result = await scanner.scanAll();

        expect(result.skills, isNotEmpty);
        for (final skill in result.skills) {
          expect(skill.scope, 'global');
        }
      } finally {
        await Directory(claudeDir).delete(recursive: true);
      }
    });
  });

  group('Per-project scanning', () {
    late String claudeDir;
    late String projectDir;

    setUp(() async {
      // Create a minimal claude dir for the scanner
      final tempClaudeDir =
          await Directory.systemTemp.createTemp('claude_proj_test_');
      claudeDir = tempClaudeDir.path;
      await File('$claudeDir/settings.json')
          .writeAsString(jsonEncode({}));

      // Create a temp project directory
      final tempProjectDir =
          await Directory.systemTemp.createTemp('project_test_');
      projectDir = tempProjectDir.path;
    });

    tearDown(() async {
      await Directory(claudeDir).delete(recursive: true);
      await Directory(projectDir).delete(recursive: true);
    });

    test('scanProjectTools returns skills from project .claude/skills/',
        () async {
      // Create project skill
      final skillDir = Directory('$projectDir/.claude/skills/my-skill');
      await skillDir.create(recursive: true);
      await File('${skillDir.path}/SKILL.md').writeAsString('''---
name: My Project Skill
description: A project-level skill
---
# My Project Skill
''');

      final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
      final result = await scanner.scanProjectTools(projectDir);

      expect(result.skills, hasLength(1));
      expect(result.skills.first.name, 'My Project Skill');
      expect(result.skills.first.scope, 'project');
      expect(result.plugins, isEmpty);
    });

    test('scanProjectTools returns MCP servers from project .mcp.json',
        () async {
      // Create project .mcp.json
      final mcpJson = {
        'mcpServers': {
          'project-server': {
            'command': 'npx',
            'args': ['-y', 'project-mcp-server'],
          },
        },
      };
      await File('$projectDir/.mcp.json')
          .writeAsString(jsonEncode(mcpJson));

      final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
      final result = await scanner.scanProjectTools(projectDir);

      expect(result.mcpServers, hasLength(1));
      expect(result.mcpServers.first.name, 'project-server');
      expect(result.mcpServers.first.scope, 'project');
      expect(result.mcpServers.first.source, 'Projekt');
      expect(result.skills, isEmpty);
    });

    test('scanProjectTools returns empty lists when no project config exists',
        () async {
      final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
      final result = await scanner.scanProjectTools(projectDir);

      expect(result.skills, isEmpty);
      expect(result.plugins, isEmpty);
      expect(result.mcpServers, isEmpty);
    });

    test('scanProjectTools handles missing .mcp.json gracefully', () async {
      // Create only a skill, no .mcp.json
      final skillDir = Directory('$projectDir/.claude/skills/only-skill');
      await skillDir.create(recursive: true);
      await File('${skillDir.path}/SKILL.md').writeAsString('''---
name: Only Skill
---
''');

      final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
      final result = await scanner.scanProjectTools(projectDir);

      expect(result.skills, hasLength(1));
      expect(result.mcpServers, isEmpty);
    });

    test(
        'Duplicate skills (same id in global and project) are kept separate with different scope',
        () async {
      // Create global skill
      final globalSkillDir = Directory('$claudeDir/skills/shared-skill');
      await globalSkillDir.create(recursive: true);
      await File('${globalSkillDir.path}/SKILL.md').writeAsString('''---
name: Shared Skill
description: Global version
---
''');

      // Create project skill with same id
      final projectSkillDir =
          Directory('$projectDir/.claude/skills/shared-skill');
      await projectSkillDir.create(recursive: true);
      await File('${projectSkillDir.path}/SKILL.md').writeAsString('''---
name: Shared Skill
description: Project version
---
''');

      final scanner = ClaudeToolsScanner(claudeDirOverride: claudeDir);
      final globalResult = await scanner.scanAll();
      final projectResult = await scanner.scanProjectTools(projectDir);

      final globalSkill =
          globalResult.skills.where((s) => s.id == 'shared-skill').first;
      final projectSkill =
          projectResult.skills.where((s) => s.id == 'shared-skill').first;

      expect(globalSkill.scope, 'global');
      expect(projectSkill.scope, 'project');
      expect(globalSkill.description, 'Global version');
      expect(projectSkill.description, 'Project version');
    });
  });
}
