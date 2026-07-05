import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/learning_data.dart';
import 'package:pro_orc/data/services/learning_reader.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

/// Read-only a1 learning-loop state (retros per skill, pattern clusters,
/// per-project observations, a1-evolve fälligkeit).
///
/// Vault path comes from the DB config (empty → reader default), project paths
/// come from [projectsProvider]. Rescans on `~/.claude` / scan-dir changes via
/// [watcherProvider], following the same stateless FutureProvider +
/// ref.listen-invalidation pattern as [harnessProvider].
final learningProvider = FutureProvider<LearningData>((ref) async {
  ref.listen(watcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });

  final db = ref.watch(appDatabaseProvider);
  final vaultDir = await db.getVaultDir();

  // Project paths for observations.jsonl discovery. Await the current project
  // list so the observations section reflects the live scan.
  final projects = await ref.watch(projectsProvider.future);
  final projectPaths = projects.map((p) => p.path).toList();

  final reader = LearningReader(vaultDirOverride: vaultDir);
  return reader.read(projectPaths);
});
