import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lanes_view.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester, {
    required List<RoadmapMilestone> milestones,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: MilestoneLanesView(
            milestones: milestones,
            colors: AppColors.dark,
            accent: AppColors.dark.cyan,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final milestoneWithFeatures = RoadmapMilestone(
    name: 'M9 — Detail Roadmap Redesign',
    status: 'in-progress',
    phases: [
      RoadmapPhase(name: 'Feature A', status: 'done'),
      RoadmapPhase(name: 'Feature B', status: 'planned'),
    ],
  );

  const milestoneWithoutFeatures = RoadmapMilestone(
    name: 'M10 — Leer',
    status: 'planned',
  );

  group('MilestoneLanesView — FR-013/FR-014/FR-016', () {
    testWidgets('renders one MilestoneLane per milestone', (tester) async {
      await pumpView(
        tester,
        milestones: [milestoneWithFeatures, milestoneWithoutFeatures],
      );

      expect(find.byType(MilestoneLane), findsNWidgets(2));
    });

    testWidgets('tapping a lane shows its features as FeatureCards (FR-016)', (
      tester,
    ) async {
      await pumpView(tester, milestones: [milestoneWithFeatures]);

      expect(find.byType(FeatureCard), findsNothing);

      await tester.tap(find.text('M9 — Detail Roadmap Redesign'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureCard), findsNWidgets(2));
      expect(find.text('Feature A'), findsOneWidget);
      expect(find.text('Feature B'), findsOneWidget);
    });

    testWidgets(
      'tapping a lane with zero features shows explicit "keine Features" '
      'state (FR-014)',
      (tester) async {
        await pumpView(tester, milestones: [milestoneWithoutFeatures]);

        await tester.tap(find.text('M10 — Leer'));
        await tester.pumpAndSettle();

        expect(
          find.text('Keine Features fuer diesen Meilenstein'),
          findsOneWidget,
        );
        expect(find.byType(FeatureCard), findsNothing);
      },
    );

    testWidgets('no lane is selected initially — no feature cards shown', (
      tester,
    ) async {
      await pumpView(tester, milestones: [milestoneWithFeatures]);

      expect(find.byType(FeatureCard), findsNothing);
      expect(find.text('Keine Features fuer diesen Meilenstein'), findsNothing);
    });

    testWidgets('selecting a second lane replaces the first selection', (
      tester,
    ) async {
      await pumpView(
        tester,
        milestones: [milestoneWithFeatures, milestoneWithoutFeatures],
      );

      await tester.tap(find.text('M9 — Detail Roadmap Redesign'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureCard), findsNWidgets(2));

      await tester.tap(find.text('M10 — Leer'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureCard), findsNothing);
      expect(
        find.text('Keine Features fuer diesen Meilenstein'),
        findsOneWidget,
      );
    });
  });
}
