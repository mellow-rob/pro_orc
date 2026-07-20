import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/vercel_detection_service.dart';

void main() {
  group('VercelDetectionService', () {
    test(
      'isAvailable() returns true when which and whoami both succeed',
      () async {
        final service = VercelDetectionService(
          whichCommand: 'true', // exits 0 regardless of args
          vercelCommand: 'true',
        );

        final available = await service.isAvailable();

        expect(available, isTrue);
      },
    );

    test(
      'isAvailable() returns false when which fails (CLI not installed)',
      () async {
        final service = VercelDetectionService(
          whichCommand: 'false', // exits 1 regardless of args
          vercelCommand: 'true',
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );

    test(
      'isAvailable() returns false when whoami fails (not logged in)',
      () async {
        final service = VercelDetectionService(
          whichCommand: 'true',
          vercelCommand: 'false', // whoami subcommand also exits 1
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );

    test(
      'isAvailable() returns false (no crash) for a nonexistent binary',
      () async {
        final service = VercelDetectionService(
          whichCommand: 'which_nonexistent_binary_xyz',
        );

        final available = await service.isAvailable();

        expect(available, isFalse);
      },
    );
  });
}
