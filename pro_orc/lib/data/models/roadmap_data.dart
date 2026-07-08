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
/// `GsdParser._deriveStatus` (done/building/planning/paused/…) — this model
/// does not introduce a new vocabulary (FR-003).
class RoadmapPhase {
  /// Phase name, e.g. `M6-learning-loop` or `Phase 3: UI Shell`.
  final String name;

  /// Normalized status string (see `GsdParser._deriveStatus` for the
  /// vocabulary). Never null — tiers must supply `'unknown'` or similar if
  /// they cannot classify.
  final String status;

  /// Specs associated with this phase, in display order. Empty list (not
  /// null) when the phase has zero specs — callers render an explicit
  /// empty-list message rather than a blank pane (FR-005).
  final List<RoadmapSpecRef> specs;

  const RoadmapPhase({
    required this.name,
    required this.status,
    this.specs = const [],
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

  const RoadmapMilestone({
    required this.name,
    required this.status,
    this.phases = const [],
  });
}

/// Aggregated, source-agnostic roadmap state for a single project.
///
/// Produced by any `RoadmapRepository` implementation and consumed uniformly
/// by the UI regardless of which tier resolved it.
class RoadmapData {
  /// Milestones in file/definition order.
  final List<RoadmapMilestone> milestones;

  const RoadmapData({this.milestones = const []});

  static const empty = RoadmapData();

  /// "Usable data" per FR-002/spec Edge Cases: a tier's result counts as
  /// usable only when it has at least one milestone. This is the predicate
  /// `FallbackRoadmapRepository` uses to decide whether to fall through to
  /// the next tier.
  bool get isEmpty => milestones.isEmpty;
}
