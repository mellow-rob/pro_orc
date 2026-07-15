/// Immutable models for the `docs/product/` schema-v1 layout (Wave 3,
/// tier-0 roadmap source), as scaffolded by a1-specforge.
///
/// Mirrors the shape of `docs/product/index.json` (§3 of
/// `a1-skills/docs/product/SCHEMA.md`) plus the "you are here" / next-step
/// content of `NEXT.md`, and the on-disk `features/<id>/{feature,spec,plan}.md`
/// paths (existence-checked here; content is read lazily in Wave 5).
///
/// Analogous to `A1Data`/`A1Reader`: pure Dart, no Flutter imports, produced
/// only by `ProductStoreParser`, which never throws — any parse failure
/// yields [ProductStoreData.empty].
library;

/// One milestone entry from `index.json` `milestones[]`.
class ProductStoreMilestone {
  /// Stable kebab-case id, e.g. `m9-detail-roadmap-redesign`.
  final String id;

  /// Human-readable title.
  final String title;

  /// Raw status string: `done` | `in-progress` | `planned` (schema v1
  /// vocabulary — adapted to the existing `deriveDisplayStatus` vocabulary
  /// by the repository layer, not here).
  final String status;

  /// Target month (`YYYY-MM`) as parsed into a [DateTime] (first-of-month),
  /// or null when unscheduled.
  final DateTime? target;

  const ProductStoreMilestone({
    required this.id,
    required this.title,
    required this.status,
    this.target,
  });
}

/// One feature entry from `index.json` `features[]`, plus the on-disk
/// existence of its `features/<id>/{feature,spec,plan}.md` files.
class ProductStoreFeature {
  /// 3-digit zero-padded sequence + kebab-slug, e.g.
  /// `002-project-organization`.
  final String id;

  /// The milestone id (`ProductStoreMilestone.id`) this feature belongs to.
  final String milestoneId;

  /// Human-readable title.
  final String title;

  /// Raw status string: `done` | `in-flight` | `planned` | `cancelled`.
  final String status;

  /// Lifecycle stage while in-flight (schema v1: started/complete/review/
  /// verify/merge/origin-cleanup/done), or null when not in-flight.
  final String? stage;

  /// Feature ids this feature depends on.
  final List<String> dependsOn;

  /// Date work began, or null if not yet started.
  final DateTime? started;

  /// Date work completed, or null if not yet finished.
  final DateTime? finished;

  /// Repo-relative path to the feature's spec doc, or null.
  final String? specPath;

  /// Repo-relative path to the feature's wave-plan doc, or null.
  final String? planPath;

  /// Absolute path to `features/<id>/feature.md` when that file exists on
  /// disk, otherwise null. Content is read lazily (Wave 5) — this parser
  /// only records the path.
  final String? featureMdPath;

  const ProductStoreFeature({
    required this.id,
    required this.milestoneId,
    required this.title,
    required this.status,
    this.stage,
    this.dependsOn = const [],
    this.started,
    this.finished,
    this.specPath,
    this.planPath,
    this.featureMdPath,
  });
}

/// Aggregated, source-specific state for a project's `docs/product/`
/// directory. Produced by `ProductStoreParser.parse`, adapted into the
/// source-agnostic `RoadmapData` by `ProductStoreRoadmapRepository`.
class ProductStoreData {
  /// Milestones from `index.json` `milestones[]`, in file order.
  final List<ProductStoreMilestone> milestones;

  /// Features from `index.json` `features[]`, in file order.
  final List<ProductStoreFeature> features;

  /// Recommended next-feature id from `index.json` `next`, or null.
  final String? next;

  /// Raw content of `NEXT.md` when present and readable, or null. Freeform
  /// text — the "you are here" / next-step summary. Rendered as-is by the
  /// Wave 4 hero section, no further parsing performed here.
  final String? nextMdContent;

  const ProductStoreData({
    this.milestones = const [],
    this.features = const [],
    this.next,
    this.nextMdContent,
  });

  static const empty = ProductStoreData();

  /// "Usable data" per FR-008/FR-009: a parse result counts as usable only
  /// when it has at least one milestone. Matches `RoadmapData.isEmpty`'s
  /// predicate so `ProductStoreRoadmapRepository` can defer to the same
  /// fall-through contract used by every other tier.
  bool get isEmpty => milestones.isEmpty;
}
