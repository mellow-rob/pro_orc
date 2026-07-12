import 'package:pro_orc/data/models/a1_data.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/a1_reader.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';

/// Local-tier [RoadmapRepository]: wraps the existing [A1Reader] and adapts
/// its `.a1/roadmap.md` + `.a1/phases/` output ([A1Data]) into the
/// source-agnostic [RoadmapData] model.
///
/// This is deliberately a thin adapter — all parsing logic lives in
/// [A1Reader] and is reused verbatim (per project convention: no
/// reimplemented parsing). Pure Dart, no Flutter imports. Never throws:
/// [A1Reader] already returns [A1Data.empty] on any internal failure, so
/// this repository always resolves to a [RoadmapResult] with
/// [RoadmapSource.local].
class LocalRoadmapRepository implements RoadmapRepository {
  LocalRoadmapRepository({A1Reader? reader}) : _reader = reader ?? A1Reader();

  final A1Reader _reader;

  /// Resolves local roadmap data for [projectPath]. [slug] is ignored — the
  /// local tier is addressed purely by filesystem path.
  @override
  Future<RoadmapResult> resolve(String slug, String projectPath) async {
    final a1Data = await _reader.read(projectPath);
    return RoadmapResult(
      data: _toRoadmapData(a1Data),
      source: RoadmapSource.local,
    );
  }

  /// Adapts [A1Data]'s milestone-table shape into [RoadmapData]. `A1Data` has
  /// no native milestone→phase nesting (it's a flat milestone list + a flat
  /// phase list), so this adapter reconstructs the nesting by matching each
  /// phase's leading token (e.g. `M6` in `M6-learning-loop`) against the same
  /// leading token in a milestone's name (e.g. `M6` in `M6 — Selbstlernendes
  /// OS`). A phase that matches no milestone becomes its own single-phase
  /// milestone entry (name doubles as label) rather than being dropped or
  /// duplicated under multiple parents.
  RoadmapData _toRoadmapData(A1Data a1Data) {
    if (a1Data.isEmpty) return RoadmapData.empty;

    final unmatchedPhases = <A1Phase>[];
    final phasesByMilestoneToken = <String, List<A1Phase>>{};
    for (final ph in a1Data.phases) {
      final token = _leadingToken(ph.name);
      if (token == null) {
        unmatchedPhases.add(ph);
        continue;
      }
      phasesByMilestoneToken.putIfAbsent(token, () => []).add(ph);
    }

    final milestones = <RoadmapMilestone>[];
    for (final m in a1Data.milestones) {
      final token = _leadingToken(m.name);
      final matched = token == null
          ? const <A1Phase>[]
          : phasesByMilestoneToken.remove(token) ?? const <A1Phase>[];
      milestones.add(
        RoadmapMilestone(
          name: m.name,
          status: m.status,
          phases: [for (final ph in matched) _toRoadmapPhase(ph)],
        ),
      );
    }

    // Phases whose leading token matched no milestone (including ones left
    // over in the map, e.g. duplicate tokens) become standalone entries.
    final leftover = phasesByMilestoneToken.values.expand((v) => v);
    for (final ph in [...unmatchedPhases, ...leftover]) {
      milestones.add(
        RoadmapMilestone(
          name: ph.name,
          status: ph.isActive ? 'in_progress' : 'done',
          phases: [_toRoadmapPhase(ph)],
        ),
      );
    }

    return RoadmapData(milestones: milestones);
  }

  RoadmapPhase _toRoadmapPhase(A1Phase ph) =>
      RoadmapPhase(name: ph.name, status: ph.isActive ? 'in_progress' : 'done');

  /// Extracts the leading alphanumeric token used to match phases to
  /// milestones, e.g. `M6` from both `M6-learning-loop` and
  /// `M6 — Selbstlernendes OS`. Returns null when the name has no such token.
  static final _leadingTokenPattern = RegExp(r'^([A-Za-z0-9]+)');

  String? _leadingToken(String name) {
    final match = _leadingTokenPattern.firstMatch(name.trim());
    return match?.group(1);
  }
}
