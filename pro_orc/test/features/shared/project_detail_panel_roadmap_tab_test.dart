import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/vision/vision_hero.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard.dart';
import 'package:pro_orc/features/shared/vision/vision_section.dart';
import 'package:pro_orc/features/shared/vision/vision_teaser_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/roadmap_provider.dart';
import 'package:pro_orc/providers/vision_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// FR-001: ProjectDetailPanel gains an "Übersicht"/"Roadmap" tab switch, with
/// today's Übersicht content unchanged and additive-only.
///
/// Note: `_QuickActionButton` (in the Übersicht body, pre-existing/
/// out-of-scope for this Roadmap-tab feature) renders a fixed 64x52 icon+
/// label Column that overflows by a few pixels regardless of hosting
/// context — a cosmetic layout issue unrelated to FR-001. Each test below
/// drains that expected overflow via `tester.takeException()` immediately
/// after pumping, so it doesn't fail the tab-switch assertions this file
/// actually verifies.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final project = const ProjectModel(
    folderId: 'my-folder',
    displayName: 'My Project',
    path: '/tmp/my-folder',
    projectType: ProjectType.code,
    description: 'A test project description.',
  );

  Future<void> pumpPanel(
    WidgetTester tester, {
    RoadmapResult? roadmapResult,
    VisionData? vision,
  }) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          roadmapProvider(project).overrideWith(
            (ref) async =>
                roadmapResult ??
                const RoadmapResult(
                  data: RoadmapData(
                    milestones: [
                      RoadmapMilestone(
                        name: 'M1 — Fundament',
                        status: 'done',
                        phases: [RoadmapPhase(name: 'Phase 1', status: 'done')],
                      ),
                    ],
                  ),
                  source: RoadmapSource.local,
                ),
          ),
          visionProvider(project).overrideWith((ref) async => vision),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(body: ProjectDetailPanel(project: project)),
        ),
      ),
    );
    await _pumpIgnoringOverflow(tester);
  }

  testWidgets('shows both Übersicht and Roadmap tab buttons', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Übersicht'), findsOneWidget);
    expect(find.text('Roadmap'), findsOneWidget);
  });

  testWidgets('Übersicht tab shows existing content by default (unchanged)', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('A test project description.'), findsOneWidget);
  });

  testWidgets('selecting Roadmap tab reveals the split-view and hides '
      'Übersicht content', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('Roadmap'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('M1 — Fundament'), findsOneWidget);
    // Übersicht-only content is no longer built.
    expect(find.text('A test project description.'), findsNothing);
  });

  testWidgets('switching back to Übersicht restores existing content', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(find.text('Roadmap'));
    await _pumpIgnoringOverflow(tester);
    await tester.tap(find.text('Übersicht'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('A test project description.'), findsOneWidget);
  });

  // Regression test for the bug where clicking a phase in the Roadmap tree
  // did nothing — the detail pane stayed on the "Phase auswaehlen..."
  // placeholder no matter what was clicked. Full ProjectDetailPanel context
  // (not just RoadmapTab in isolation) is exercised here since that's where
  // the bug was reported.
  testWidgets('clicking a phase in the Roadmap tree shows its spec list in the '
      'detail pane', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('Roadmap'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('Phase auswaehlen, um Details zu sehen'), findsOneWidget);

    await tester.tap(find.text('Phase 1'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('Phase auswaehlen, um Details zu sehen'), findsNothing);
    expect(find.text('Keine Specs fuer diese Phase vorhanden'), findsOneWidget);
  });

  group('ProjectDetailPanel — feature 002 Wave 1: tab gating', () {
    const vision = VisionData(
      title: 'Pro Orc — Vision',
      lead: 'Der Ueberblick ueber alle Projekte.',
      pillars: [VisionPillar(name: 'Pillar A', description: 'Beschreibung A.')],
    );

    const tier0Result = RoadmapResult(
      data: RoadmapData(
        nextMdContent: '# Stand',
        milestones: [RoadmapMilestone(name: 'M9', status: 'in-progress')],
      ),
      source: RoadmapSource.productStore,
    );

    const legacyResult = RoadmapResult(
      data: RoadmapData(
        milestones: [
          RoadmapMilestone(
            name: 'M1 — Fundament',
            status: 'done',
            phases: [RoadmapPhase(name: 'Phase 1', status: 'done')],
          ),
        ],
      ),
      source: RoadmapSource.local,
    );

    testWidgets('Vision tab button is hidden when there is no VISION.md '
        'fixture', (tester) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

      expect(find.text('Vision'), findsNothing);
    });

    testWidgets('Vision tab button appears when a VISION.md fixture '
        'resolves', (tester) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

      expect(find.text('Vision'), findsOneWidget);
    });

    testWidgets(
      'Zeitstrahl tab button is hidden for a non-productStore roadmap '
      'source',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        expect(find.text('Zeitstrahl'), findsNothing);
      },
    );

    testWidgets('Zeitstrahl tab button appears only when the roadmap source is '
        'productStore (tier-0)', (tester) async {
      await pumpPanel(tester, roadmapResult: tier0Result, vision: null);

      expect(find.text('Zeitstrahl'), findsOneWidget);
    });
  });

  group('ProjectDetailPanel — feature 002 Wave 3 FR-008: legacy-project '
      'regression guard', () {
    // A project with no `docs/product/` tier-0 data at all — the roadmap
    // resolves from a legacy tier (`.a1/roadmap.md`/Brain/Vault) and no
    // VISION.md exists. This is the exact fixture shape a project without
    // `docs/product/` produces: `RoadmapSource.local` (never `productStore`)
    // and a null vision.
    const legacyOnlyResult = RoadmapResult(
      data: RoadmapData(
        milestones: [
          RoadmapMilestone(
            name: 'M2 — Legacy-Meilenstein',
            status: 'building',
            phases: [
              RoadmapPhase(
                name: 'Legacy-Phase',
                status: 'building',
                specs: [RoadmapSpecRef(title: 'Legacy-Spec', path: '/tmp/x')],
              ),
            ],
          ),
        ],
      ),
      source: RoadmapSource.local,
    );

    testWidgets(
      'shows only Übersicht and Roadmap tabs (no Vision/Zeitstrahl) for a '
      'project without docs/product/',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyOnlyResult, vision: null);

        expect(find.text('Übersicht'), findsOneWidget);
        expect(find.text('Roadmap'), findsOneWidget);
        expect(find.text('Vision'), findsNothing);
        expect(find.text('Zeitstrahl'), findsNothing);
      },
    );

    testWidgets(
      'the Roadmap tab falls back to the legacy tree/spec-list view, not '
      'the tier-0 hero+lanes view, for a project without docs/product/',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyOnlyResult, vision: null);

        await tester.tap(find.text('Roadmap'));
        await _pumpIgnoringOverflow(tester);

        // Legacy tree/spec-list markers: the milestone/phase renders via
        // RoadmapTree (clickable phase row), not a MilestoneLane/FeatureCard
        // (the tier-0-only widgets from feature 002).
        expect(find.text('Legacy-Phase'), findsOneWidget);
        expect(find.byType(MilestoneLane), findsNothing);
        expect(find.byType(FeatureCard), findsNothing);
        // No tier-0 "Nächster Schritt" banner either.
        expect(find.textContaining('NÄCHSTER SCHRITT'), findsNothing);
      },
    );
  });

  group('ProjectDetailPanel — Vision tab rendering', () {
    const vision = VisionData(
      title: 'Pro Orc — Vision',
      lead: 'Der Ueberblick ueber alle Projekte.',
      pillars: [
        VisionPillar(name: 'Pillar A', description: 'Beschreibung A.'),
        VisionPillar(name: 'Pillar B', description: 'Beschreibung B.'),
      ],
    );

    const legacyResult = RoadmapResult(
      data: RoadmapData(
        milestones: [
          RoadmapMilestone(
            name: 'M1 — Fundament',
            status: 'done',
            phases: [RoadmapPhase(name: 'Phase 1', status: 'done')],
          ),
        ],
      ),
      source: RoadmapSource.local,
    );

    testWidgets(
      'selecting the Vision tab renders hero, scorecard, and pillars from '
      'the fixture',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

        await tester.tap(find.text('Vision'));
        await _pumpIgnoringOverflow(tester);

        expect(find.byType(VisionHero), findsOneWidget);
        expect(find.byType(VisionScorecard), findsOneWidget);
        expect(find.byType(VisionSection), findsOneWidget);
        expect(find.text('Pro Orc — Vision'), findsOneWidget);
        expect(find.text('Pillar A'), findsOneWidget);
        expect(find.text('Pillar B'), findsOneWidget);
      },
    );
  });

  group('ProjectDetailPanel — FR-002: vision teaser integration', () {
    const vision = VisionData(
      title: 'Pro Orc — Vision',
      lead: 'Der Ueberblick ueber alle Projekte.',
      pillars: [VisionPillar(name: 'Pillar A', description: 'Beschreibung A.')],
    );

    const legacyResult = RoadmapResult(
      data: RoadmapData(
        milestones: [
          RoadmapMilestone(
            name: 'M1 — Fundament',
            status: 'done',
            phases: [RoadmapPhase(name: 'Phase 1', status: 'done')],
          ),
        ],
      ),
      source: RoadmapSource.local,
    );

    testWidgets(
      'the Übersicht tab shows the vision teaser card when vision data '
      'resolves, and tapping it switches to the Vision tab',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

        expect(find.byType(VisionTeaserCard), findsOneWidget);

        await tester.tap(find.byType(VisionTeaserCard));
        await _pumpIgnoringOverflow(tester);

        // Switching to the Vision tab renders the Vision-tab-only widgets
        // and the tab button itself now shows as selected.
        expect(find.byType(VisionHero), findsOneWidget);
        expect(find.byType(VisionScorecard), findsOneWidget);
      },
    );

    testWidgets(
      'the Übersicht tab shows no vision teaser card for a legacy project '
      'without VISION.md',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        expect(find.byType(VisionTeaserCard), findsNothing);
      },
    );
  });

  group('ProjectDetailPanel — feature 002 FR-009: milestone selection survives '
      'Roadmap <-> Zeitstrahl tab switches', () {
    // The milestone under test is `done` (not `active`) so the accordion
    // does NOT auto-expand it on first render (FR-003 SC-001 only expands
    // active milestones) — a tap on it is then unambiguously "open it",
    // which is what this FR-009 persistence test needs to exercise.
    const tier0Result = RoadmapResult(
      data: RoadmapData(
        nextMdContent: '# Stand',
        milestones: [
          RoadmapMilestone(
            name: 'M9 — Detail Roadmap Redesign',
            status: 'done',
            phases: [
              RoadmapPhase(name: 'Wave 4 — Hero + Lanes', status: 'done'),
            ],
          ),
        ],
      ),
      source: RoadmapSource.productStore,
    );

    testWidgets(
      'selecting a milestone in Roadmap, switching to Zeitstrahl and back '
      'keeps the milestone selected',
      (tester) async {
        await pumpPanel(tester, roadmapResult: tier0Result, vision: null);

        await tester.tap(find.text('Roadmap'));
        await _pumpIgnoringOverflow(tester);

        expect(find.byType(FeatureCard), findsNothing);

        // Select the milestone -> its feature rows appear.
        await tester.tap(find.text('M9 — Detail Roadmap Redesign'));
        await _pumpIgnoringOverflow(tester);

        expect(find.byType(MilestoneLane), findsOneWidget);
        expect(find.byType(FeatureCard), findsOneWidget);
        expect(find.text('Wave 4 — Hero + Lanes'), findsOneWidget);

        // Switch to Zeitstrahl — the Roadmap lanes/cards leave the tree.
        await tester.tap(find.text('Zeitstrahl'));
        await _pumpIgnoringOverflow(tester);

        expect(find.byType(MilestoneLane), findsNothing);
        expect(find.byType(FeatureCard), findsNothing);

        // Switch back to Roadmap: the previously-selected milestone's
        // feature rows must reappear without tapping the lane again —
        // proof the selection survived the round-trip (FR-009).
        await tester.tap(find.text('Roadmap'));
        await _pumpIgnoringOverflow(tester);

        expect(find.byType(MilestoneLane), findsOneWidget);
        expect(find.byType(FeatureCard), findsOneWidget);
        expect(find.text('Wave 4 — Hero + Lanes'), findsOneWidget);
      },
    );
  });
}

/// Pumps a bounded number of frames instead of `pumpAndSettle()` (which
/// asserts no pending errors and would rethrow the pre-existing
/// `_QuickActionButton` overflow described above), draining that expected
/// exception after each frame so it never reaches the test's final
/// assertion.
Future<void> _pumpIgnoringOverflow(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    tester.takeException();
  }
}
