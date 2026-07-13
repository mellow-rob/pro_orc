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

      test('escapes shell metacharacters in the path so they cannot break out '
          'of the shell layer (double-escaped again for AppleScript)', () {
        final script = service.buildClaudeScript(
          '/tmp/"; rm -rf ~; echo "pwned',
        );

        // Shell layer: " -> \" ; AppleScript layer: \" -> \\\"
        expect(script, contains(r'cd \"/tmp/\\\"; rm -rf ~; echo \\\"pwned\"'));
        // The raw unescaped payload must never appear verbatim.
        expect(script, isNot(contains('/tmp/"; rm -rf ~; echo "pwned')));
      });
    });

    group('buildClaudePromptCommand', () {
      test('builds claude "<prompt>" in the project directory', () {
        final cmd = service.buildClaudePromptCommand(
          '/some/path',
          'fix the bug',
        );

        expect(cmd, 'cd "/some/path" && claude "fix the bug"');
      });

      test('escapes double quotes and backticks in the prompt', () {
        final cmd = service.buildClaudePromptCommand(
          '/some/path',
          'say "hi" `whoami`',
        );

        expect(cmd, r'cd "/some/path" && claude "say \"hi\" `whoami`"');
      });

      test('escapes double quotes in the path so it cannot break out of its '
          'quotes', () {
        final cmd = service.buildClaudePromptCommand('/a"b/c', 'prompt');

        expect(cmd, r'cd "/a\"b/c" && claude "prompt"');
      });

      test(
        'a prompt containing a double quote and semicolons is fully '
        'escaped and cannot break out of the double-quoted shell command',
        () {
          final cmd = service.buildClaudePromptCommand(
            '/proj',
            '"; touch /tmp/pwned; echo "',
          );

          expect(cmd, r'cd "/proj" && claude "\"; touch /tmp/pwned; echo \""');
          // The raw unescaped payload must never appear verbatim.
          expect(cmd, isNot(contains('"; touch /tmp/pwned; echo "')));
        },
      );
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
        final cmd = service.buildSkillLaunchCommand(
          '/my project/folder',
          'a1-execute',
        );

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

    group('isValidSkillName', () {
      test('accepts plausible skill names, with or without leading slash', () {
        expect(isValidSkillName('a1-fix'), isTrue);
        expect(isValidSkillName('/a1-plan'), isTrue);
        expect(isValidSkillName('vercel:deploy'), isTrue);
        expect(isValidSkillName('rem_sleep'), isTrue);
      });

      test('rejects shell metacharacters and whitespace', () {
        expect(isValidSkillName('a1-fix; rm -rf /'), isFalse);
        expect(isValidSkillName('foo bar'), isFalse);
        expect(isValidSkillName(r'$(whoami)'), isFalse);
        expect(isValidSkillName('"quote'), isFalse);
        expect(isValidSkillName(''), isFalse);
      });
    });
  });
}
