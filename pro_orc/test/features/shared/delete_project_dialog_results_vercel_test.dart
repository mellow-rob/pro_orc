import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Wave 4 nachtrag — Vercel active-delete execution (FR-014 deviation:
/// the "--yes" flag the spec assumed does not exist on the locally
/// installed vercel CLI 51.8.0; deleteVercel() answers the interactive
/// confirmation via stdin instead — see the doc comment on
/// buildVercelDeleteArgs in external_deletion_service.dart for the full
/// justification, verified stderr strings, and the orchestrator's
/// approval). Covers the same reason-ordering discipline established for
/// gh (FR-009 pattern): an auth failure must never be misreported as
/// already-deleted just because the CLI also could not confirm the
/// project exists.
void main() {
  group('DeleteProjectDialog — Wave 4 Vercel execution', () {
    late Directory root;
    late ProjectModel notAuthProject;
    late ProjectModel alreadyDeletedProject;
    late ProjectModel timeoutProject;

    Future<ProjectModel> makeVercelProject(
      Directory root,
      String name,
    ) async {
      final dir = Directory(p.join(root.path, name));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'STATE.md'));
      await file.writeAsString(
        'Deployed at https://vercel.com/my-scope/$name for prod.',
      );
      // NOT pre-removed here — unlike the gh tests (where the github URL
      // lives directly on ProjectModel.git), the Vercel URL is only found
      // by scanning project.mdFiles during resource detection, so the
      // directory and its STATE.md must still exist when
      // pumpDeleteProjectDialog runs the initial load (same lesson as the
      // FR-010 Figma test in this wave). runFlow removes it later, right
      // before confirming, purely so deleteProject() takes its fast
      // not-found path instead of a real Finder move.
      return ProjectModel(
        folderId: name,
        displayName: 'Test Project',
        path: dir.path,
        projectType: ProjectType.code,
        mdFiles: [
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: file.path,
          ),
        ],
      );
    }

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp(
        'delete_dialog_vercel_test_',
      );
      notAuthProject = await makeVercelProject(root, 'vercel_not_auth');
      alreadyDeletedProject = await makeVercelProject(
        root,
        'vercel_already_deleted',
      );
      timeoutProject = await makeVercelProject(root, 'vercel_timeout');
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> runFlow(
      WidgetTester tester,
      VercelProcessRunner vercelRunner,
      ProjectModel project,
    ) async {
      await pumpDeleteProjectDialog(
        tester,
        project,
        vercelAvailable: true,
        ghAvailable: false,
        vercelRunner: vercelRunner,
      );

      // Now that resource detection already ran (during
      // pumpDeleteProjectDialog's initial load), remove the directory so
      // deleteProject() takes its fast not-found path instead of a real
      // osascript/Finder move — irrelevant to these vercel-result
      // assertions.
      await tester.runAsync(() async {
        final projectDir = Directory(project.path);
        if (await projectDir.exists()) {
          await projectDir.delete(recursive: true);
        }
      });

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Test Project');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Ja, endgueltig loeschen'));
      });
      await tester.pump();

      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.text('Schliessen').evaluate().isNotEmpty) break;
      }
    }

    testWidgets(
      'an invalid/expired Vercel token maps to notAuthenticated even when '
      'the same stderr also mentions the project not existing — the auth '
      'check takes priority so it is never misreported as already-deleted '
      '(same ordering discipline as the gh missingScope-before-not-found '
      'check, FR-009)',
      (tester) async {
        await runFlow(tester, (arguments) async {
          return const VercelProcessOutcome(
            exitCode: 1,
            stderr:
                'Error: The token provided via `--token` argument is not '
                'valid. Please provide a valid token. No such project exists.',
          );
        }, notAuthProject);

        expect(find.text('nicht authentifiziert'), findsOneWidget);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'a genuine "No such project exists" failure (no auth error) is '
      'shown as a SUCCESS row labelled "war bereits geloescht", not a '
      'failure (FR-017) — the exact stderr text verified against the '
      'real installed vercel CLI',
      (tester) async {
        await runFlow(tester, (arguments) async {
          return const VercelProcessOutcome(
            exitCode: 1,
            stderr: 'Error: No such project exists',
          );
        }, alreadyDeletedProject);

        expect(find.text('war bereits geloescht'), findsOneWidget);
        // Only the per-resource row's error icon (size 16) is relevant
        // here — NOT Icons.error_outline in general. The local
        // folder-deletion row (size 22) legitimately shows that same icon
        // in this test: the project directory was deliberately pre-removed
        // in runFlow so deleteProject() takes its fast not-found path, and
        // deleteProject() returns false for a missing directory by design
        // (see deletion_service_test.dart — "returns false when directory
        // does not exist"), independent of the Vercel outcome under test.
        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.error_outline && w.size == 16,
          ),
          findsNothing,
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'a Vercel CLI that never responds within the timeout guard is '
      'reported as a readable failure — the flow still reaches the '
      'result report instead of hanging indefinitely',
      (tester) async {
        await runFlow(tester, (arguments) async {
          return const VercelProcessOutcome(
            exitCode: -1,
            stderr: '',
            timedOut: true,
          );
        }, timeoutProject);

        expect(find.text('Schliessen'), findsOneWidget);
        expect(
          find.textContaining('Vercel-CLI hat nicht wie erwartet reagiert'),
          findsOneWidget,
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
