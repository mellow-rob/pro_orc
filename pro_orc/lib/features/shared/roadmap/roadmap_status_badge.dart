import 'package:flutter/material.dart';
import 'package:pro_orc/data/services/gsd_parser.dart';
import 'package:pro_orc/features/shared/status_badge.dart';

/// Status badge for a [RoadmapMilestone]/[RoadmapPhase] row.
///
/// Reuses [GsdStatusBadge] and [deriveGsdStatus] (the exact vocabulary from
/// `GsdParser._deriveStatus`) verbatim — no new status words are introduced
/// for the Roadmap tab (FR-003).
class RoadmapStatusBadge extends StatelessWidget {
  const RoadmapStatusBadge({super.key, required this.rawStatus});

  /// Raw/normalized status string as produced by any roadmap tier (see
  /// `RoadmapMilestone.status` / `RoadmapPhase.status`).
  final String rawStatus;

  @override
  Widget build(BuildContext context) {
    return GsdStatusBadge(status: deriveGsdStatus(rawStatus));
  }
}
