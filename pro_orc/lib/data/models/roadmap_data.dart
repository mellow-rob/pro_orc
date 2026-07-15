/// Source-agnostic roadmap model for the Roadmap & Backlog Dashboard
/// (spec `001-roadmap-backlog-dashboard`, Wave 1).
///
/// This model is deliberately decoupled from any single tier's storage shape
/// (local `.a1/roadmap.md`, A1 Brain MCP, or Obsidian Vault). Each tier
/// repository is responsible for adapting its native shape into this model;
/// UI and provider code depend only on this model, never on tier internals.
///
/// No Flutter imports — pure Dart, unit-testable and isolate-safe.
library;

/// Which of the three fallback tiers produced a [RoadmapData] result.
///
/// Order of precedence when resolving (see `FallbackRoadmapRepository`):
/// `local` → `brain` → `vault`. A tier is only consulted when every prior
/// tier returned no usable data (usable = non-empty per [RoadmapData.isEmpty]).
enum RoadmapSource {
  /// Resolved from the project's `docs/product/index.json` schema-v1 layout
  /// (Wave 3, tier-0 — tried ahead of every other tier).
  productStore,

  /// Resolved from the project's local `.a1/roadmap.md` + `.a1/phases/`.
  local,

  /// Resolved from the A1 Brain MCP server (streamable-HTTP).
  brain,

  /// Resolved from the Obsidian Vault (`~/N3URAL-Vault/projects/<slug>/`).
  vault,
}

/// Reference to one spec document associated with a [RoadmapPhase].
///
/// Kept minimal and source-agnostic: enough to list and then lazily render
/// the full spec (FR-004/FR-005) without re-fetching (SC-005).
class RoadmapSpecRef {
  /// Human-readable title (from frontmatter `title:` or filename fallback).
  final String title;

  /// Absolute path or source-specific identifier used to fetch the full
  /// Markdown content lazily (e.g. filesystem path for local/Vault tiers, or
  /// an MCP resource id for the Brain tier).
  final String path;

  const RoadmapSpecRef({required this.title, required this.path});
}

/// One phase within a milestone.
///
/// `status` intentionally reuses the existing status vocabulary produced by
/// `deriveDisplayStatus` (done/building/planning/paused/…) — this model
/// does not introduce a new vocabulary (FR-003).
class RoadmapPhase {
  /// Phase name, e.g. `M6-learning-loop` or `Phase 3: UI Shell`.
  final String name;

  /// Normalized status string (see `deriveDisplayStatus` for the
  /// vocabulary). Never null — tiers must supply `'unknown'` or similar if
  /// they cannot classify.
  final String status;

  /// Specs associated with this phase, in display order. Empty list (not
  /// null) when the phase has zero specs — callers render an explicit
  /// empty-list message rather than a blank pane (FR-005).
  final List<RoadmapSpecRef> specs;

  /// Optional start date (Wave 3, for the Wave 6 timeline/Gantt view). Null
  /// when the source tier does not carry date information (e.g. the legacy
  /// `.a1/roadmap.md` tier never populates this).
  final DateTime? start;

  /// Optional target/due date (Wave 3, for the Wave 6 timeline/Gantt view).
  final DateTime? target;

  /// Optional completion date (Wave 3, for the Wave 6 timeline/Gantt view).
  final DateTime? finished;

  /// Human-readable titles of phases/features this one depends on (Wave 4,
  /// for the `feature_card.dart` dependency chips). Empty list (not null)
  /// when the source tier does not carry dependency information or the
  /// phase has no dependencies.
  final List<String> dependsOn;

  /// Repo-relative or absolute path to this feature's spec document (Wave 5,
  /// `structured_spec_renderer.dart`), or null when the source tier does not
  /// carry a spec path (e.g. the legacy `.a1/roadmap.md` tier, which uses
  /// [specs] instead).
  final String? specPath;

  /// Repo-relative or absolute path to this feature's wave-plan document
  /// (Wave 5), or null when the source tier does not carry a plan path.
  final String? planPath;

  const RoadmapPhase({
    required this.name,
    required this.status,
    this.specs = const [],
    this.start,
    this.target,
    this.finished,
    this.dependsOn = const [],
    this.specPath,
    this.planPath,
  });
}

/// One milestone row, containing zero or more phases.
class RoadmapMilestone {
  /// Milestone name, e.g. `M6 — Selbstlernendes OS`.
  final String name;

  /// Raw/normalized status text for the milestone itself.
  final String status;

  /// Phases belonging to this milestone, in file/definition order.
  final List<RoadmapPhase> phases;

  /// Optional start date (Wave 3, for the Wave 6 timeline/Gantt view). Null
  /// when the source tier does not carry date information.
  final DateTime? start;

  /// Optional target/due date (Wave 3, for the Wave 6 timeline/Gantt view).
  final DateTime? target;

  /// Optional completion date (Wave 3, for the Wave 6 timeline/Gantt view).
  final DateTime? finished;

  const RoadmapMilestone({
    required this.name,
    required this.status,
    this.phases = const [],
    this.start,
    this.target,
    this.finished,
  });
}

/// Aggregated, source-agnostic roadmap state for a single project.
///
/// Produced by any `RoadmapRepository` implementation and consumed uniformly
/// by the UI regardless of which tier resolved it.
class RoadmapData {
  /// Milestones in file/definition order.
  final List<RoadmapMilestone> milestones;

  /// Raw content of the source tier's "you are here" / next-step summary
  /// (e.g. tier-0's `NEXT.md`), or null when the tier does not supply one.
  /// Rendered as-is by `roadmap_hero.dart` (Wave 4) — no further parsing
  /// performed here.
  final String? nextMdContent;

  const RoadmapData({this.milestones = const [], this.nextMdContent});

  static const empty = RoadmapData();

  /// "Usable data" per FR-002/spec Edge Cases: a tier's result counts as
  /// usable only when it has at least one milestone. This is the predicate
  /// `FallbackRoadmapRepository` uses to decide whether to fall through to
  /// the next tier.
  bool get isEmpty => milestones.isEmpty;
}
