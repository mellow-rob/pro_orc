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

        expect(script, contains('cd "/some/path" && claude'));
        expect(script, contains('tell application "Terminal"'));
        expect(script, contains('do script'));
      });

      test('handles paths with spaces', () {
        final script = service.buildClaudeScript('/my project/folder');

        expect(script, contains('cd "/my project/folder" && claude'));
      });
    });
  });
}
