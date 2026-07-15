import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/roadmap/structured_spec_renderer_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Milestone lanes + feature-card drill-down for the tier-0 Roadmap path
/// (FR-013/FR-014/FR-016).
///
/// Renders one [MilestoneLane] per milestone; tapping a lane selects it and
/// shows that milestone's features as [FeatureCard]s below the lanes, or an
/// explicit "keine Features" message when the milestone has zero features.
///
/// Selection is a controlled value ([selectedMilestone]/[onMilestoneSelected])
/// rather than local widget state: the Zeitstrahl tab (feature 002, Wave 1)
/// needs the selection to survive switching to that sibling top-level tab
/// and back, so the selection is hoisted all the way up to
/// `ProjectDetailPanel`'s state instead of living inside this widget, which
/// would reset it on rebuild/remount.
class MilestoneLanesView extends StatelessWidget {
  const MilestoneLanesView({
    super.key,
    required this.milestones,
    required this.colors,
    required this.accent,
    required this.selectedMilestone,
    required this.onMilestoneSelected,
  });

  final List<RoadmapMilestone> milestones;
  final AppColors colors;
  final Color accent;

  /// Currently selected milestone, owned by the parent so it survives a
  /// Wave 7 view-mode switch (lanes <-> timeline).
  final RoadmapMilestone? selectedMilestone;

  final ValueChanged<RoadmapMilestone> onMilestoneSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedMilestone;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final milestone in milestones) ...[
            MilestoneLane(
              milestone: milestone,
              colors: colors,
              accent: accent,
              selected: identical(milestone, selected),
              onTap: () => onMilestoneSelected(milestone),
            ),
            const SizedBox(height: 8),
          ],
          if (selected != null) ...[
            const SizedBox(height: 8),
            _FeatureCardsSection(milestone: selected, colors: colors),
          ],
        ],
      ),
    );
  }
}

/// Feature-card list for the currently-selected milestone (FR-016), with the
/// FR-014 "keine Features" empty state mirroring `SpecList`'s
/// "Keine Specs..." precedent.
class _FeatureCardsSection extends StatelessWidget {
  const _FeatureCardsSection({required this.milestone, required this.colors});

  final RoadmapMilestone milestone;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (milestone.phases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Keine Features fuer diesen Meilenstein',
            style: TextStyle(color: colors.textDim, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in milestone.phases) ...[
          FeatureCard(
            feature: feature,
            colors: colors,
            onTap: () => showStructuredSpecRenderer(
              context,
              specPath: feature.specPath,
              planPath: feature.planPath,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
