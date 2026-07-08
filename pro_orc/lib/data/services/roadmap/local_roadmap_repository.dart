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

  /// Adapts [A1Data]'s milestone-table shape into [RoadmapData]. `A1Data`
  /// has no per-phase spec references and no milestone→phase nesting (it's a
  /// flat milestone list + a flat phase list), so each phase becomes its own
  /// single-phase "milestone" entry — the phase's own name doubles as the
  /// milestone label since the local tier has no coarser grouping today.
  RoadmapData _toRoadmapData(A1Data a1Data) {
    if (a1Data.isEmpty) return RoadmapData.empty;

    final milestones = <RoadmapMilestone>[
      for (final m in a1Data.milestones)
        RoadmapMilestone(name: m.name, status: m.status, phases: const []),
      for (final ph in a1Data.phases)
        RoadmapMilestone(
          name: ph.name,
          status: ph.isActive ? 'in_progress' : 'done',
          phases: [
            RoadmapPhase(
              name: ph.name,
              status: ph.isActive ? 'in_progress' : 'done',
            ),
          ],
        ),
    ];

    return RoadmapData(milestones: milestones);
  }
}
