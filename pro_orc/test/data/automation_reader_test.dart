import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/automation_data.dart';
import 'package:pro_orc/data/models/harness_data.dart';
import 'package:pro_orc/data/services/automation_reader.dart';

const _claudePlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.n3ural.claude-nightly</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/claude</string>
    <string>--dangerously-skip-permissions</string>
    <string>--api-key</string>
    <string>sk-secret-1234567890</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';

const _unrelatedPlist = '''
<?xml version="1.0"?>
<plist version="1.0"><dict>
  <key>Label</key><string>com.google.keystone.agent</string>
  <key>ProgramArguments</key>
  <array><string>/opt/google/keystone</string></array>
</dict></plist>
''';

void main() {
  group('parseLaunchdPlist (pure)', () {
    test('extracts label + program and masks secrets when claude is present',
        () {
      final a = parseLaunchdPlist(_claudePlist);
      expect(a, isNotNull);
      expect(a!.name, 'com.n3ural.claude-nightly');
      expect(a.source, AutomationSource.launchd);
      expect(a.schedule, 'RunAtLoad');
      expect(a.command, contains('/usr/local/bin/claude'));
      // Secret after --api-key must be masked.
      expect(a.command, isNot(contains('sk-secret-1234567890')));
      expect(a.command, contains('••••'));
    });

    test('returns null for a plist that does not reference claude', () {
      expect(parseLaunchdPlist(_unrelatedPlist), isNull);
    });

    test('label helpers parse individual keys', () {
      expect(parsePlistLabel(_claudePlist), 'com.n3ural.claude-nightly');
      expect(parsePlistProgram(_unrelatedPlist), '/opt/google/keystone');
      expect(parsePlistRunAtLoad(_claudePlist), isTrue);
      expect(parsePlistRunAtLoad(_unrelatedPlist), isFalse);
    });
  });

  group('parseCrontab (pure)', () {
    test('keeps claude lines with schedule + masked command, skips others', () {
      const cron = '''
# a comment
0 9 * * * /usr/local/bin/claude --token abc123def456 run
30 2 * * 0 /usr/bin/backup.sh
''';
      final result = parseCrontab(cron);
      expect(result, hasLength(1));
      final a = result.single;
      expect(a.source, AutomationSource.cron);
      expect(a.schedule, '0 9 * * *');
      expect(a.command, startsWith('/usr/local/bin/claude'));
      expect(a.command, isNot(contains('abc123def456')));
    });

    test('empty output yields no automations', () {
      expect(parseCrontab(''), isEmpty);
    });
  });

  group('AutomationReader.read', () {
    test('combines launchd, cron (injected) and harness hooks', () async {
      // Temp LaunchAgents dir with one claude + one unrelated plist.
      final dir = await Directory.systemTemp.createTemp('launchagents_');
      addTearDown(() => dir.delete(recursive: true));
      await File(p.join(dir.path, 'com.n3ural.claude-nightly.plist'))
          .writeAsString(_claudePlist);
      await File(p.join(dir.path, 'com.google.keystone.agent.plist'))
          .writeAsString(_unrelatedPlist);

      final reader = AutomationReader(
        launchAgentsDirOverride: dir.path,
        readCrontab: () async => '0 9 * * * claude run\n',
      );

      final data = await reader.read(hooks: const [
        HarnessHook(
          event: 'Stop',
          matcher: '',
          command: 'session-to-obsidian.py',
          level: HarnessLevel.global,
        ),
      ]);

      expect(data.ofSource(AutomationSource.launchd), hasLength(1));
      expect(data.ofSource(AutomationSource.cron), hasLength(1));
      expect(data.ofSource(AutomationSource.hook), hasLength(1));
      expect(data.ofSource(AutomationSource.hook).single.name, 'Stop');
    });

    test('missing LaunchAgents dir + no crontab yields empty (honest state)',
        () async {
      final reader = AutomationReader(
        launchAgentsDirOverride:
            p.join(Directory.systemTemp.path, 'no_such_launchagents_xyz'),
        readCrontab: () async => null,
      );

      final data = await reader.read();
      expect(data.isEmpty, isTrue);
    });
  });
}
