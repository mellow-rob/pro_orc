import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard_data.dart';
import 'package:pro_orc/features/shared/vision/vision_teaser_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  const vision = VisionData(
    title: 'Pro Orc — Vision',
    lead: 'Pro Orc ist das Dashboard und der Launcher fuer alle Projekte.',
  );

  const scorecard = VisionScorecardData(
    milestonesDone: 8,
    milestonesActive: 1,
    featuresTotal: 10,
    featuresDone: 8,
  );

  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onTap}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: VisionTeaserCard(
            vision: vision,
            scorecard: scorecard,
            colors: AppColors.dark,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('VisionTeaserCard — FR-002', () {
    testWidgets('renders the vision lead sentence', (tester) async {
      await pumpCard(tester);

      expect(
        find.text(
          'Pro Orc ist das Dashboard und der Launcher fuer alle Projekte.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the "Vision ansehen" call to action', (tester) async {
      await pumpCard(tester);

      expect(find.text('Vision ansehen →'), findsOneWidget);
    });

    testWidgets('renders all 4 real counts from the scorecard', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.text('8'), findsNWidgets(2)); // milestonesDone + featuresDone
      expect(find.text('1'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Meilensteine fertig'), findsOneWidget);
      expect(find.text('Meilensteine aktiv'), findsOneWidget);
      expect(find.text('Features gesamt'), findsOneWidget);
      expect(find.text('Features fertig'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped anywhere on the card', (
      tester,
    ) async {
      var tapped = false;
      await pumpCard(tester, onTap: () => tapped = true);

      await tester.tap(find.byType(VisionTeaserCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('truncates a long lead to 2 lines with ellipsis, no crash', (
      tester,
    ) async {
      const longVision = VisionData(
        lead:
            'Dies ist ein sehr langer Lead-Satz, der garantiert ueber zwei '
            'Zeilen umbricht und mit Ellipsis abgeschnitten werden muss, '
            'damit die Teaser-Karte kompakt bleibt und nicht unbegrenzt '
            'waechst, egal wie lang der Vision-Text im VISION.md ist.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: VisionTeaserCard(
                vision: longVision,
                scorecard: scorecard,
                colors: AppColors.dark,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final textWidget = tester.widget<Text>(
        find.textContaining('Dies ist ein sehr langer'),
      );
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
