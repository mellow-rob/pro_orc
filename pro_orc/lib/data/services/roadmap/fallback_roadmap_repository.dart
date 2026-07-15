import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/vault_roadmap_repository.dart';

/// Composes the roadmap tiers (product-store → local → A1 Brain → Obsidian
/// Vault) in strict priority order, per FR-002/FR-011 and the ADR at
/// `2026-07-08-roadmap-repository-interface.md`.
///
/// Each tier is tried only when every prior tier returned
/// `RoadmapData.empty` ("usable" = `!result.data.isEmpty`). Tiers are
/// queried lazily and sequentially — never in parallel — so the common case
/// (product-store or local tier hits) never touches the network (keeps
/// SC-002 achievable).
///
/// The product-store tier (Wave 3, FR-008/FR-011) is optional and, when
/// supplied, tried BEFORE `local` — a project scaffolded with
/// `docs/product/` (a1-specforge schema v1) is the most authoritative,
/// most structured source when present, so it wins over the legacy
/// `.a1/roadmap.md` tier per "first usable tier wins". Omitting it (the
/// default) preserves the exact pre-Wave-3 behavior (FR-010).
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
    RoadmapRepository? productStore,
  }) : _local = local,
       _brain = brain,
       _vault = vault ?? ObsidianVaultRoadmapRepository(),
       _productStore = productStore;

  final RoadmapRepository _local;
  final RoadmapRepository _brain;
  final RoadmapRepository _vault;

  /// Optional tier-0 reader (Wave 3). Null when the caller does not wire one
  /// in — the chain then behaves exactly as it did before Wave 3.
  final RoadmapRepository? _productStore;

  @override
  Future<RoadmapResult> resolve(String slug, String projectPath) async {
    final productStore = _productStore;
    if (productStore != null) {
      final productStoreResult = await productStore.resolve(slug, projectPath);
      if (!productStoreResult.data.isEmpty) return productStoreResult;
    }

    final localResult = await _local.resolve(slug, projectPath);
    if (!localResult.data.isEmpty) return localResult;

    final brainResult = await _brain.resolve(slug, projectPath);
    if (!brainResult.data.isEmpty) return brainResult;

    final vaultResult = await _vault.resolve(slug, projectPath);
    return vaultResult;
  }
}
