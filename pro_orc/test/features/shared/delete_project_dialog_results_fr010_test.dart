import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Wave 4 / FR-010 — a Figma resource must never be dispatched to a
/// runner, at any point in the flow (permanently hint-only).
void main() {
  group('DeleteProjectDialog — Wave 4 FR-010 Figma never dispatched', () {
    late Directory root;
    late ProjectModel project;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('delete_dialog_fr010_test_');
      final dir = Directory(p.join(root.path, 'figma_hint_only'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'STATE.md'));
      await file.writeAsString(
        'Design lives at https://figma.com/file/abc123 for reference.',
      );
      project = ProjectModel(
        folderId: 'figma_hint_only',
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

      // NOT pre-removed here — detectExternalResources() (run during
      // pumpDeleteProjectDialog's initial load) needs the .md file to
      // still exist to find the Figma URL in the first place. The
      // directory is removed inside the test body instead, right before
      // confirming, once the resource row has already rendered.
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    testWidgets(
      'a project with a detected Figma resource never dispatches it to '
      'the runner — Figma stays hint-only with no checkbox at any point '
      '(FR-010)',
      (tester) async {
        var runnerCalls = 0;

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
                runnerCalls++;
                return ProcessResult(0, 0, '', '');
              },
        );

        // Figma renders with no active-delete checkbox — only the github
        // resource (if any) would show one, and this project has no
        // github URL, so there must be no checkbox for Figma to even tap.
        // Figma is never actively deletable (FR-010), so its row shows
        // the same "Token fehlt / nur Hinweis" status text as any other
        // non-dispatchable resource (Variant A, established in Wave 2).
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('Figma-Design'), findsOneWidget);
        expect(find.textContaining('Token fehlt'), findsOneWidget);

        // Complete a no-selection run (nothing checked) to confirm the
        // runner is still never invoked even once the flow executes.
        // The directory is removed now (after resource detection already
        // ran) purely so deleteProject() returns fast without a real
        // osascript/Finder move — irrelevant to this test's assertion.
        await tester.runAsync(() async {
          final projectDir = Directory(project.path);
          if (await projectDir.exists()) {
            await projectDir.delete(recursive: true);
          }
        });

        await tester.enterText(find.byType(TextField), 'Test Project');
        await tester.pump();

        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Loeschen'));
        });
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          });
          await tester.pump();
          if (find.text('Schliessen').evaluate().isNotEmpty) break;
        }

        expect(runnerCalls, 0);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
