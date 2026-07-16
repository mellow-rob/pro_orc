import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required RoadmapPhase feature,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: FeatureCard(feature: feature, colors: AppColors.dark),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final feature = RoadmapPhase(
    name: 'Projekt-Hub',
    status: 'done',
    start: DateTime(2026, 7, 1),
    finished: DateTime(2026, 7, 15),
    dependsOn: const ['Backend-API', 'Auth-Flow'],
  );

  group('FeatureCard — FR-003 compact accordion feature row', () {
    testWidgets('renders title', (tester) async {
      await pumpCard(tester, feature: feature);

      expect(find.text('Projekt-Hub'), findsOneWidget);
    });

    testWidgets('renders a status-colored dot (via Container/Key)', (
      tester,
    ) async {
      await pumpCard(tester, feature: feature);

      // The row must communicate status visually, not just via a tag
      // string — assert the status-dot Container exists at all.
      expect(find.byKey(const Key('feature_card_status_edge')), findsOneWidget);
    });

    testWidgets('renders a small status tag (mockup .ftag)', (tester) async {
      await pumpCard(tester, feature: feature);

      expect(find.text('FERTIG'), findsOneWidget);
    });

    testWidgets('no crash when start/finished/dependsOn are all empty', (
      tester,
    ) async {
      final noExtras = RoadmapPhase(name: 'Solo Feature', status: 'planned');

      await pumpCard(tester, feature: noExtras);

      expect(tester.takeException(), isNull);
      expect(find.text('GEPLANT'), findsOneWidget);
    });

    testWidgets('invokes onTap when the row is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: FeatureCard(
              feature: feature,
              colors: AppColors.dark,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Projekt-Hub'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('renders without a tap handler when onTap is omitted', (
      tester,
    ) async {
      await pumpCard(tester, feature: feature);

      expect(tester.takeException(), isNull);
    });
  });
}
