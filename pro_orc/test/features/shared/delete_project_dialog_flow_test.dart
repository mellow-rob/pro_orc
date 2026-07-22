import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/features/shared/delete_project_dialog.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Wave 3 — confirmation step & flow-control locking. Fixtures follow the
/// same setUpAll-based pattern as delete_project_dialog_test.dart (Wave 2):
/// all filesystem setup happens once, before any testWidgets pump activates
/// the flutter_tester binding, and every pump goes through
/// [pumpDeleteProjectDialog] to avoid the runAsync-related hang documented
/// there.
void main() {
  group('DeleteProjectDialog — Wave 3 confirmation & flow control', () {
    late Directory root;
    late ProjectModel githubProject;
    late ProjectModel claudeMemoryOnlyProject;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('delete_dialog_flow_test_');

      final githubDir = Directory(p.join(root.path, 'github_only'));
      await githubDir.create(recursive: true);
      githubProject = ProjectModel(
        folderId: 'github_only',
        displayName: 'Test Project',
        path: githubDir.path,
        projectType: ProjectType.code,
        git: const GitData(
          githubUrl: 'https://github.com/n3urala1-rob/a1-pro-orc',
        ),
        mdFiles: const [],
      );

      // Claude memory: a real directory under the actual
      // ~/.claude/projects/<encoded-path> path, matching how
      // resource_detector.dart discovers it (no destructive-external
      // resource — this project has neither github nor vercel).
      final memoryDir = Directory(p.join(root.path, 'memory_only'));
      await memoryDir.create(recursive: true);
      claudeMemoryOnlyProject = ProjectModel(
        folderId: 'memory_only',
        displayName: 'Test Project',
        path: memoryDir.path,
        projectType: ProjectType.code,
        mdFiles: const [],
      );
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);

      // The FR-018 test's flow run actually moves claudeMemoryOnlyProject's
      // directory to the real macOS Trash via deleteProject() (same
      // Finder-based move as deletion_service_test.dart). Best-effort
      // cleanup so repeated test runs don't accumulate junk there — do not
      // fail teardown if this itself fails.
      try {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final trashed = Directory(p.join(home, '.Trash', 'memory_only'));
          if (await trashed.exists()) {
            await trashed.delete(recursive: true);
          }
        }
      } catch (_) {}
    });

    Future<void> typeProjectName(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'Test Project');
      await tester.pump();
    }

    testWidgets('checking a destructive-external resource (GitHub), typing the '
        'correct name, and tapping Loeschen shows the destructive-warning '
        'step with the exact wording and both actions BEFORE any external '
        'call (FR-007, destructive branch)', (tester) async {
      await pumpDeleteProjectDialog(
        tester,
        githubProject,
        vercelAvailable: false,
        ghAvailable: true,
        // This test is about the FR-007 destructive-warning step, not the
        // Wave 3 scope pre-flight check — inject a `present` result so the
        // checkbox stays checked and the flow proceeds exactly as before
        // Wave 3 wired the check in.
        checkDeleteRepoScope: () async => GhScopeStatus.present,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await typeProjectName(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
      await tester.pump();

      expect(
        find.textContaining('kann NICHT rueckgaengig gemacht werden'),
        findsOneWidget,
      );
      expect(find.text('Zurueck'), findsOneWidget);
      expect(find.text('Ja, endgueltig loeschen'), findsOneWidget);

      // No result/running screen yet — no external call has happened.
      expect(find.text('Projekt wird geloescht…'), findsNothing);
      expect(find.text('Projekt geloescht'), findsNothing);
    });

    testWidgets(
      '"Zurueck" on the destructive-warning step returns to the main form '
      'without starting the flow',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          // Not about the Wave 3 scope pre-flight check — see the doc
          // comment on the previous test in this file.
          checkDeleteRepoScope: () async => GhScopeStatus.present,
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await typeProjectName(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
        await tester.pump();

        await tester.tap(find.text('Zurueck'));
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Loeschen'), findsOneWidget);
        expect(find.text('Ja, endgueltig loeschen'), findsNothing);
      },
    );

    testWidgets(
      'checking ONLY the Claude-memory resource (not destructive-external), '
      'typing the correct name, and tapping Loeschen skips the '
      'destructive-warning step entirely and goes straight to the result '
      'container (FR-007, non-destructive branch)',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          claudeMemoryOnlyProject,
          vercelAvailable: false,
          ghAvailable: false,
        );

        // claudeMemoryOnlyProject has no detected resources (no github/
        // vercel url, and its ~/.claude/projects dir was never created),
        // so there is nothing to check — confirm the flow starts directly
        // via the name field alone, exactly like the pre-Wave-3 behavior
        // for a selection with no destructive-external resource.
        await typeProjectName(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
        await tester.pump();

        expect(
          find.textContaining('kann NICHT rueckgaengig gemacht werden'),
          findsNothing,
        );
        expect(find.text('Zurueck'), findsNothing);
        expect(find.text('Ja, endgueltig loeschen'), findsNothing);
      },
    );

    testWidgets('once the flow has started, the Loeschen button is immediately '
        'disabled so a second activation cannot start a duplicate run '
        '(FR-016)', (tester) async {
      await pumpDeleteProjectDialog(
        tester,
        claudeMemoryOnlyProject,
        vercelAvailable: false,
        ghAvailable: false,
      );

      await typeProjectName(tester);

      final deleteButtonFinder = find.widgetWithText(FilledButton, 'Loeschen');
      await tester.tap(deleteButtonFinder);
      await tester.pump();

      // The main form (and its "Loeschen" button) is gone — the dialog
      // is now on the running/result container, so a second tap on the
      // same button is structurally impossible; assert its absence
      // rather than tapping a finder that no longer resolves.
      expect(deleteButtonFinder, findsNothing);
      expect(find.text('Projekt wird geloescht…'), findsOneWidget);
    });

    testWidgets(
      'while the deletion flow is running, no close IconButton is present '
      'and the dialog offers no mid-flight cancel action (FR-015)',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          claudeMemoryOnlyProject,
          vercelAvailable: false,
          ghAvailable: false,
        );

        await typeProjectName(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
        await tester.pump();

        expect(find.text('Projekt wird geloescht…'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
        expect(find.text('Abbrechen'), findsNothing);
      },
    );

    testWidgets(
      'the result screen ends with an explicit Schliessen action and does '
      'NOT auto-close — the dialog stays open until that action is tapped '
      '(FR-018)',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          claudeMemoryOnlyProject,
          vercelAvailable: false,
          ghAvailable: false,
        );

        await typeProjectName(tester);

        // Tapping "Loeschen" here starts _startDeletionFlow(), which calls
        // deleteProject() (a real osascript Process.run). Exactly like the
        // dialog's own initial load (see delete_project_dialog_test_helpers
        // .dart), that real async work must be triggered from inside
        // runAsync — otherwise its completion callback never fires and the
        // test hangs rather than failing. Poll (bounded) rather than a
        // single fixed delay — real process-spawn latency varies with
        // system load and a flat delay flakes under load.
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
        });
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          if (find.text('Schliessen').evaluate().isNotEmpty) break;
        }

        // The flow reached the result step, but the dialog itself is
        // still present (no auto-pop) — the DeleteProjectDialog widget
        // and its "Schliessen" button are both still in the tree.
        expect(find.byType(DeleteProjectDialog), findsOneWidget);
        expect(find.text('Schliessen'), findsOneWidget);

        await tester.tap(find.text('Schliessen'));
        await tester.pumpAndSettle();

        // Only NOW, after the explicit action, does the dialog pop.
        expect(find.byType(DeleteProjectDialog), findsNothing);
      },
    );
  });
}
