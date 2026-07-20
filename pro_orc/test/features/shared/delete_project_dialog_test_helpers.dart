import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/data/services/vercel_detection_service.dart';
import 'package:pro_orc/features/shared/delete_project_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Pumps a [DeleteProjectDialog] for [project] with injected detection-
/// service stubs and waits for its initial async load to fully settle.
///
/// `_loadResources()` and `_resolveAvailability()` (started from
/// `initState`) spawn real processes (`Process.run`) and do real file I/O.
/// If `pumpWidget` itself is called outside `tester.runAsync()`, those real
/// async operations start in the fake-async test zone and their completion
/// callbacks never fire — the test hangs forever, not just fails (found and
/// diagnosed in Wave 2). Wrapping `pumpWidget` in `runAsync`, then awaiting
/// the dialog's exposed `initialLoad` future in a second `runAsync`, lets
/// both operations actually run against the real event loop. Every widget
/// test that pumps [DeleteProjectDialog] MUST go through this helper (or
/// replicate the same runAsync wrapping) — skipping it reproduces the hang.
Future<void> pumpDeleteProjectDialog(
  WidgetTester tester,
  ProjectModel project, {
  required bool vercelAvailable,
  required bool ghAvailable,
  ProcessRunner ghRunner = defaultProcessRunner,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer(),
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: DeleteProjectDialog(
              project: project,
              vercelDetectionService: VercelDetectionService(
                whichCommand: vercelAvailable ? 'true' : 'false',
                vercelCommand: 'true',
              ),
              ghDetectionService: GhDetectionService(
                whichCommand: ghAvailable ? 'true' : 'false',
                ghCommand: 'true',
              ),
              ghRunner: ghRunner,
            ),
          ),
        ),
      ),
    );
  });

  final state = tester.state<State<DeleteProjectDialog>>(
    find.byType(DeleteProjectDialog),
  );
  await tester.runAsync(() => (state as dynamic).initialLoad as Future<void>);
  await tester.pumpAndSettle();
}
