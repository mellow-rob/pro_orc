import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Wave 4 / FR-008 — one selected external resource failing must not
/// prevent the flow from reaching the result report. Split into its own
/// file (rather than combined with the other Wave 4 result tests) so each
/// file's setUpAll does minimal I/O and stays fast in isolation — see
/// delete_project_dialog_test_helpers.dart for the runAsync/setUpAll
/// pattern every test here follows.
///
/// The project directory is deliberately pre-removed in setUpAll so
/// deleteProject() takes its fast not-found path instead of the real
/// osascript/Finder move — deleteProject()'s own success path is already
/// covered by deletion_service_test.dart; this test's job is proving the
/// gh failure doesn't block the flow from completing, which the fast path
/// demonstrates identically (independence doesn't require reproducing a
/// slow real Finder call here too, and doing so made this test's runtime
/// unpredictable under heavy system load).
void main() {
  group('DeleteProjectDialog — Wave 4 FR-008 independence', () {
    late Directory root;
    late ProjectModel project;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('delete_dialog_fr008_test_');
      final dir = Directory(p.join(root.path, 'gh_failure_local_ok'));
      await dir.create(recursive: true);
      project = ProjectModel(
        folderId: 'gh_failure_local_ok',
        displayName: 'Test Project',
        path: dir.path,
        projectType: ProjectType.code,
        git: const GitData(
          githubUrl: 'https://github.com/n3urala1-rob/a1-pro-orc',
        ),
        mdFiles: const [],
      );

      // See the doc comment above: pre-removed so deleteProject() takes
      // its fast not-found path instead of a real Finder move.
      await dir.delete(recursive: true);
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    testWidgets(
      'a failing gh deletion still lets the local folder deletion and '
      'result report complete — the failure does not abort the run '
      '(FR-008)',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          project,
          vercelAvailable: false,
          ghAvailable: true,
          ghRunner:
              (
                String executable,
                List<String> arguments, {
                bool runInShell = true,
              }) async {
                return ProcessResult(0, 1, '', 'some unexpected error');
              },
          // This test is about deletion-outcome independence (FR-008), not
          // about the Wave 3 scope pre-flight check — inject a `present`
          // result so the checkbox stays checked and the flow proceeds
          // exactly as before Wave 3 wired the check in.
          checkDeleteRepoScope: () async => GhScopeStatus.present,
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Test Project');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.text('Ja, endgueltig loeschen'));
        });
        await tester.pump();

        for (var i = 0; i < 40; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          if (find.text('Schliessen').evaluate().isNotEmpty) break;
        }

        // The result report was reached (not stuck on running) despite
        // the gh failure — the flow completes and reports the gh row as
        // a failure rather than getting stuck or silently dropping it.
        // (The project directory was pre-removed above, so deleteProject()
        // itself also reports "not found" here — its own header text
        // reflects that, which is expected and not what this test is
        // about.) Independence of the *external* deletions from each
        // other and from the local/DB deletion is covered by
        // deletion_service_test.dart's deleteSelectedExternalResources
        // test (FR-008 — independence), which runs a failing + a
        // succeeding resource together without a real process/Finder
        // call.
        expect(find.text('Schliessen'), findsOneWidget);
        expect(find.text('GitHub-Repository'), findsOneWidget);
        expect(find.textContaining('Fehlgeschlagen'), findsOneWidget);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
