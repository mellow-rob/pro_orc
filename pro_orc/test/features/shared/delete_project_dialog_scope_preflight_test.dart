import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/features/shared/github_permission_popup.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Spec 008 Wave 3 — wires the GitHub delete_repo scope pre-flight check
/// (Wave 1's `GhDetectionService.checkDeleteRepoScope()`) into the
/// DeleteProjectDialog's GitHub-repo checkbox.
///
/// FR-002/FR-003/FR-005/FR-006/FR-011. Uses the same setUpAll-based real-
/// temp-dir fixture pattern and [pumpDeleteProjectDialog] helper as the
/// other delete_project_dialog test files (avoids the runAsync-related
/// hang documented in delete_project_dialog_test.dart).
void main() {
  group('DeleteProjectDialog — GitHub scope pre-flight (Wave 3)', () {
    late Directory root;
    late ProjectModel githubProject;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp(
        'delete_dialog_scope_preflight_test_',
      );

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
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    testWidgets(
      'present: checking the GitHub checkbox shows no popup and stays '
      'checked (FR-002)',
      (tester) async {
        var callCount = 0;
        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () async {
            callCount++;
            return GhScopeStatus.present;
          },
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        expect(callCount, 1);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
        expect(find.text('Berechtigung fehlt'), findsNothing);
      },
    );

    testWidgets('missing: checking the GitHub checkbox shows the popup and the '
        'checkbox is NOT checked (FR-003/FR-005)', (tester) async {
      await pumpDeleteProjectDialog(
        tester,
        githubProject,
        vercelAvailable: false,
        ghAvailable: true,
        checkDeleteRepoScope: () async => GhScopeStatus.missing,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('Berechtigung fehlt'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets(
      'checkFailed: checking the GitHub checkbox shows the popup and the '
      'checkbox is NOT checked (treated like missing)',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () async => GhScopeStatus.checkFailed,
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        expect(find.text('Berechtigung fehlt'), findsOneWidget);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      },
    );

    testWidgets('cliUnavailable: checking the GitHub checkbox shows the '
        'cli-unavailable popup body and the checkbox is NOT checked '
        '(FR-012 safety-net path)', (tester) async {
      await pumpDeleteProjectDialog(
        tester,
        githubProject,
        vercelAvailable: false,
        ghAvailable: true,
        checkDeleteRepoScope: () async => GhScopeStatus.cliUnavailable,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'GitHub CLI (gh) ist nicht installiert oder nicht angemeldet',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Terminal oeffnen & Berechtigung nachfordern'),
        findsNothing,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('unchecking never triggers a pre-flight check', (tester) async {
      var callCount = 0;
      await pumpDeleteProjectDialog(
        tester,
        githubProject,
        vercelAvailable: false,
        ghAvailable: true,
        checkDeleteRepoScope: () async {
          callCount++;
          return GhScopeStatus.present;
        },
      );

      // Check then uncheck.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(callCount, 1, reason: 'unchecking must not run a check');
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets(
      're-checking after a missing result always runs a brand-new check '
      '— no cached result reused (FR-006)',
      (tester) async {
        var callCount = 0;
        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () async {
            callCount++;
            return GhScopeStatus.missing;
          },
        );

        // First check → missing → popup shown, checkbox stays unchecked.
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(callCount, 1);
        expect(find.text('Berechtigung fehlt'), findsOneWidget);

        // Dismiss the popup via its own Abbrechen button (scoped to the
        // popup — the dialog's main form also has an "Abbrechen" button
        // underneath it).
        await tester.tap(
          find.descendant(
            of: find.byType(GithubPermissionPopup),
            matching: find.text('Abbrechen'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Berechtigung fehlt'), findsNothing);

        // Check again → a brand-new call, not a cached result.
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(
          callCount,
          2,
          reason:
              'second checkbox tick must trigger a fresh pre-flight '
              'call, not reuse the first result',
        );
        expect(find.text('Berechtigung fehlt'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the popup action button opens the terminal, closes the '
      'popup, and the checkbox stays unchecked; re-checking runs a fresh '
      'check (FR-011)',
      (tester) async {
        var callCount = 0;
        var terminalOpenCount = 0;
        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () async {
            callCount++;
            return GhScopeStatus.missing;
          },
          onOpenTerminalForGhScopeRefresh: () async {
            terminalOpenCount++;
          },
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(find.text('Berechtigung fehlt'), findsOneWidget);

        await tester.tap(
          find.text('Terminal oeffnen & Berechtigung nachfordern'),
        );
        await tester.pumpAndSettle();

        expect(terminalOpenCount, 1);
        expect(find.text('Berechtigung fehlt'), findsNothing);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

        // Re-checking runs a fresh pre-flight call.
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(callCount, 2);
      },
    );

    testWidgets(
      'the pre-flight check never advances the dialog step past the main '
      'form (form -> destructiveWarning stays reachable only via Loeschen)',
      (tester) async {
        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () async => GhScopeStatus.present,
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Still on the main form: project-name text field + Loeschen
        // button are present, no destructive-warning / running / result
        // screen content.
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Loeschen'), findsOneWidget);
        expect(find.text('Endgueltige Loeschung bestaetigen'), findsNothing);
      },
    );
  });

  group('DeleteProjectDialog — in-flight scope-check guard (review fix)', () {
    late Directory root;
    late ProjectModel githubProject;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp(
        'delete_dialog_inflight_guard_test_',
      );

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
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    testWidgets(
      'Loeschen stays disabled while a GitHub scope check for a currently '
      'selected resource is still in flight, even once the project name '
      'matches (review fix — In-flight-Race Finding 1a)',
      (tester) async {
        final checkCompleter = Completer<GhScopeStatus>();

        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () => checkCompleter.future,
        );

        // Tick the GitHub checkbox — starts the (never-resolving-yet)
        // pre-flight check.
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        // Type the exact project name while the check is still pending.
        await tester.enterText(find.byType(TextField), 'Test Project');
        await tester.pump();

        // Loeschen must still be disabled — tapping it must not start the
        // deletion flow while the scope check is unresolved.
        final deleteButtonFinder = find.widgetWithText(
          FilledButton,
          'Loeschen',
        );
        final deleteButton = tester.widget<FilledButton>(deleteButtonFinder);
        expect(
          deleteButton.onPressed,
          isNull,
          reason:
              'the delete button must be disabled while a scope check for '
              'a selected destructive-external resource is in flight',
        );

        // Even attempting to tap it (in case a future change re-enables
        // it) must not advance past the main form.
        await tester.tap(deleteButtonFinder, warnIfMissed: false);
        await tester.pump();
        expect(find.text('Endgueltige Loeschung bestaetigen'), findsNothing);
        expect(find.byType(TextField), findsOneWidget);

        // Resolve the check so the pending timer/future doesn't leak past
        // the test.
        checkCompleter.complete(GhScopeStatus.present);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'unchecking the GitHub checkbox before a slow scope check resolves '
      'suppresses the missing-permission popup once the check completes '
      '(review fix — In-flight-Race Finding 1b)',
      (tester) async {
        final checkCompleter = Completer<GhScopeStatus>();

        await pumpDeleteProjectDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
          checkDeleteRepoScope: () => checkCompleter.future,
        );

        // Check, then uncheck again before the check resolves.
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

        // Now the check resolves with `missing` — since the user already
        // walked back their selection, the popup must not appear.
        checkCompleter.complete(GhScopeStatus.missing);
        await tester.pumpAndSettle();

        expect(find.byType(GithubPermissionPopup), findsNothing);
        expect(find.text('Berechtigung fehlt'), findsNothing);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      },
    );
  });
}
