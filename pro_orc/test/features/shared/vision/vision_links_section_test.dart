import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/shared/vision/vision_links_section.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required List<VisionLink> links,
    QuickActionsService? qa,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: VisionLinksSection(
            links: links,
            colors: AppColors.dark,
            qa: qa ?? QuickActionsService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('VisionLinksSection — FR-005', () {
    testWidgets('renders nothing (no header chrome) when links is empty', (
      tester,
    ) async {
      await pumpSection(tester, links: const []);

      expect(find.text('LINKS'), findsNothing);
      expect(find.byType(VisionLinksSection), findsOneWidget);
    });

    testWidgets('renders a chip with the title for each link', (
      tester,
    ) async {
      await pumpSection(
        tester,
        links: const [
          VisionLink(
            title: 'GitHub Repo',
            target: 'https://github.com/example/pro-orc',
            isWeb: true,
          ),
          VisionLink(
            title: 'Projektordner',
            target: '/tmp/pro-orc',
            isWeb: false,
          ),
        ],
      );

      expect(find.text('LINKS'), findsOneWidget);
      expect(find.text('GitHub Repo'), findsOneWidget);
      expect(find.text('Projektordner'), findsOneWidget);
    });

    testWidgets('tapping a local link whose path does not exist shows a '
        'graceful failure indicator, no crash', (tester) async {
      await pumpSection(
        tester,
        links: const [
          VisionLink(
            title: 'Fehlt',
            target: '/nonexistent/path/does-not-exist',
            isWeb: false,
          ),
        ],
      );

      // The tap handler awaits real file-system I/O
      // (FileSystemEntity.isDirectory/isFile), which never resolves inside
      // testWidgets' default fake-async zone — the tap itself (not just a
      // delay afterwards) must run inside tester.runAsync() so the real
      // event loop actually progresses that I/O.
      await tester.runAsync(() async {
        await tester.tap(find.text('Fehlt'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Pfad nicht gefunden'), findsOneWidget);
    });
  });
}
