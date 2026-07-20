import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';

void main() {
  group('GhDetectionService', () {
    test(
      'isAvailable() returns true when which and auth status both succeed',
      () async {
        final service = GhDetectionService(
          whichCommand: 'true', // exits 0 regardless of args
          ghCommand: 'true',
        );

        final available = await service.isAvailable();

        expect(available, isTrue);
      },
    );

    test(
      'isAvailable() returns false when which fails (CLI not installed)',
      () async {
        final service = GhDetectionService(
          whichCommand: 'false', // exits 1 regardless of args
          ghCommand: 'true',
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );

    test(
      'isAvailable() returns false when auth status fails (not logged in)',
      () async {
        final service = GhDetectionService(
          whichCommand: 'true',
          ghCommand: 'false', // auth status subcommand also exits 1
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );

    test(
      'isAvailable() returns false (no crash) for a nonexistent binary',
      () async {
        final service = GhDetectionService(
          whichCommand: 'which_nonexistent_binary_xyz',
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );
  });
}
