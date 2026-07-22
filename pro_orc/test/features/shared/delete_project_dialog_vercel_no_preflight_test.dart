import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/features/shared/github_permission_popup.dart';

import 'delete_project_dialog_test_helpers.dart';

/// Spec 008, Wave 5 — FR-010 guard.
///
/// FR-010 deliberately does NOT implement a Vercel pre-flight permission
/// check: Vercel has no equivalent to GitHub's granular `delete_repo` OAuth
/// scope (permission is tied to team role, with no CLI self-service
/// role-upgrade command the way `gh auth refresh` exists for GitHub). The
/// Vercel checkbox therefore keeps its pre-008 behavior exactly as-is —
/// optimistic select on check, no pre-flight call, no popup — and any
/// missing permission still only surfaces later via the existing
/// execution-time `DeletionOutcome.missingScope` fallback in
/// `external_deletion_service.dart` (FR-009), which is unchanged by this
/// feature and therefore not re-tested here.
///
/// This test exists purely as a regression guard so a future edit can't
/// accidentally wire `_checkGithubScope` (or an equivalent pre-flight call)
/// into the Vercel branch of `_buildResources`'s checkbox `onChanged`
/// without a test failing.
void main() {
  group('DeleteProjectDialog — Vercel checkbox has no pre-flight (FR-010)', () {
    late Directory root;
    late ProjectModel vercelProject;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp(
        'delete_dialog_vercel_no_preflight_test_',
      );

      final vercelDir = Directory(p.join(root.path, 'vercel_only'));
      await vercelDir.create(recursive: true);
      final stateFile = File(p.join(vercelDir.path, 'STATE.md'));
      await stateFile.writeAsString(
        'Deployed at https://vercel.com/my-scope/vercel_only for prod.',
      );

      vercelProject = ProjectModel(
        folderId: 'vercel_only',
        displayName: 'Test Project',
        path: vercelDir.path,
        projectType: ProjectType.code,
        mdFiles: [
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: stateFile.path,
          ),
        ],
      );
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    testWidgets(
      'checking the Vercel checkbox stays checked immediately, shows no '
      'GithubPermissionPopup, and never runs a scope pre-flight call '
      '(FR-010 — pre-008 behavior unchanged)',
      (tester) async {
        var scopeCheckCallCount = 0;

        await pumpDeleteProjectDialog(
          tester,
          vercelProject,
          vercelAvailable: true,
          ghAvailable: false,
          // Injected as the GitHub scope checker purely to prove it is
          // NEVER invoked from the Vercel branch — if a future change
          // wires pre-flight into Vercel too, this call count would go
          // to 1 and the test fails.
          checkDeleteRepoScope: () async {
            scopeCheckCallCount++;
            return GhScopeStatus.present;
          },
        );

        await tester.tap(find.byType(Checkbox));
        // No pumpAndSettle() needed/expected: unlike the GitHub branch,
        // there is no async pre-flight to await. A single pump proves the
        // checkbox already reflects the final state synchronously.
        await tester.pump();

        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).value,
          isTrue,
          reason:
              'Vercel checkbox must stay optimistically checked with no '
              'pre-flight gate, exactly like before Spec 008',
        );
        expect(find.byType(GithubPermissionPopup), findsNothing);
        expect(find.text('Berechtigung fehlt'), findsNothing);
        expect(
          scopeCheckCallCount,
          0,
          reason:
              'FR-010: the GitHub delete_repo scope pre-flight checker '
              'must never be called from the Vercel checkbox path',
        );
      },
    );
  });
}
