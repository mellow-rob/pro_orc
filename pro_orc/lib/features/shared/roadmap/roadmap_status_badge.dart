import 'package:flutter/material.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/display_status_badge.dart';

/// Status badge for a [RoadmapMilestone]/[RoadmapPhase] row.
///
/// Reuses [DisplayStatusBadge] and [deriveDisplayStatus] verbatim — no new
/// status words are introduced for the Roadmap tab (FR-003).
class RoadmapStatusBadge extends StatelessWidget {
  const RoadmapStatusBadge({super.key, required this.rawStatus});

  /// Raw/normalized status string as produced by any roadmap tier (see
  /// `RoadmapMilestone.status` / `RoadmapPhase.status`).
  final String rawStatus;

  @override
  Widget build(BuildContext context) {
    return DisplayStatusBadge(status: deriveDisplayStatus(rawStatus));
  }
}
