import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';

void main() {
  group('QuickActionsService', () {
    late QuickActionsService service;

    setUp(() {
      service = QuickActionsService();
    });

    group('buildClaudeScript', () {
      test('generates AppleScript containing cd and claude command', () {
        final script = service.buildClaudeScript('/some/path');

        // Quotes are escaped for AppleScript embedding
        expect(script, contains(r'cd \"/some/path\" && claude'));
        expect(script, contains('tell application "Terminal"'));
        expect(script, contains('do script'));
      });

      test('handles paths with spaces', () {
        final script = service.buildClaudeScript('/my project/folder');

        expect(script, contains(r'cd \"/my project/folder\" && claude'));
      });
    });

    group('buildSkillLaunchCommand', () {
      test('builds claude "/<skill>" in the project directory', () {
        final cmd = service.buildSkillLaunchCommand('/some/path', 'a1-fix');

        expect(cmd, 'cd "/some/path" && claude "/a1-fix"');
      });

      test('does not double up an already-slashed skill name', () {
        final cmd = service.buildSkillLaunchCommand('/some/path', '/a1-plan');

        expect(cmd, 'cd "/some/path" && claude "/a1-plan"');
      });

      test('handles paths with spaces', () {
        final cmd =
            service.buildSkillLaunchCommand('/my project/folder', 'a1-execute');

        expect(cmd, 'cd "/my project/folder" && claude "/a1-execute"');
      });

      test('escapes double quotes in the path so it cannot break out', () {
        final cmd = service.buildSkillLaunchCommand('/a"b/c', 'a1-fix');

        expect(cmd, r'cd "/a\"b/c" && claude "/a1-fix"');
      });

      test('escapes double quotes and backslashes in the skill name', () {
        final cmd = service.buildSkillLaunchCommand('/p', r'we"ird\name');

        expect(cmd, r'cd "/p" && claude "/we\"ird\\name"');
      });
    });
  });
}
