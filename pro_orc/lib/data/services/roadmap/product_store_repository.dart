import 'package:pro_orc/data/models/product_store_data.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/product_store_parser.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';

/// Tier-0 [RoadmapRepository]: wraps [ProductStoreParser] and adapts its
/// `docs/product/index.json` (+ `NEXT.md` + `features/<id>/feature.md`)
/// output ([ProductStoreData]) into the source-agnostic [RoadmapData]
/// model.
///
/// Tried BEFORE every other tier by `FallbackRoadmapRepository` (FR-011:
/// "first usable tier wins", and `docs/product/` is the most authoritative,
/// most structured source when present). Pure Dart, no Flutter imports.
/// Never throws: [ProductStoreParser] already returns
/// [ProductStoreData.empty] on any internal failure (malformed JSON,
/// missing directory, etc. — FR-009/FR-010), so this repository always
/// resolves to a [RoadmapResult] with [RoadmapSource.productStore], whose
/// `data` may simply be [RoadmapData.empty].
class ProductStoreRoadmapRepository implements RoadmapRepository {
  ProductStoreRoadmapRepository({ProductStoreParser? parser})
    : _parser = parser ?? ProductStoreParser();

  final ProductStoreParser _parser;

  /// Resolves tier-0 roadmap data for [projectPath]. [slug] is ignored —
  /// like the local tier, this tier is addressed purely by filesystem path.
  @override
  Future<RoadmapResult> resolve(String slug, String projectPath) async {
    final storeData = await _parser.parse(projectPath);
    return RoadmapResult(
      data: _toRoadmapData(storeData),
      source: RoadmapSource.productStore,
    );
  }

  /// Adapts [ProductStoreData]'s flat milestone/feature lists into
  /// [RoadmapData]'s milestone→phase nesting. Each `ProductStoreFeature`
  /// becomes a [RoadmapPhase] nested under the [RoadmapMilestone] matching
  /// its `milestoneId`; a feature whose `milestoneId` matches no milestone
  /// is simply not attached anywhere (the source-agnostic model has no
  /// "unassigned" bucket) rather than dropped with an error or crashing.
  RoadmapData _toRoadmapData(ProductStoreData storeData) {
    if (storeData.isEmpty) return RoadmapData.empty;

    final featuresByMilestone = <String, List<ProductStoreFeature>>{};
    for (final feature in storeData.features) {
      featuresByMilestone
          .putIfAbsent(feature.milestoneId, () => [])
          .add(feature);
    }

    final milestones = <RoadmapMilestone>[
      for (final m in storeData.milestones)
        RoadmapMilestone(
          name: m.title,
          status: m.status,
          target: m.target,
          phases: [
            for (final f in featuresByMilestone[m.id] ?? const [])
              _toRoadmapPhase(f),
          ],
        ),
    ];

    return RoadmapData(milestones: milestones);
  }

  RoadmapPhase _toRoadmapPhase(ProductStoreFeature f) => RoadmapPhase(
    name: f.title,
    status: f.status,
    start: f.started,
    finished: f.finished,
  );
}
