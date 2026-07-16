import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lanes_view.dart';
import 'package:pro_orc/features/shared/roadmap/structured_spec_renderer.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  // `MilestoneLanesView` reports the most-recently-toggled milestone via
  // `onMilestoneSelected`, but owns its own per-milestone expand/collapse
  // accordion state internally (FR-003). `_SelectionHost` below stands in
  // for the real parent (`_RoadmapHeroView` in `roadmap_tab.dart`), holding
  // `selectedMilestone` in real widget state so the controlled-value
  // contract (used for cross-tab persistence, FR-009) is exercised exactly
  // as production code drives it.
  Future<void> pumpView(
    WidgetTester tester, {
    required List<RoadmapMilestone> milestones,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(body: _SelectionHost(milestones: milestones)),
      ),
    );
    await tester.pumpAndSettle();
  }

  final activeMilestoneWithFeatures = RoadmapMilestone(
    name: 'M9 — Detail Roadmap Redesign',
    status: 'in-progress',
    phases: const [
      RoadmapPhase(name: 'Feature A', status: 'done'),
      RoadmapPhase(name: 'Feature B', status: 'planned'),
    ],
  );

  const doneMilestoneWithoutFeatures = RoadmapMilestone(
    name: 'M10 — Leer',
    status: 'done',
  );

  group('MilestoneLanesView — FR-003 accordion', () {
    testWidgets('renders one MilestoneLane per milestone', (tester) async {
      await pumpView(
        tester,
        milestones: [activeMilestoneWithFeatures, doneMilestoneWithoutFeatures],
      );

      expect(find.byType(MilestoneLane), findsNWidgets(2));
    });

    testWidgets(
      'SC-001: only the active milestone starts expanded — its feature '
      'rows show, nothing else',
      (tester) async {
        await pumpView(
          tester,
          milestones: [
            activeMilestoneWithFeatures,
            doneMilestoneWithoutFeatures,
          ],
        );

        expect(find.byType(FeatureCard), findsNWidgets(2));
        expect(find.text('Feature A'), findsOneWidget);
        expect(find.text('Feature B'), findsOneWidget);
      },
    );

    testWidgets(
      'a milestone without feature specs shows the placeholder text when '
      'its accordion is expanded',
      (tester) async {
        await pumpView(tester, milestones: [doneMilestoneWithoutFeatures]);

        await tester.tap(find.text('M10 — Leer'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Keine Feature-Spec-Dateien fuer diesen Meilenstein hinterlegt.',
          ),
          findsOneWidget,
        );
        expect(find.byType(FeatureCard), findsNothing);
      },
    );

    testWidgets('tapping an expanded milestone collapses it again', (
      tester,
    ) async {
      await pumpView(tester, milestones: [activeMilestoneWithFeatures]);

      expect(find.byType(FeatureCard), findsNWidgets(2));

      await tester.tap(find.text('M9 — Detail Roadmap Redesign'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureCard), findsNothing);
    });

    testWidgets('tapping a collapsed done/planned milestone expands it '
        'without collapsing the already-expanded active one', (tester) async {
      await pumpView(
        tester,
        milestones: [activeMilestoneWithFeatures, doneMilestoneWithoutFeatures],
      );

      expect(find.byType(FeatureCard), findsNWidgets(2));

      await tester.tap(find.text('M10 — Leer'));
      await tester.pumpAndSettle();

      // Both accordions are now open: the active milestone's 2 feature rows
      // plus the newly-expanded done milestone's placeholder text.
      expect(find.byType(FeatureCard), findsNWidgets(2));
      expect(
        find.text(
          'Keine Feature-Spec-Dateien fuer diesen Meilenstein hinterlegt.',
        ),
        findsOneWidget,
      );
    });
  });

  group('MilestoneLanesView — Wave 5 tap-to-spec navigation (FR-017)', () {
    testWidgets(
      'tapping a FeatureCard opens the StructuredSpecRenderer dialog',
      (tester) async {
        await pumpView(tester, milestones: [activeMilestoneWithFeatures]);

        expect(find.byType(FeatureCard), findsNWidgets(2));

        await tester.tap(find.text('Feature A'));
        await tester.pumpAndSettle();

        expect(find.byType(StructuredSpecRenderer), findsOneWidget);
        // No spec/plan path on this fixture -> graceful fallback, not a crash.
        expect(find.textContaining('Spec nicht verfügbar'), findsOneWidget);
      },
    );

    testWidgets(
      'the opened dialog carries the feature name and status through as '
      'the mockup title/status-pill header (FR-007)',
      (tester) async {
        await pumpView(tester, milestones: [activeMilestoneWithFeatures]);

        await tester.tap(find.text('Feature B'));
        await tester.pumpAndSettle();

        expect(find.byType(StructuredSpecRenderer), findsOneWidget);
        // Feature B's status is 'planned' -> mockup pill label 'GEPLANT',
        // rendered inside the StructuredSpecRenderer header specifically
        // (the FeatureCard behind the dialog also shows a 'GEPLANT' tag, so
        // scope the finder to the renderer subtree to avoid ambiguity).
        expect(
          find.descendant(
            of: find.byType(StructuredSpecRenderer),
            matching: find.text('GEPLANT'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('MilestoneLanesView — FR-003 status-grouped labels', () {
    testWidgets(
      'groups milestones into Aktiv/Fertig/Geplant labels in that display '
      'order',
      (tester) async {
        await pumpView(
          tester,
          milestones: [
            const RoadmapMilestone(name: 'M1 — Fertig', status: 'done'),
            const RoadmapMilestone(name: 'M2 — Aktiv', status: 'building'),
            const RoadmapMilestone(name: 'M3 — Geplant', status: 'planned'),
          ],
        );

        final labels = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .toList();
        final activeIndex = labels.indexOf('AKTIV');
        final doneIndex = labels.indexOf('FERTIG');
        final plannedIndex = labels.indexOf('GEPLANT');

        expect(activeIndex, greaterThanOrEqualTo(0));
        expect(doneIndex, greaterThan(activeIndex));
        expect(plannedIndex, greaterThan(doneIndex));
      },
    );

    testWidgets('omits a group label entirely when it has zero milestones', (
      tester,
    ) async {
      await pumpView(
        tester,
        milestones: [
          const RoadmapMilestone(name: 'M1 — Fertig', status: 'done'),
        ],
      );

      expect(find.text('FERTIG'), findsOneWidget);
      expect(find.text('AKTIV'), findsNothing);
      expect(find.text('GEPLANT'), findsNothing);
    });

    testWidgets('milestones with an unrecognized status default to the '
        'Aktiv group rather than being dropped', (tester) async {
      await pumpView(
        tester,
        milestones: [
          const RoadmapMilestone(
            name: 'M7 — Unbekannter Status',
            status: 'weird-custom-status',
          ),
        ],
      );

      expect(find.text('AKTIV'), findsOneWidget);
      expect(find.text('M7 — Unbekannter Status'), findsOneWidget);
    });
  });

  group('MilestoneLanesView — edge case: all milestones done', () {
    testWidgets(
      'when no milestone is active, all accordions start collapsed (even '
      'a done milestone with features) and the Aktiv label is absent',
      (tester) async {
        final doneWithFeatures = RoadmapMilestone(
          name: 'M1 — Fundament',
          status: 'done',
          phases: const [RoadmapPhase(name: 'Alte Feature', status: 'done')],
        );
        const doneWithoutFeatures = RoadmapMilestone(
          name: 'M2 — Aufraeumen',
          status: 'done',
        );

        await pumpView(
          tester,
          milestones: [doneWithFeatures, doneWithoutFeatures],
        );

        expect(find.byType(MilestoneLane), findsNWidgets(2));
        expect(find.byType(FeatureCard), findsNothing);
        expect(find.text('Alte Feature'), findsNothing);
        expect(find.text('AKTIV'), findsNothing);
        expect(find.text('FERTIG'), findsOneWidget);
      },
    );
  });

  group('MilestoneLanesView — SC-001 fixture with >=3 milestones', () {
    testWidgets(
      'initial render shows only milestone rows plus the active '
      'milestone\'s feature rows, nothing from done/planned milestones',
      (tester) async {
        final doneWithFeatures = RoadmapMilestone(
          name: 'M1 — Fundament',
          status: 'done',
          phases: const [RoadmapPhase(name: 'Alte Feature', status: 'done')],
        );
        const plannedMilestone = RoadmapMilestone(
          name: 'M11 — Zukunft',
          status: 'planned',
        );

        await pumpView(
          tester,
          milestones: [
            doneWithFeatures,
            activeMilestoneWithFeatures,
            plannedMilestone,
          ],
        );

        expect(find.byType(MilestoneLane), findsNWidgets(3));
        // Only the active milestone's 2 feature rows are visible.
        expect(find.byType(FeatureCard), findsNWidgets(2));
        expect(find.text('Feature A'), findsOneWidget);
        expect(find.text('Feature B'), findsOneWidget);
        expect(find.text('Alte Feature'), findsNothing);
      },
    );
  });
}

/// Test double for the real parent (`_RoadmapHeroView` in `roadmap_tab.dart`)
/// that owns the last-toggled milestone as hoisted state (feature 002,
/// FR-023) for cross-tab persistence. Holds `selectedMilestone` across
/// rebuilds so `MilestoneLanesView`'s controlled-value contract is
/// exercised the same way production code drives it.
class _SelectionHost extends StatefulWidget {
  const _SelectionHost({required this.milestones});

  final List<RoadmapMilestone> milestones;

  @override
  State<_SelectionHost> createState() => _SelectionHostState();
}

class _SelectionHostState extends State<_SelectionHost> {
  RoadmapMilestone? _selected;

  @override
  Widget build(BuildContext context) {
    return MilestoneLanesView(
      milestones: widget.milestones,
      colors: AppColors.dark,
      accent: AppColors.dark.cyan,
      selectedMilestone: _selected,
      onMilestoneSelected: (m) => setState(() => _selected = m),
    );
  }
}
