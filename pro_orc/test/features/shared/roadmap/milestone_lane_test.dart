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
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final milestoneWithTarget = RoadmapMilestone(
    name: 'M9 — Detail Roadmap Redesign',
    status: 'in-progress',
    target: DateTime(2026, 8),
  );

  group('MilestoneLane — FR-013/FR-005', () {
    testWidgets('renders title, mono id-chip and a status dot (mockup style)', (
      tester,
    ) async {
      await pumpLane(tester, milestone: milestoneWithTarget);

      expect(find.text('M9 — Detail Roadmap Redesign'), findsOneWidget);
      // Mockup `#roadmap .lane li` shows a status dot + mono id-chip (e.g.
      // `m9`) in front of the title, not a full status-word badge.
      expect(find.text('m9'), findsOneWidget);
    });

    testWidgets('renders target date when present', (tester) async {
      await pumpLane(tester, milestone: milestoneWithTarget);

      expect(find.textContaining('2026'), findsOneWidget);
    });

    testWidgets('renders no date text when target is null', (tester) async {
      const milestoneNoTarget = RoadmapMilestone(
        name: 'M10 — Unscheduled',
        status: 'planned',
      );

      await pumpLane(tester, milestone: milestoneNoTarget);

      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('is tappable and invokes onTap', (tester) async {
      var tapped = false;
      await pumpLane(
        tester,
        milestone: milestoneWithTarget,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(MilestoneLane));
      expect(tapped, isTrue);
    });

    testWidgets('reflects selected state without crashing', (tester) async {
      await pumpLane(tester, milestone: milestoneWithTarget, selected: true);

      expect(tester.takeException(), isNull);
    });
  });
}
