import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/vault_roadmap_repository.dart';

/// Composes the three roadmap tiers (local → A1 Brain → Obsidian Vault) in
/// strict priority order, per FR-002 and the ADR at
/// `2026-07-08-roadmap-repository-interface.md`.
///
/// Each tier is tried only when every prior tier returned
/// `RoadmapData.empty` ("usable" = `!result.data.isEmpty`). Tiers are
/// queried lazily and sequentially — never in parallel — so the common case
/// (local tier hits) never touches the network (keeps SC-002 achievable).
///
/// The Vault tier (Wave 2, FR-006) is `ObsidianVaultRoadmapRepository` by
/// default, reading `~/N3URAL-Vault/projects/<slug>/`; a caller may inject
/// a different [RoadmapRepository] (e.g. for tests).
///
/// Pure Dart, no Flutter imports. Never throws — delegates entirely to its
/// constituent tiers, which already uphold the "never throw" convention.
class FallbackRoadmapRepository implements RoadmapRepository {
  FallbackRoadmapRepository({
    required RoadmapRepository local,
    required RoadmapRepository brain,
    RoadmapRepository? vault,
  }) : _local = local,
       _brain = brain,
       _vault = vault ?? ObsidianVaultRoadmapRepository();

  final RoadmapRepository _local;
  final RoadmapRepository _brain;
  final RoadmapRepository _vault;

  @override
  Future<RoadmapResult> resolve(String slug, String projectPath) async {
    final localResult = await _local.resolve(slug, projectPath);
    if (!localResult.data.isEmpty) return localResult;

    final brainResult = await _brain.resolve(slug, projectPath);
    if (!brainResult.data.isEmpty) return brainResult;

    final vaultResult = await _vault.resolve(slug, projectPath);
    return vaultResult;
  }
}
