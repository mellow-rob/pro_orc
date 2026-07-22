import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart'
    show MdFileInfo, ProjectModel;
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';
import 'package:pro_orc/features/shared/detail/links_tab_content.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/vision/vision_hero.dart';
import 'package:pro_orc/features/shared/vision/vision_links_section.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard.dart';
import 'package:pro_orc/features/shared/vision/vision_section.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/external_resources_provider.dart';
import 'package:pro_orc/providers/roadmap_provider.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/providers/vision_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// FR-001: ProjectDetailPanel's tab bar is Vision · Roadmap · Zeitstrahl —
/// Vision is always present and first (no separate Übersicht tab; FR-006
/// covers its legacy-only fallback content).
///
/// Note: `_QuickActionButton` (in the former Übersicht body, now absorbed
/// into the Vision tab) renders a fixed 64x52 icon+label Column that
/// overflows by a few pixels regardless of hosting context — a cosmetic
/// layout issue unrelated to this feature. Each test below drains that
/// expected overflow via `tester.takeException()` immediately after
/// pumping, so it doesn't fail the tab-switch assertions this file actually
/// verifies.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final defaultProject = const ProjectModel(
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
    ProjectModel? project,
    ProjectSessionData? sessionData,
    List<ExternalResource>? externalResources,
  }) async {
    final activeProject = project ?? defaultProject;

    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          roadmapProvider(activeProject).overrideWith(
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
          visionProvider(activeProject).overrideWith((ref) async => vision),
          // projectSessionsProvider does real disk I/O (scans
          // ~/.claude/projects) which never resolves inside flutter_test's
          // fake-async pump loop — overridden with a deterministic fixture,
          // same rationale as roadmapProvider/visionProvider above.
          projectSessionsProvider(activeProject.path).overrideWith(
            (ref) async => sessionData ?? ProjectSessionData.empty,
          ),
          // externalResourcesProvider does real disk I/O (detectExternalResources
          // reads .vercel/project.json, scans mdFiles, checks the Claude Memory
          // dir) — overridden the same way, default empty so existing tests
          // that don't care about the Links tab's auto-detected source stay
          // unaffected.
          externalResourcesProvider(
            activeProject,
          ).overrideWith((ref) async => externalResources ?? const []),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(body: ProjectDetailPanel(project: activeProject)),
        ),
      ),
    );
    await _pumpIgnoringOverflow(tester);
  }

  testWidgets('shows Vision and Roadmap tab buttons, no Übersicht button', (
    tester,
  ) async {
    await pumpPanel(tester, vision: null);

    expect(find.text('Vision'), findsOneWidget);
    expect(find.text('Roadmap'), findsOneWidget);
    expect(find.text('Übersicht'), findsNothing);
  });

  testWidgets('Vision tab shows the former-Übersicht content by default '
      '(no vision fixture)', (tester) async {
    await pumpPanel(tester, vision: null);

    expect(find.text('A test project description.'), findsOneWidget);
  });

  testWidgets('selecting Roadmap tab reveals the split-view and hides '
      'the former-Übersicht content', (tester) async {
    await pumpPanel(tester, vision: null);

    await tester.tap(find.text('Roadmap'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('M1 — Fundament'), findsOneWidget);
    expect(find.text('A test project description.'), findsNothing);
  });

  testWidgets('switching back to Vision restores the former-Übersicht '
      'content', (tester) async {
    await pumpPanel(tester, vision: null);

    await tester.tap(find.text('Roadmap'));
    await _pumpIgnoringOverflow(tester);
    await tester.tap(find.text('Vision'));
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
    await pumpPanel(tester, vision: null);

    await tester.tap(find.text('Roadmap'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('Phase auswaehlen, um Details zu sehen'), findsOneWidget);

    await tester.tap(find.text('Phase 1'));
    await _pumpIgnoringOverflow(tester);

    expect(find.text('Phase auswaehlen, um Details zu sehen'), findsNothing);
    expect(find.text('Keine Specs fuer diese Phase vorhanden'), findsOneWidget);
  });

  group('ProjectDetailPanel — FR-001/FR-006: tab gating', () {
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

    testWidgets('Vision tab button is present even without a VISION.md '
        'fixture (FR-006)', (tester) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

      expect(find.text('Vision'), findsOneWidget);
    });

    testWidgets('Vision tab button is present when a VISION.md fixture '
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

  group('ProjectDetailPanel — FR-006: legacy-project regression guard', () {
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
      'shows only Vision and Roadmap tabs (no Zeitstrahl) for a project '
      'without docs/product/, Vision rendering legacy-only content',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyOnlyResult, vision: null);

        expect(find.text('Vision'), findsOneWidget);
        expect(find.text('Roadmap'), findsOneWidget);
        expect(find.text('Zeitstrahl'), findsNothing);
        // FR-006: legacy-only content, no hero/pillars/scorecard.
        expect(find.text('A test project description.'), findsOneWidget);
        expect(find.byType(VisionHero), findsNothing);
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

  group('ProjectDetailPanel — Vision tab rendering (FR-003)', () {
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
      'the Vision tab renders hero, scorecard, pillars, AND the former-'
      'Übersicht content together, since it is now the default/first tab',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

        expect(find.byType(VisionHero), findsOneWidget);
        expect(find.byType(VisionScorecard), findsOneWidget);
        expect(find.byType(VisionSection), findsOneWidget);
        expect(find.text('Pro Orc — Vision'), findsOneWidget);
        expect(find.text('Pillar A'), findsOneWidget);
        expect(find.text('Pillar B'), findsOneWidget);
        // FR-003: former-Übersicht content is appended, not dropped.
        expect(find.text('A test project description.'), findsOneWidget);

        // SC-002: content order is hero -> pillars -> scorecard, not
        // hero -> scorecard -> pillars. Comparing vertical position (not
        // just presence) is what actually catches an order regression.
        final heroTop = tester.getTopLeft(find.byType(VisionHero)).dy;
        final sectionTop = tester.getTopLeft(find.byType(VisionSection)).dy;
        final scorecardTop = tester.getTopLeft(find.byType(VisionScorecard)).dy;
        expect(heroTop, lessThan(sectionTop));
        expect(sectionTop, lessThan(scorecardTop));
      },
    );

    testWidgets('renders the product version badge above the hero when '
        'present (FR-002)', (tester) async {
      const versionedVision = VisionData(
        title: 'Pro Orc — Vision',
        version: '2026.06 — Closed Beta',
        lead: 'Der Ueberblick ueber alle Projekte.',
      );

      await pumpPanel(
        tester,
        roadmapResult: legacyResult,
        vision: versionedVision,
      );

      expect(find.text('2026.06 — Closed Beta'), findsOneWidget);
    });

    testWidgets('renders no version badge when version is absent, rest of '
        'tab renders normally', (tester) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

      expect(find.byType(VisionHero), findsOneWidget);
    });

    testWidgets(
      'the Vision tab renders no VisionLinksSection even when the vision '
      'fixture has links — links moved to their own tab (feature 005)',
      (tester) async {
        const visionWithLinks = VisionData(
          title: 'Pro Orc — Vision',
          lead: 'Der Ueberblick ueber alle Projekte.',
          links: [
            VisionLink(
              title: 'GitHub Repo',
              target: 'https://github.com/example/pro-orc',
              isWeb: true,
            ),
          ],
        );

        await pumpPanel(
          tester,
          roadmapResult: legacyResult,
          vision: visionWithLinks,
        );

        expect(find.byType(VisionLinksSection), findsNothing);
      },
    );
  });

  group('ProjectDetailPanel — FR-001/FR-002: Links tab (feature 005)', () {
    const vision = VisionData(
      title: 'Pro Orc — Vision',
      lead: 'Der Ueberblick ueber alle Projekte.',
      links: [
        VisionLink(
          title: 'GitHub Repo',
          target: 'https://github.com/example/pro-orc',
          isWeb: true,
        ),
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
      'shows exactly 4 tab buttons (Vision, Roadmap, Zeitstrahl, Links) '
      'for a tier-0 project with a populated vision',
      (tester) async {
        const tier0Result = RoadmapResult(
          data: RoadmapData(
            nextMdContent: '# Stand',
            milestones: [RoadmapMilestone(name: 'M9', status: 'in-progress')],
          ),
          source: RoadmapSource.productStore,
        );

        await pumpPanel(tester, roadmapResult: tier0Result, vision: vision);

        expect(find.text('Vision'), findsOneWidget);
        expect(find.text('Roadmap'), findsOneWidget);
        expect(find.text('Zeitstrahl'), findsOneWidget);
        expect(find.text('Links'), findsOneWidget);
      },
    );

    testWidgets('the Links tab is present even for a legacy project with no '
        'docs/product/ at all (FR-002)', (tester) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

      expect(find.text('Links'), findsOneWidget);
    });

    testWidgets('selecting the Links tab renders the vision fixture\'s links '
        '(2026-07-22-links-tab-missing-sources-3: rendering consolidated '
        'into LinksTabContent, which merges manual VisionData.links with '
        'auto-detected resources — VisionLinksSection itself moved back to '
        'Vision-tab-only usage, no longer used by the Links tab)', (
      tester,
    ) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

      await tester.tap(find.text('Links'));
      await _pumpIgnoringOverflow(tester);

      expect(find.byType(LinksTabContent), findsOneWidget);
      expect(find.text('GitHub Repo'), findsOneWidget);
    });

    testWidgets(
      'selecting the Links tab shows a visible empty state when the vision '
      'fixture has zero links (FR-002/SC-003)',
      (tester) async {
        const visionNoLinks = VisionData(
          title: 'Pro Orc — Vision',
          lead: 'Der Ueberblick ueber alle Projekte.',
        );

        await pumpPanel(
          tester,
          roadmapResult: legacyResult,
          vision: visionNoLinks,
        );

        await tester.tap(find.text('Links'));
        await _pumpIgnoringOverflow(tester);

        expect(find.text('Keine Links konfiguriert'), findsOneWidget);
        expect(find.byType(VisionLinksSection), findsNothing);
      },
    );

    testWidgets(
      'selecting the Links tab shows a visible empty state for a legacy '
      'project with no VISION.md at all (FR-002/SC-003)',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        await tester.tap(find.text('Links'));
        await _pumpIgnoringOverflow(tester);

        expect(find.text('Keine Links konfiguriert'), findsOneWidget);
        expect(find.byType(VisionLinksSection), findsNothing);
      },
    );

    testWidgets('switching from Links to Roadmap and back preserves the '
        'selection-persistence contract (no crash, tab content restored)', (
      tester,
    ) async {
      await pumpPanel(tester, roadmapResult: legacyResult, vision: vision);

      await tester.tap(find.text('Links'));
      await _pumpIgnoringOverflow(tester);
      expect(find.text('GitHub Repo'), findsOneWidget);

      await tester.tap(find.text('Roadmap'));
      await _pumpIgnoringOverflow(tester);
      expect(find.text('M1 — Fundament'), findsOneWidget);
      expect(find.text('GitHub Repo'), findsNothing);

      await tester.tap(find.text('Links'));
      await _pumpIgnoringOverflow(tester);
      expect(find.text('GitHub Repo'), findsOneWidget);
    });
  });

  group('ProjectDetailPanel — Links tab: auto-detected external resources '
      '(2026-07-22-links-tab-missing-sources-3)', () {
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

    // The "Niimo shape" from the bug report: a project with a git remote
    // (githubUrl set) but no docs/product/VISION.md at all.
    final niimoShapedProject = ProjectModel(
      folderId: 'niimo',
      displayName: 'Niimo',
      path: '/tmp/niimo',
      projectType: ProjectType.code,
      git: const GitData(githubUrl: 'https://github.com/N3URAL-A1/niimo'),
    );

    testWidgets('a project with a git remote but no VISION.md shows the '
        'GitHub chip on the Links tab, not the empty state', (tester) async {
      await pumpPanel(
        tester,
        roadmapResult: legacyResult,
        vision: null,
        project: niimoShapedProject,
        externalResources: const [
          ExternalResource(
            type: ExternalResourceType.github,
            label: 'GitHub-Repository',
            uri: 'https://github.com/N3URAL-A1/niimo',
            hint: 'x',
          ),
        ],
      );

      await tester.tap(find.text('Links'));
      await _pumpIgnoringOverflow(tester);

      expect(find.text('GitHub-Repository'), findsOneWidget);
      expect(find.text('Keine Links konfiguriert'), findsNothing);
      expect(find.byType(LinksTabContent), findsOneWidget);
    });

    testWidgets(
      'an auto-detected resource and a VisionData.links entry pointing '
      'at the same URI produce only one chip (dedup)',
      (tester) async {
        const visionWithDuplicateLink = VisionData(
          title: 'Pro Orc — Vision',
          lead: 'Der Ueberblick ueber alle Projekte.',
          links: [
            VisionLink(
              title: 'GitHub Repo',
              target: 'https://github.com/N3URAL-A1/niimo',
              isWeb: true,
            ),
          ],
        );

        await pumpPanel(
          tester,
          roadmapResult: legacyResult,
          vision: visionWithDuplicateLink,
          project: niimoShapedProject,
          externalResources: const [
            ExternalResource(
              type: ExternalResourceType.github,
              label: 'GitHub-Repository',
              uri: 'https://github.com/N3URAL-A1/niimo',
              hint: 'x',
            ),
          ],
        );

        await tester.tap(find.text('Links'));
        await _pumpIgnoringOverflow(tester);

        // Exactly one chip for the shared URI — the auto-detected label
        // wins, the manual duplicate ('GitHub Repo') does not also render.
        expect(find.text('GitHub-Repository'), findsOneWidget);
        expect(find.text('GitHub Repo'), findsNothing);
      },
    );

    testWidgets('the empty state only shows when BOTH the auto-detected and '
        'manual sources are empty', (tester) async {
      await pumpPanel(
        tester,
        roadmapResult: legacyResult,
        vision: null,
        externalResources: const [],
      );

      await tester.tap(find.text('Links'));
      await _pumpIgnoringOverflow(tester);

      expect(find.text('Keine Links konfiguriert'), findsOneWidget);
    });

    testWidgets(
      'auto-detected resources render even when VisionData.links also '
      'has entries — both sources are additive, not replacing',
      (tester) async {
        const visionWithOtherLink = VisionData(
          title: 'Pro Orc — Vision',
          lead: 'Der Ueberblick ueber alle Projekte.',
          links: [
            VisionLink(
              title: 'Design-Doku',
              target: 'https://example.com/design',
              isWeb: true,
            ),
          ],
        );

        await pumpPanel(
          tester,
          roadmapResult: legacyResult,
          vision: visionWithOtherLink,
          project: niimoShapedProject,
          externalResources: const [
            ExternalResource(
              type: ExternalResourceType.github,
              label: 'GitHub-Repository',
              uri: 'https://github.com/N3URAL-A1/niimo',
              hint: 'x',
            ),
          ],
        );

        await tester.tap(find.text('Links'));
        await _pumpIgnoringOverflow(tester);

        expect(find.text('GitHub-Repository'), findsOneWidget);
        expect(find.text('Design-Doku'), findsOneWidget);
      },
    );
  });

  group('ProjectDetailPanel — FR-001/FR-002/FR-003: Dateien and Token tabs '
      '(feature 006)', () {
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

    final projectWithFiles = const ProjectModel(
      folderId: 'my-folder',
      displayName: 'My Project',
      path: '/tmp/my-folder',
      projectType: ProjectType.code,
      description: 'A test project description.',
      mdFiles: [
        MdFileInfo(
          name: 'README.md',
          path: '/tmp/my-folder/README.md',
          relativePath: 'README.md',
        ),
      ],
    );

    testWidgets(
      'shows exactly 6 tab buttons (Vision, Roadmap, Zeitstrahl, Links, '
      'Dateien, Token) for a tier-0 project',
      (tester) async {
        const tier0Result = RoadmapResult(
          data: RoadmapData(
            nextMdContent: '# Stand',
            milestones: [RoadmapMilestone(name: 'M9', status: 'in-progress')],
          ),
          source: RoadmapSource.productStore,
        );

        await pumpPanel(tester, roadmapResult: tier0Result, vision: null);

        expect(find.text('Vision'), findsOneWidget);
        expect(find.text('Roadmap'), findsOneWidget);
        expect(find.text('Zeitstrahl'), findsOneWidget);
        expect(find.text('Links'), findsOneWidget);
        expect(find.text('Dateien'), findsOneWidget);
        expect(find.text('Token'), findsOneWidget);
      },
    );

    testWidgets(
      'Dateien and Token tabs are present even for a legacy project with no '
      'docs/product/ at all (FR-003)',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        expect(find.text('Dateien'), findsOneWidget);
        expect(find.text('Token'), findsOneWidget);
      },
    );

    testWidgets(
      'Vision tab no longer renders the DATEIEN or TOKEN-NUTZUNG sections '
      '(FR-001/FR-002 — moved to their own tabs)',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        expect(find.text('DATEIEN'), findsNothing);
        expect(find.text('TOKEN-NUTZUNG'), findsNothing);
        // FR-004: remaining legacy content (description) still renders.
        expect(find.text('A test project description.'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting the Dateien tab renders the project\'s markdown file '
      'hierarchy',
      (tester) async {
        await pumpPanel(
          tester,
          roadmapResult: legacyResult,
          vision: null,
          project: projectWithFiles,
        );

        await tester.tap(find.text('Dateien'));
        await _pumpIgnoringOverflow(tester);

        expect(find.text('README.md'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting the Dateien tab shows a visible empty state when the '
      'project has no markdown files (FR-001/SC-003)',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        await tester.tap(find.text('Dateien'));
        await _pumpIgnoringOverflow(tester);

        expect(find.text('Keine Dateien gefunden'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting the Token tab renders the TOKEN-NUTZUNG scorecard as sole '
      'content, with its own empty state for a project with no session data',
      (tester) async {
        await pumpPanel(tester, roadmapResult: legacyResult, vision: null);

        await tester.tap(find.text('Token'));
        await _pumpIgnoringOverflow(tester);

        expect(find.text('TOKEN-NUTZUNG'), findsOneWidget);
        expect(
          find.text('Keine Daten zur Token-Nutzung vorhanden.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'switching from Dateien to Token and back to Vision preserves the '
      'selection-persistence contract (no crash, tab content restored)',
      (tester) async {
        await pumpPanel(
          tester,
          roadmapResult: legacyResult,
          vision: null,
          project: projectWithFiles,
        );

        await tester.tap(find.text('Dateien'));
        await _pumpIgnoringOverflow(tester);
        expect(find.text('README.md'), findsOneWidget);

        await tester.tap(find.text('Token'));
        await _pumpIgnoringOverflow(tester);
        expect(find.text('TOKEN-NUTZUNG'), findsOneWidget);
        expect(find.text('README.md'), findsNothing);

        await tester.tap(find.text('Vision'));
        await _pumpIgnoringOverflow(tester);
        expect(find.text('A test project description.'), findsOneWidget);
        expect(find.text('TOKEN-NUTZUNG'), findsNothing);
      },
    );
  });

  group('ProjectDetailPanel — FR-009: milestone selection survives '
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
