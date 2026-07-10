/// `RoadmapRepository` abstraction for the Roadmap & Backlog Dashboard
/// (spec `001-roadmap-backlog-dashboard`, Wave 1).
///
/// This file defines ONLY the interface + result/failure shapes. It does not
/// implement any tier — see:
///   - `LocalRoadmapRepository` (wraps `A1Reader`, Wave 1, felix)
///   - `A1BrainRoadmapRepository` (MCP client, Wave 1, felix)
///   - `ObsidianVaultRoadmapRepository` (Wave 2, felix)
///   - `FallbackRoadmapRepository` (composes the three, Wave 1 stub + Wave 2
///     completion, felix)
///
/// No Flutter imports — pure Dart, unit-testable and isolate-safe. Per
/// project convention, implementations return a typed empty/failure result
/// rather than throwing.
library;

import 'package:pro_orc/data/models/roadmap_data.dart';

/// Why a tier failed to produce data, when it is a source that CAN fail
/// (currently only the A1 Brain tier — local/Vault "failure" is simply
/// "file/dir not found", which is represented as an empty [RoadmapData],
/// not a [RoadmapFailure]).
///
/// FR-015: the A1 Brain repository MUST classify every failure into exactly
/// one of these three categories, so `FallbackRoadmapRepository` (FR-006)
/// and the UI's "Offline-Fallback" badge (FR-010a) can react correctly
/// regardless of which specific failure occurred.
enum RoadmapFailureKind {
  /// The call did not complete within the expected time budget.
  timeout,

  /// The Keychain token was missing/invalid, or the server rejected it.
  authFailure,

  /// The call completed but found no roadmap data for the given slug
  /// (includes slug-mismatch per FR-008 — treated as "no result", not an
  /// error).
  noResult,
}

/// Typed failure detail, carried alongside an empty [RoadmapData] so callers
/// can distinguish "there is genuinely nothing here" from "this tier is
/// broken right now" without inspecting exceptions or log output.
class RoadmapFailure {
  final RoadmapFailureKind kind;

  /// Non-sensitive, human-readable detail for logs/debugging. MUST NEVER
  /// contain the Keychain bearer token (FR-010) — enforced by the Brain
  /// tier's tests, not by this type, but documented here as a hard
  /// constraint on any string passed through this field.
  final String? message;

  const RoadmapFailure(this.kind, [this.message]);
}

/// The result of a single tier's (or the fallback orchestrator's) resolve
/// call.
///
/// `data` is always present (falls back to [RoadmapData.empty], never
/// null) so callers can use `result.data.isEmpty` uniformly without a null
/// check — consistent with the project's "services return empty, never
/// throw" convention.
class RoadmapResult {
  /// The resolved data. [RoadmapData.empty] when nothing was found or the
  /// tier failed.
  final RoadmapData data;

  /// Which tier actually produced [data]. For a single-tier repository this
  /// is always that tier's own [RoadmapSource]; for
  /// `FallbackRoadmapRepository` it is whichever tier's data proved usable.
  final RoadmapSource source;

  /// Present only when [data] is empty because of a Brain-tier failure
  /// (FR-015). Null for local/Vault tiers and for genuine "no data
  /// anywhere" outcomes — those are just an empty [RoadmapData] with no
  /// failure attached.
  final RoadmapFailure? failure;

  const RoadmapResult({required this.data, required this.source, this.failure});
}

/// A single roadmap data source. Each tier (local / Brain / Vault)
/// implements this against its own storage, adapting to [RoadmapData].
///
/// Contract for every implementation (enforced by convention, not the type
/// system — see project CLAUDE.md "services never throw"):
///   - MUST NOT throw. Any internal error is caught and reported as
///     [RoadmapData.empty] (optionally with a [RoadmapFailure] attached to
///     the returned [RoadmapResult], where applicable to that tier).
///   - MUST be pure Dart (no Flutter imports).
///   - MUST treat an unresolvable/mismatched `slug` the same as "no data"
///     (FR-008) — never a special error path.
abstract class RoadmapRepository {
  /// Resolves roadmap data for [slug] (the project's Vault/Brain-facing
  /// identifier) given [projectPath] (the local filesystem path, used by the
  /// local tier). Tiers that don't need one of the two arguments simply
  /// ignore it.
  Future<RoadmapResult> resolve(String slug, String projectPath);
}

/// Composition contract for the orchestrator that will be implemented as
/// `FallbackRoadmapRepository` (Wave 1 stub with Vault tier deferred to
/// Wave 2; see wave plan).
///
/// `FallbackRoadmapRepository` MUST implement [RoadmapRepository] and
/// compose exactly three constituent [RoadmapRepository]s in this fixed
/// priority order:
///
/// 1. Local tier (`LocalRoadmapRepository`, wraps `A1Reader`) — fastest,
///    always tried first.
/// 2. A1 Brain tier (`A1BrainRoadmapRepository`) — tried only when (1)
///    returned [RoadmapData.empty].
/// 3. Obsidian Vault tier (`ObsidianVaultRoadmapRepository`) — tried only
///    when (1) AND (2) both returned [RoadmapData.empty]. Stubbed to
///    `RoadmapResult(data: RoadmapData.empty, source: RoadmapSource.vault)`
///    in Wave 1; wired to the real Vault reader in Wave 2 (FR-006).
///
/// "Usable data" (the fall-through predicate) = `!result.data.isEmpty`.
/// A [RoadmapFailure] on the Brain tier's result does NOT special-case the
/// fall-through logic — a failed Brain call always yields
/// `data.isEmpty == true`, so the same single predicate
/// (`!result.data.isEmpty`) drives every transition. The orchestrator
/// simply stops at the first tier whose result is usable and returns that
/// tier's `source`; when all three are empty, it returns
/// `RoadmapResult(data: RoadmapData.empty, source: RoadmapSource.vault)`
/// (the last-tried tier) so the UI's empty state (FR-007) has a
/// deterministic, harmless `source` to ignore.
///
/// Each tier is queried lazily and in sequence (never in parallel) — this
/// keeps SC-002 (<2s with Brain available) achievable, since the common
/// case (local tier hits) never reaches the network at all.
abstract class FallbackRoadmapRepositoryContract implements RoadmapRepository {}
