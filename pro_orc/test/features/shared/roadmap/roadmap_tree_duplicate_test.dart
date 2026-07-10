import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tree.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  group('RoadmapTree — single-phase duplicate collapse', () {
    testWidgets(
        'collapses a milestone with one identically-named phase into a '
        'single clickable row', (tester) async {
      const milestone = RoadmapMilestone(
        name: '006-deal-project-invoice-chain',
        status: 'in_progress',
        phases: [
          RoadmapPhase(
            name: '006-deal-project-invoice-chain',
            status: 'in_progress',
          ),
        ],
      );

      RoadmapPhase? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: RoadmapTree(
              milestones: const [milestone],
              colors: AppColors.dark,
              accent: AppColors.dark.cyan,
              onPhaseSelected: (phase) => selected = phase,
            ),
          ),
        ),
      );

      // Exactly one occurrence of the name — not one for the milestone row
      // and a second for the phase row underneath.
      expect(find.text('006-deal-project-invoice-chain'), findsOneWidget);

      await tester.tap(find.text('006-deal-project-invoice-chain'));
      await tester.pump();

      expect(selected?.name, '006-deal-project-invoice-chain');
    });

    testWidgets('keeps the nested tree when phase names differ from the '
        'milestone name', (tester) async {
      const milestone = RoadmapMilestone(
        name: 'M6 — Selbstlernendes OS',
        status: 'done',
        phases: [
          RoadmapPhase(name: 'M6-learning-loop', status: 'done'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: RoadmapTree(
              milestones: const [milestone],
              colors: AppColors.dark,
              accent: AppColors.dark.cyan,
            ),
          ),
        ),
      );

      expect(find.text('M6 — Selbstlernendes OS'), findsOneWidget);
      expect(find.text('M6-learning-loop'), findsOneWidget);
    });

    testWidgets(
        'keeps the nested tree when a milestone has multiple phases, even '
        'if one phase name matches the milestone name', (tester) async {
      const milestone = RoadmapMilestone(
        name: '048-tenant-feature-flags-mvp-dtg',
        status: 'in_progress',
        phases: [
          RoadmapPhase(
            name: '048-tenant-feature-flags-mvp-dtg',
            status: 'in_progress',
          ),
          RoadmapPhase(name: 'follow-up', status: 'planning'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: RoadmapTree(
              milestones: const [milestone],
              colors: AppColors.dark,
              accent: AppColors.dark.cyan,
            ),
          ),
        ),
      );

      // Two rows: the milestone header row and the two phase rows (one of
      // which repeats the milestone's name — expected here since there's
      // more than one phase, so the collapse rule does not apply).
      expect(find.text('048-tenant-feature-flags-mvp-dtg'), findsNWidgets(2));
      expect(find.text('follow-up'), findsOneWidget);
    });
  });
}
