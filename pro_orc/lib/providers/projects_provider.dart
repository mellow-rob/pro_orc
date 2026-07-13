import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/project_organization_seed_service.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

/// Live project list — rescans on every watcher event.
/// Watcher events trigger invalidation → rescan → UI rebuild.
final projectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  // Listen to watcher events — any change invalidates this provider
  ref.listen(watcherProvider, (previous, next) {
    // Only invalidate on actual data events, not loading/error transitions
    if (next.hasValue) {
      ref.invalidateSelf();
    }
  });

  final scanner = ref.read(projectScannerProvider);
  final projects = await scanner.scanAll();

  // One-time, idempotent seed (FR-014/015/016) — runs after every scan but
  // the seed-applied flag makes every call after the first a no-op.
  final db = ref.read(appDatabaseProvider);
  await ProjectOrganizationSeedService(db).applyIfNeeded(projects);

  return projects;
});
