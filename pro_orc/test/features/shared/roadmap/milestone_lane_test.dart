import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Future<void> pumpLane(
    WidgetTester tester, {
    required RoadmapMilestone milestone,
    bool selected = false,
    bool expanded = false,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: MilestoneLane(
            milestone: milestone,
            colors: AppColors.dark,
            accent: AppColors.dark.cyan,
            selected: selected,
            expanded: expanded,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final milestoneWithFeatures = RoadmapMilestone(
    name: 'M9 — Detail Roadmap Redesign',
    status: 'in-progress',
    phases: const [RoadmapPhase(name: 'Feature A', status: 'done')],
  );

  group('MilestoneLane — FR-003 (mockup v2 accordion row)', () {
    testWidgets('renders title, mono id-chip and a status dot (mockup style)', (
      tester,
    ) async {
      await pumpLane(tester, milestone: milestoneWithFeatures);

      expect(find.text('M9 — Detail Roadmap Redesign'), findsOneWidget);
      // Mockup `#roadmap .m-row` shows a status dot + mono id-chip (e.g.
      // `m9`) in front of the title, not a full status-word badge.
      expect(find.text('m9'), findsOneWidget);
    });

    testWidgets('renders the right-aligned "<n> Features" meta label', (
      tester,
    ) async {
      await pumpLane(tester, milestone: milestoneWithFeatures);

      expect(find.text('1 Feature'), findsOneWidget);
    });

    testWidgets('appends a checkmark to the meta label for a done milestone', (
      tester,
    ) async {
      final doneMilestone = RoadmapMilestone(
        name: 'M1 — Fertig',
        status: 'done',
        phases: const [
          RoadmapPhase(name: 'Feature A', status: 'done'),
          RoadmapPhase(name: 'Feature B', status: 'done'),
        ],
      );

      await pumpLane(tester, milestone: doneMilestone);

      expect(find.text('2 Features ✓'), findsOneWidget);
    });

    testWidgets('renders a placeholder meta label for a milestone with zero '
        'features', (tester) async {
      const milestoneNoFeatures = RoadmapMilestone(
        name: 'M10 — Unscheduled',
        status: 'planned',
      );

      await pumpLane(tester, milestone: milestoneNoFeatures);

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('is tappable and invokes onTap', (tester) async {
      var tapped = false;
      await pumpLane(
        tester,
        milestone: milestoneWithFeatures,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(MilestoneLane));
      expect(tapped, isTrue);
    });

    testWidgets('reflects selected state without crashing', (tester) async {
      await pumpLane(tester, milestone: milestoneWithFeatures, selected: true);

      expect(tester.takeException(), isNull);
    });

    testWidgets('rotates the chevron when expanded, without crashing', (
      tester,
    ) async {
      await pumpLane(tester, milestone: milestoneWithFeatures, expanded: true);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
