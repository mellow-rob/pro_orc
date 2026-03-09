import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/claude_detection_service.dart';

void main() {
  group('ClaudeDetectionService', () {
    group('on system with Claude installed', () {
      final service = ClaudeDetectionService();

      test('isClaudeInstalled() returns true', () async {
        final installed = await service.isClaudeInstalled();
        expect(installed, isTrue);
      });

      test('getClaudeVersion() returns non-null string', () async {
        final version = await service.getClaudeVersion();
        expect(version, isNotNull);
        expect(version, isNotEmpty);
      });
    });

    group('edge cases', () {
      test('returns false when which command is nonexistent binary', () async {
        final service = ClaudeDetectionService(
          whichCommand: 'which_nonexistent_binary_xyz',
        );
        final installed = await service.isClaudeInstalled();
        expect(installed, isFalse);
      });

      test('getClaudeVersion() returns null when claude binary not found',
          () async {
        final service = ClaudeDetectionService(
          claudeCommand: 'nonexistent_claude_binary_xyz',
        );
        final version = await service.getClaudeVersion();
        expect(version, isNull);
      });
    });
  });
}
