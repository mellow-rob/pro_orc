import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Wave 4 / FR-009 — a gh failure caused by a missing delete_repo scope
/// must surface the refresh hint and be reported with DISTINCT wording
/// from a plain not-authenticated failure. Both fixture projects have
/// their directory pre-removed in setUpAll so deleteProject() returns fast
/// (no real osascript/Finder move) — these tests only assert on the
/// gh-result text, not the local-folder outcome.
void main() {
  group('DeleteProjectDialog — Wave 4 FR-009 distinct gh failure reasons', () {
    late Directory root;
    late ProjectModel missingScopeProject;
    late ProjectModel notAuthenticatedProject;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('delete_dialog_fr009_test_');

      final scopeDir = Directory(p.join(root.path, 'gh_missing_scope'));
      await scopeDir.create(recursive: true);
      missingScopeProject = ProjectModel(
        folderId: 'gh_missing_scope',
        displayName: 'Test Project',
        path: scopeDir.path,
        projectType: ProjectType.code,
        git: const GitData(
          githubUrl: 'https://github.com/n3urala1-rob/a1-pro-orc',
        ),
        mdFiles: const [],
      );

      final authDir = Directory(p.join(root.path, 'gh_not_authenticated'));
      await authDir.create(recursive: true);
      notAuthenticatedProject = ProjectModel(
        folderId: 'gh_not_authenticated',
        displayName: 'Test Project',
        path: authDir.path,
        projectType: ProjectType.code,
        git: const GitData(
          githubUrl: 'https://github.com/n3urala1-rob/a1-pro-orc',
        ),
        mdFiles: const [],
      );

      // Pre-removed — these tests only assert on the gh-result text.
      await scopeDir.delete(recursive: true);
      await authDir.delete(recursive: true);
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> runFlow(
      WidgetTester tester,
      ProcessRunner ghRunner,
      ProjectModel project,
    ) async {
      await pumpDeleteProjectDialog(
        tester,
        project,
        vercelAvailable: false,
        ghAvailable: true,
        ghRunner: ghRunner,
      );

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
      'a gh failure caused by a missing delete_repo scope surfaces the '
      'refresh hint (FR-009)',
      (tester) async {
        await runFlow(tester, (
          String executable,
          List<String> arguments, {
          bool runInShell = true,
        }) async {
          return ProcessResult(
            0,
            1,
            '',
            'HTTP 404: Not Found\n'
                'This API operation needs the "delete_repo" scope. To '
                'request it, run: gh auth refresh -h github.com -s delete_repo',
          );
        }, missingScopeProject);

        expect(
          find.textContaining('gh auth refresh -s delete_repo'),
          findsOneWidget,
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    testWidgets(
      'a plain gh authentication failure shows notAuthenticated wording, '
      'without the delete_repo refresh hint (FR-009, distinct reason)',
      (tester) async {
        await runFlow(tester, (
          String executable,
          List<String> arguments, {
          bool runInShell = true,
        }) async {
          return ProcessResult(
            0,
            1,
            '',
            'You are not logged into any GitHub hosts.',
          );
        }, notAuthenticatedProject);

        expect(find.text('nicht authentifiziert'), findsOneWidget);
        expect(find.textContaining('delete_repo'), findsNothing);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
