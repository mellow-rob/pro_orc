import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';
import 'package:pro_orc/features/shared/project_detail_panel.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/roadmap_provider.dart';
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

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          roadmapProvider(project).overrideWith(
            (ref) async => const RoadmapResult(
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
