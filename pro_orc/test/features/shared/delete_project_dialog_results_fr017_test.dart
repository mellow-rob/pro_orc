import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Wave 4 / FR-017 — a gh deletion reporting the repo as already gone
/// (not found, no scope message) must be shown as a SUCCESS row labelled
/// "war bereits geloescht", not a failure.
void main() {
  group('DeleteProjectDialog — Wave 4 FR-017 idempotent already-deleted', () {
    late Directory root;
    late ProjectModel project;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('delete_dialog_fr017_test_');
      final dir = Directory(p.join(root.path, 'gh_already_deleted'));
      await dir.create(recursive: true);
      project = ProjectModel(
        folderId: 'gh_already_deleted',
        displayName: 'Test Project',
        path: dir.path,
        projectType: ProjectType.code,
        git: const GitData(
          githubUrl: 'https://github.com/n3urala1-rob/a1-pro-orc',
        ),
        mdFiles: const [],
      );

      // Deliberately NOT pre-removed: this test also asserts that NO
      // error_outline icon renders anywhere in the result — that only
      // holds if the local-folder deletion succeeds too (a failed local
      // delete renders its own error_outline header icon, unrelated to
      // the gh outcome this test targets). Keeping the real directory
      // means deleteProject() takes the real osascript/Finder-move path,
      // same as the FR-008 test.
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);

      // The real Finder move (see comment in setUpAll) lands the
      // directory in the Trash — best-effort cleanup.
      try {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final trashed = Directory(
            p.join(home, '.Trash', 'gh_already_deleted'),
          );
          if (await trashed.exists()) {
            await trashed.delete(recursive: true);
          }
        }
      } catch (_) {}
    });

    testWidgets('a gh deletion reporting the repo as already gone (not found, no '
        'scope message) is shown as a SUCCESS row labelled '
        '"war bereits geloescht", not a failure (FR-017)', (tester) async {
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
              return ProcessResult(
                0,
                1,
                '',
                'GraphQL: Could not resolve to a Repository (repository) (Not Found)',
              );
            },
        // This test is about the FR-017 gh-result mapping, not the Wave 3
        // scope pre-flight check — inject a `present` result so the
        // checkbox stays checked and the flow proceeds exactly as before
        // Wave 3 wired the check in.
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

      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.text('Schliessen').evaluate().isNotEmpty) break;
      }

      expect(find.text('war bereits geloescht'), findsOneWidget);
      // A success row renders with the check-circle icon, not the
      // error/warning icon.
      expect(find.byIcon(Icons.error_outline), findsNothing);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
