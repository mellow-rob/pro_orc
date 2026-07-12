import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/harness_data.dart';
import 'package:pro_orc/data/services/harness_reader.dart';

void main() {
  group('HarnessReader', () {
    test(
      'reads hooks, permissions, env and inline MCP across three levels',
      () async {
        final claudeHome = await Directory.systemTemp.createTemp(
          'harness_home_',
        );
        addTearDown(() => claudeHome.delete(recursive: true));
        final project = await Directory.systemTemp.createTemp('harness_proj_');
        addTearDown(() => project.delete(recursive: true));

        await File(p.join(claudeHome.path, 'settings.json')).writeAsString('''
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "guard.sh"}]}
    ]
  },
  "permissions": {"allow": ["Read", "Bash(git *)"], "deny": ["Bash(rm *)"]},
  "env": {"FOO": "bar"},
  "mcpServers": {"global-srv": {"command": "node", "args": ["srv.js"]}}
}
''');

        final projClaude = Directory(p.join(project.path, '.claude'));
        await projClaude.create(recursive: true);
        await File(p.join(projClaude.path, 'settings.json')).writeAsString('''
{"permissions": {"ask": ["WebFetch"]}, "env": {"BAZ": "qux"}}
''');
        await File(
          p.join(projClaude.path, 'settings.local.json'),
        ).writeAsString('{"permissions": {"allow": ["Write"]}}');

        final reader = HarnessReader(claudeHomeDirOverride: claudeHome.path);
        final data = await reader.read(project.path);

        // Hooks (global only).
        expect(data.hooks, hasLength(1));
        expect(data.hooks.first.event, 'PreToolUse');
        expect(data.hooks.first.matcher, 'Bash');
        expect(data.hooks.first.command, 'guard.sh');
        expect(data.hooks.first.level, HarnessLevel.global);

        // Permissions carry their level.
        final allowGlobal = data.permissions.where(
          (x) => x.level == HarnessLevel.global && x.kind == 'allow',
        );
        expect(
          allowGlobal.map((x) => x.rule),
          containsAll(['Read', 'Bash(git *)']),
        );
        expect(
          data.permissions.any(
            (x) =>
                x.level == HarnessLevel.project &&
                x.kind == 'ask' &&
                x.rule == 'WebFetch',
          ),
          isTrue,
        );
        expect(
          data.permissions.any(
            (x) =>
                x.level == HarnessLevel.local &&
                x.kind == 'allow' &&
                x.rule == 'Write',
          ),
          isTrue,
        );

        // Env vars from both levels.
        expect(
          data.envVars.map((e) => '${e.key}=${e.value}'),
          containsAll(['FOO=bar', 'BAZ=qux']),
        );

        // Inline global MCP server with command detail.
        expect(data.mcpServers.any((m) => m.name == 'global-srv'), isTrue);
      },
    );

    test('reads project .mcp.json in both shapes', () async {
      final claudeHome = await Directory.systemTemp.createTemp('harness_home_');
      addTearDown(() => claudeHome.delete(recursive: true));
      final project = await Directory.systemTemp.createTemp('harness_proj_');
      addTearDown(() => project.delete(recursive: true));

      await File(p.join(project.path, '.mcp.json')).writeAsString(
        '{"mcpServers": {"proj-srv": {"url": "https://example.test/mcp"}}}',
      );

      final reader = HarnessReader(claudeHomeDirOverride: claudeHome.path);
      final data = await reader.read(project.path);

      final srv = data.mcpServers.firstWhere((m) => m.name == 'proj-srv');
      expect(srv.level, HarnessLevel.project);
      expect(srv.detail, 'https://example.test/mcp');
    });

    test('extracts H1 titles from rules, falling back to filename', () async {
      final claudeHome = await Directory.systemTemp.createTemp('harness_home_');
      addTearDown(() => claudeHome.delete(recursive: true));

      final rulesDir = Directory(p.join(claudeHome.path, 'rules', 'common'));
      await rulesDir.create(recursive: true);
      await File(
        p.join(rulesDir.path, 'testing.md'),
      ).writeAsString('# Testing Requirements\n\nsome body');
      await File(
        p.join(rulesDir.path, 'no-heading.md'),
      ).writeAsString('just text, no heading');

      final reader = HarnessReader(claudeHomeDirOverride: claudeHome.path);
      final data = await reader.read(null);

      final withH1 = data.rules.firstWhere(
        (r) => r.relativePath.endsWith('testing.md'),
      );
      expect(withH1.title, 'Testing Requirements');
      final noH1 = data.rules.firstWhere(
        (r) => r.relativePath.endsWith('no-heading.md'),
      );
      expect(noH1.title, 'no-heading.md');
    });

    test(
      'malformed JSON and missing files yield empty results, never throws',
      () async {
        final claudeHome = await Directory.systemTemp.createTemp(
          'harness_home_',
        );
        addTearDown(() => claudeHome.delete(recursive: true));

        // Broken global settings.
        await File(
          p.join(claudeHome.path, 'settings.json'),
        ).writeAsString('{ this is not json ');

        final reader = HarnessReader(claudeHomeDirOverride: claudeHome.path);
        // Project path that does not exist — no project files at all.
        final data = await reader.read('/tmp/definitely-not-a-project-xyz');

        expect(data.hooks, isEmpty);
        expect(data.permissions, isEmpty);
        expect(data.envVars, isEmpty);
        expect(data.mcpServers, isEmpty);
        expect(data.isEmpty, isTrue);
      },
    );

    test('sources point only to files that actually exist', () async {
      final claudeHome = await Directory.systemTemp.createTemp('harness_home_');
      addTearDown(() => claudeHome.delete(recursive: true));
      final project = await Directory.systemTemp.createTemp('harness_proj_');
      addTearDown(() => project.delete(recursive: true));

      await File(
        p.join(claudeHome.path, 'settings.json'),
      ).writeAsString('{"env": {"A": "1"}}');

      final reader = HarnessReader(claudeHomeDirOverride: claudeHome.path);
      final data = await reader.read(project.path);

      expect(data.sources.globalSettingsPath, isNotNull);
      // No project/.claude/settings.json was created.
      expect(data.sources.projectSettingsPath, isNull);
      expect(data.sources.localSettingsPath, isNull);
    });
  });
}
