import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/project_model.dart';
import 'database_provider.dart';
import 'watcher_provider.dart';

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
  return scanner.scanAll();
});
