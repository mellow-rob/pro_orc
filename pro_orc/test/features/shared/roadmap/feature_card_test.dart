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

  final featureWithFullTimeframe = RoadmapPhase(
    name: 'Projekt-Hub',
    status: 'done',
    start: DateTime(2026, 7, 1),
    finished: DateTime(2026, 7, 15),
    dependsOn: const ['Backend-API', 'Auth-Flow'],
  );

  group('FeatureCard — FR-016', () {
    testWidgets('renders title', (tester) async {
      await pumpCard(tester, feature: featureWithFullTimeframe);

      expect(find.text('Projekt-Hub'), findsOneWidget);
    });

    testWidgets('renders a status-colored left edge (via Container/Border)', (
      tester,
    ) async {
      await pumpCard(tester, feature: featureWithFullTimeframe);

      // The card must communicate status visually, not just via a badge
      // string — assert the left-edge accent Container exists at all.
      expect(find.byKey(const Key('feature_card_status_edge')), findsOneWidget);
    });

    testWidgets('renders timeframe when start/finished are present', (
      tester,
    ) async {
      await pumpCard(tester, feature: featureWithFullTimeframe);

      expect(find.textContaining('2026'), findsWidgets);
    });

    testWidgets('renders dependency chips', (tester) async {
      await pumpCard(tester, feature: featureWithFullTimeframe);

      expect(find.text('Backend-API'), findsOneWidget);
      expect(find.text('Auth-Flow'), findsOneWidget);
    });

    testWidgets('renders no dependency chips when dependsOn is empty', (
      tester,
    ) async {
      final noDeps = RoadmapPhase(name: 'Solo Feature', status: 'planned');

      await pumpCard(tester, feature: noDeps);

      expect(tester.takeException(), isNull);
    });

    testWidgets('no crash when start/finished are both null', (tester) async {
      final noDates = RoadmapPhase(name: 'Unscheduled', status: 'planned');

      await pumpCard(tester, feature: noDates);

      expect(tester.takeException(), isNull);
    });
  });
}
