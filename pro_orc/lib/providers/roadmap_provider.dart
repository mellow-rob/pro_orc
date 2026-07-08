import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/roadmap/a1_brain_roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/fallback_roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/local_roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';

/// Shared [FallbackRoadmapRepository] instance (stateless, safe to reuse
/// across all projects) — composes local → A1 Brain → Obsidian Vault per
/// the fixed priority chain (Waves 1-2).
final roadmapRepositoryProvider = Provider<RoadmapRepository>((ref) {
  return FallbackRoadmapRepository(
    local: LocalRoadmapRepository(),
    brain: A1BrainRoadmapRepository(),
  );
});

/// Resolves roadmap data for a single project via the three-tier fallback
/// chain (local `.a1/roadmap.md` → A1 Brain MCP → Obsidian Vault).
///
/// Keyed by [ProjectModel] so each project's Roadmap tab gets its own cached
/// result; `folderId` doubles as the Vault/Brain-facing slug (per project
/// convention — no separate slug field exists on [ProjectModel] today).
final roadmapProvider =
    FutureProvider.family<RoadmapResult, ProjectModel>((ref, project) async {
  final repo = ref.read(roadmapRepositoryProvider);
  return repo.resolve(project.folderId, project.path);
});
