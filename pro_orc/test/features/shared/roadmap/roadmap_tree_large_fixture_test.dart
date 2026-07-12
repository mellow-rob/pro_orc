import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tree.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  group('RoadmapTree — FR-014 large-roadmap smoke test', () {
    testWidgets(
      'renders and scrolls a large fixture (dozens of milestones x phases) '
      'without throwing',
      (tester) async {
        final largeMilestones = List.generate(
          40,
          (i) => RoadmapMilestone(
            name: 'M$i — Milestone $i',
            status: i.isEven ? 'done' : 'building',
            phases: List.generate(
              6,
              (j) => RoadmapPhase(name: 'Phase $j of M$i', status: 'planning'),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [AppColors.dark],
            ),
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: RoadmapTree(
                  milestones: largeMilestones,
                  colors: AppColors.dark,
                  accent: AppColors.dark.cyan,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ListView), findsOneWidget);

        // Scroll through the tree — must not throw or drop frames-as-errors.
        await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.fling(find.byType(ListView), const Offset(0, 2000), 3000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
