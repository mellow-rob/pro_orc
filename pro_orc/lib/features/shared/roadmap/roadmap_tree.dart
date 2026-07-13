import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_status_badge.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Read-only milestone/phase tree for the Roadmap tab's left pane (~35%
/// width, FR-016).
///
/// Purely presentational: no tap handlers write anything (FR-012), and no
/// search field exists here or anywhere else in the feature (FR-013).
/// Tapping a phase notifies [onPhaseSelected] so the detail pane can show
/// its spec list (Wave 4, FR-004).
class RoadmapTree extends StatelessWidget {
  const RoadmapTree({
    super.key,
    required this.milestones,
    required this.colors,
    required this.accent,
    this.onPhaseSelected,
    this.selectedPhase,
  });

  final List<RoadmapMilestone> milestones;
  final AppColors colors;
  final Color accent;
  final ValueChanged<RoadmapPhase>? onPhaseSelected;
  final RoadmapPhase? selectedPhase;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // Lazily-built scrollable per Wave 6 (FR-014) — avoids eagerly
      // materializing every milestone/phase row up front.
      itemCount: milestones.length,
      itemBuilder: (context, index) => _MilestoneNode(
        milestone: milestones[index],
        colors: colors,
        accent: accent,
        onPhaseSelected: onPhaseSelected,
        selectedPhase: selectedPhase,
      ),
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  const _MilestoneNode({
    required this.milestone,
    required this.colors,
    required this.accent,
    required this.onPhaseSelected,
    required this.selectedPhase,
  });

  final RoadmapMilestone milestone;
  final AppColors colors;
  final Color accent;
  final ValueChanged<RoadmapPhase>? onPhaseSelected;
  final RoadmapPhase? selectedPhase;

  /// True when this milestone has exactly one phase whose name duplicates
  /// the milestone's own name — the local a1 tier's single-phase adapter
  /// shape (see `LocalRoadmapRepository`). Showing both a milestone row and
  /// an identical phase row underneath is pure visual duplication, so this
  /// case collapses to a single clickable row instead.
  bool get _isSinglePhaseDuplicate =>
      milestone.phases.length == 1 &&
      milestone.phases.single.name == milestone.name;

  @override
  Widget build(BuildContext context) {
    if (_isSinglePhaseDuplicate) {
      final phase = milestone.phases.single;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _PhaseNode(
          phase: phase,
          colors: colors,
          accent: accent,
          selected: identical(phase, selectedPhase),
          onTap: onPhaseSelected == null ? null : () => onPhaseSelected!(phase),
          nameStyle: TextStyle(
            color: colors.textPri,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  milestone.name,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RoadmapStatusBadge(rawStatus: milestone.status),
          for (final phase in milestone.phases)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 6),
              child: _PhaseNode(
                phase: phase,
                colors: colors,
                accent: accent,
                selected: identical(phase, selectedPhase),
                onTap: onPhaseSelected == null
                    ? null
                    : () => onPhaseSelected!(phase),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single phase row. Tapping it surfaces the phase's spec list in the
/// detail pane (Wave 4) — purely a read/select action, never a write
/// (FR-012).
class _PhaseNode extends StatelessWidget {
  const _PhaseNode({
    required this.phase,
    required this.colors,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.nameStyle,
  });

  final RoadmapPhase phase;
  final AppColors colors;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;

  /// Overrides the default (dim, small) name style — used when a milestone
  /// with a single duplicate-named phase collapses into this row alone, so
  /// it should read like a milestone row, not an indented child row.
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              phase.name,
              style:
                  nameStyle ?? TextStyle(color: colors.textSec, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            RoadmapStatusBadge(rawStatus: phase.status),
          ],
        ),
      ),
    );
  }
}
