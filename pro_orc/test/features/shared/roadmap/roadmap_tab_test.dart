import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/roadmap/offline_fallback_badge.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_hero.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tab.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_timeline_view.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_tree.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_view_toggle.dart';
import 'package:pro_orc/providers/roadmap_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  final project = const ProjectModel(
    folderId: 'my-folder',
    displayName: 'My Project',
    path: '/tmp/my-folder',
    projectType: ProjectType.code,
  );

  Future<void> pumpTab(
    WidgetTester tester, {
    required RoadmapResult result,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roadmapProvider(project).overrideWith((ref) async => result),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: RoadmapTab(project: project, accent: AppColors.dark.cyan),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const populatedData = RoadmapData(
    milestones: [
      RoadmapMilestone(
        name: 'M1 — Fundament',
        status: 'done',
        phases: [
          RoadmapPhase(name: 'Phase 1: Setup', status: 'done'),
          RoadmapPhase(name: 'Phase 2: Build', status: 'in_progress'),
        ],
      ),
    ],
  );

  group('RoadmapTab — FR-001/FR-003 tree + badges', () {
    testWidgets('renders milestone and phase names with status badges', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      expect(find.text('M1 — Fundament'), findsOneWidget);
      expect(find.text('Phase 1: Setup'), findsOneWidget);
      expect(find.text('Phase 2: Build'), findsOneWidget);

      // Status vocabulary reused verbatim via deriveDisplayStatus —
      // 'done' -> 'Complete', 'in_progress' -> 'In Progress'.
      expect(find.text('Complete'), findsWidgets);
      expect(find.text('In Progress'), findsOneWidget);
    });
  });

  group('RoadmapTab — FR-016 split-view ratio, no resize handle', () {
    testWidgets('tree/detail panes use a fixed 35/65 flex ratio', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      final expandedWidgets = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .where((w) => w.flex == 35 || w.flex == 65)
          .toList();

      expect(expandedWidgets.where((w) => w.flex == 35), hasLength(1));
      expect(expandedWidgets.where((w) => w.flex == 65), hasLength(1));
    });

    testWidgets('no draggable resize handle exists', (tester) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      // No drag-based resize affordance anywhere in the tab. (Tap targets
      // like phase rows use GestureDetector internally via InkWell — that's
      // ordinary tap interaction, not a resize handle, so it's not asserted
      // against here.)
      expect(find.byType(Draggable), findsNothing);
    });
  });

  group('RoadmapTab — FR-010a offline-fallback badge', () {
    testWidgets('shows Offline-Fallback badge when source is vault', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.vault,
        ),
      );

      expect(find.byType(OfflineFallbackBadge), findsOneWidget);
      expect(find.text('Offline-Fallback'), findsOneWidget);
    });

    testWidgets('no badge when source is local', (tester) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      expect(find.byType(OfflineFallbackBadge), findsNothing);
    });

    testWidgets('no badge when source is brain', (tester) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.brain,
        ),
      );

      expect(find.byType(OfflineFallbackBadge), findsNothing);
    });
  });

  group('RoadmapTab — FR-007/FR-008 empty state', () {
    testWidgets('shows exact empty-state text when no data resolves at all', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: RoadmapData.empty,
          source: RoadmapSource.vault,
        ),
      );

      expect(find.text('Keine Roadmap-Daten vorhanden'), findsOneWidget);
      // No raw error widget/dialog.
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'shows the same empty state for a project whose slug matches nothing '
      '(slug mismatch treated identically to no data)',
      (tester) async {
        // A mismatched slug resolves through the same fallback chain and
        // yields RoadmapData.empty per FR-008 — verified here by directly
        // feeding that outcome (the repository-level slug-mismatch behavior
        // is covered by the Wave 1/2 repository tests).
        final mismatchedProject = project.copyWithFolderId('MISMATCHED-Slug');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              roadmapProvider(mismatchedProject).overrideWith(
                (ref) async => const RoadmapResult(
                  data: RoadmapData.empty,
                  source: RoadmapSource.vault,
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                extensions: const [AppColors.dark],
              ),
              home: Scaffold(
                body: RoadmapTab(
                  project: mismatchedProject,
                  accent: AppColors.dark.cyan,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Keine Roadmap-Daten vorhanden'), findsOneWidget);
      },
    );
  });

  group('RoadmapTab — FR-012/FR-013 read-only audit', () {
    testWidgets('no write-affordance widgets anywhere in the tab', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
    });

    testWidgets('no cross-spec search field exists', (tester) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.search), findsNothing);
    });
  });

  group('RoadmapTab — FR-004/FR-005 phase -> spec-list -> spec navigation', () {
    const dataWithManySpecs = RoadmapData(
      milestones: [
        RoadmapMilestone(
          name: 'M1 — Fundament',
          status: 'done',
          phases: [
            RoadmapPhase(
              name: 'Phase 1: Setup',
              status: 'done',
              specs: [
                RoadmapSpecRef(title: 'Spec A', path: '/tmp/spec-a.md'),
                RoadmapSpecRef(title: 'Spec B', path: '/tmp/spec-b.md'),
              ],
            ),
          ],
        ),
      ],
    );

    const dataWithOneSpec = RoadmapData(
      milestones: [
        RoadmapMilestone(
          name: 'M1 — Fundament',
          status: 'done',
          phases: [
            RoadmapPhase(
              name: 'Phase 1: Setup',
              status: 'done',
              specs: [RoadmapSpecRef(title: 'Only Spec', path: '/tmp/only.md')],
            ),
          ],
        ),
      ],
    );

    testWidgets('tapping a phase with many specs shows a spec list', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: dataWithManySpecs,
          source: RoadmapSource.local,
        ),
      );

      await tester.tap(find.text('Phase 1: Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Spec A'), findsOneWidget);
      expect(find.text('Spec B'), findsOneWidget);
    });

    testWidgets('tapping a phase with exactly one spec still shows a list', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: dataWithOneSpec,
          source: RoadmapSource.local,
        ),
      );

      await tester.tap(find.text('Phase 1: Setup'));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsWidgets);
      expect(find.text('Only Spec'), findsOneWidget);
    });

    testWidgets('tapping a phase with zero specs shows an explicit empty '
        'message', (tester) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      await tester.tap(find.text('Phase 1: Setup'));
      await tester.pumpAndSettle();

      expect(
        find.text('Keine Specs fuer diese Phase vorhanden'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a spec renders its full content', (tester) async {
      final specPath = File(
        '${Directory.systemTemp.path}/pro_orc_spec_viewer_test.md',
      );
      specPath.writeAsStringSync('# Hello Spec\n\nBody text.');
      addTearDown(() => specPath.deleteSync());

      final dataWithRealSpec = RoadmapData(
        milestones: [
          RoadmapMilestone(
            name: 'M1 — Fundament',
            status: 'done',
            phases: [
              RoadmapPhase(
                name: 'Phase 1: Setup',
                status: 'done',
                specs: [
                  RoadmapSpecRef(title: 'Real Spec', path: specPath.path),
                ],
              ),
            ],
          ),
        ],
      );

      await pumpTab(
        tester,
        result: RoadmapResult(
          data: dataWithRealSpec,
          source: RoadmapSource.local,
        ),
      );

      await tester.tap(find.text('Phase 1: Setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Real Spec'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello Spec'), findsOneWidget);
    });

    testWidgets(
      'a malformed/missing spec file shows a fallback message, no crash',
      (tester) async {
        const dataWithMissingSpec = RoadmapData(
          milestones: [
            RoadmapMilestone(
              name: 'M1 — Fundament',
              status: 'done',
              phases: [
                RoadmapPhase(
                  name: 'Phase 1: Setup',
                  status: 'done',
                  specs: [
                    RoadmapSpecRef(
                      title: 'Broken Spec',
                      path: '/nonexistent/path/broken.md',
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        await pumpTab(
          tester,
          result: const RoadmapResult(
            data: dataWithMissingSpec,
            source: RoadmapSource.local,
          ),
        );

        await tester.tap(find.text('Phase 1: Setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Broken Spec'));
        await tester.pumpAndSettle();

        expect(find.text('Spec konnte nicht angezeigt werden'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'RoadmapTab — FR-012/FR-013/FR-014/FR-016 tier-0 hero + lanes path',
    () {
      final productStoreData = RoadmapData(
        nextMdContent: '# Aktueller Stand\n\nWir bauen M9.',
        milestones: [
          RoadmapMilestone(
            name: 'M9 — Detail Roadmap Redesign',
            status: 'in-progress',
            target: DateTime(2026, 8),
            phases: [
              RoadmapPhase(
                name: 'Wave 4 — Hero + Lanes',
                status: 'done',
                start: DateTime(2026, 7, 1),
                finished: DateTime(2026, 7, 15),
                dependsOn: const ['Wave 3 — Tier-0 Reader'],
              ),
            ],
          ),
          const RoadmapMilestone(
            name: 'M10 — Leerer Meilenstein',
            status: 'planned',
          ),
        ],
      );

      testWidgets('renders the hero section with NEXT.md content', (
        tester,
      ) async {
        await pumpTab(
          tester,
          result: RoadmapResult(
            data: productStoreData,
            source: RoadmapSource.productStore,
          ),
        );

        expect(find.byType(RoadmapHero), findsOneWidget);
        expect(find.textContaining('Aktueller Stand'), findsOneWidget);
        // Legacy tree path must NOT render for the tier-0 source.
        expect(find.byType(RoadmapTree), findsNothing);
      });

      testWidgets('renders one MilestoneLane per milestone', (tester) async {
        await pumpTab(
          tester,
          result: RoadmapResult(
            data: productStoreData,
            source: RoadmapSource.productStore,
          ),
        );

        expect(find.byType(MilestoneLane), findsNWidgets(2));
      });

      testWidgets(
        'tapping a milestone lane reveals its features as cards (FR-016)',
        (tester) async {
          await pumpTab(
            tester,
            result: RoadmapResult(
              data: productStoreData,
              source: RoadmapSource.productStore,
            ),
          );

          expect(find.byType(FeatureCard), findsNothing);

          await tester.tap(find.text('M9 — Detail Roadmap Redesign'));
          await tester.pumpAndSettle();

          expect(find.byType(FeatureCard), findsOneWidget);
          expect(find.text('Wave 4 — Hero + Lanes'), findsOneWidget);
          expect(find.text('Wave 3 — Tier-0 Reader'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping a milestone lane with zero features shows the explicit '
        'German empty state (FR-014)',
        (tester) async {
          await pumpTab(
            tester,
            result: RoadmapResult(
              data: productStoreData,
              source: RoadmapSource.productStore,
            ),
          );

          await tester.tap(find.text('M10 — Leerer Meilenstein'));
          await tester.pumpAndSettle();

          expect(
            find.text('Keine Features fuer diesen Meilenstein'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('RoadmapTab — Wave 7 FR-022 view toggle', () {
    final productStoreData = RoadmapData(
      nextMdContent: '# Aktueller Stand\n\nWir bauen M9.',
      milestones: [
        RoadmapMilestone(
          name: 'M9 — Detail Roadmap Redesign',
          status: 'in-progress',
          start: DateTime(2026, 7),
          target: DateTime(2026, 8),
          phases: [
            RoadmapPhase(
              name: 'Wave 4 — Hero + Lanes',
              status: 'done',
              start: DateTime(2026, 7, 1),
              finished: DateTime(2026, 7, 15),
            ),
          ],
        ),
        const RoadmapMilestone(
          name: 'M10 — Leerer Meilenstein',
          status: 'planned',
        ),
      ],
    );

    testWidgets('starts in the lanes view with the toggle present', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: RoadmapResult(
          data: productStoreData,
          source: RoadmapSource.productStore,
        ),
      );

      expect(find.byType(RoadmapViewToggle), findsOneWidget);
      expect(find.byType(MilestoneLane), findsNWidgets(2));
      expect(find.byType(RoadmapTimelineView), findsNothing);
    });

    testWidgets('tapping "Zeitstrahl" switches the visible view from lanes to '
        'timeline', (tester) async {
      await pumpTab(
        tester,
        result: RoadmapResult(
          data: productStoreData,
          source: RoadmapSource.productStore,
        ),
      );

      await tester.tap(find.text('Zeitstrahl'));
      await tester.pumpAndSettle();

      expect(find.byType(RoadmapTimelineView), findsOneWidget);
      expect(find.byType(MilestoneLane), findsNothing);

      await tester.tap(find.text('Übersicht'));
      await tester.pumpAndSettle();

      expect(find.byType(MilestoneLane), findsNWidgets(2));
      expect(find.byType(RoadmapTimelineView), findsNothing);
    });

    testWidgets(
      'selecting a milestone in lanes, switching to timeline and back '
      'preserves the selection (FR-023)',
      (tester) async {
        await pumpTab(
          tester,
          result: RoadmapResult(
            data: productStoreData,
            source: RoadmapSource.productStore,
          ),
        );

        // Select the milestone with features -> its feature cards show up.
        await tester.tap(find.text('M9 — Detail Roadmap Redesign'));
        await tester.pumpAndSettle();
        expect(find.byType(FeatureCard), findsOneWidget);
        expect(find.text('Wave 4 — Hero + Lanes'), findsOneWidget);

        // Switch to the timeline view — lanes (and the selection UI) leave
        // the tree entirely.
        await tester.tap(find.text('Zeitstrahl'));
        await tester.pumpAndSettle();
        expect(find.byType(MilestoneLane), findsNothing);
        expect(find.byType(FeatureCard), findsNothing);
        expect(find.byType(RoadmapTimelineView), findsOneWidget);

        // Switch back to lanes: the previously-selected milestone's feature
        // cards must reappear without needing to tap the lane again — proof
        // the selection survived the round-trip (FR-023).
        await tester.tap(find.text('Übersicht'));
        await tester.pumpAndSettle();

        expect(find.byType(MilestoneLane), findsNWidgets(2));
        expect(find.byType(FeatureCard), findsOneWidget);
        expect(find.text('Wave 4 — Hero + Lanes'), findsOneWidget);
      },
    );
  });

  group('RoadmapTab — FR-011 "What\'s next" indicator', () {
    // Note: RoadmapTab no longer has a source for "current phase" (the GSD
    // legacy system that used to supply it was removed) — it always passes
    // `currentPhase: null` to WhatsNextIndicator, so only the graceful-hide
    // behavior is exercised here.
    testWidgets('hides gracefully when no current phase is parsable', (
      tester,
    ) async {
      await pumpTab(
        tester,
        result: const RoadmapResult(
          data: populatedData,
          source: RoadmapSource.local,
        ),
      );

      expect(find.textContaining('Was kommt als naechstes'), findsNothing);
    });
  });
}

/// Test-only helper: [ProjectModel] has no `copyWith`, so build a second
/// instance with a different `folderId` (the field used as the
/// Vault/Brain-facing slug) to simulate a slug-mismatch scenario.
extension _ProjectModelTestX on ProjectModel {
  ProjectModel copyWithFolderId(String folderId) => ProjectModel(
    folderId: folderId,
    displayName: displayName,
    path: path,
    projectType: projectType,
  );
}
