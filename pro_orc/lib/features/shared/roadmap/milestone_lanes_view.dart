import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Milestone lanes + feature-card drill-down for the tier-0 Roadmap path
/// (FR-013/FR-014/FR-016).
///
/// Renders one [MilestoneLane] per milestone; tapping a lane selects it and
/// shows that milestone's features as [FeatureCard]s below the lanes, or an
/// explicit "keine Features" message when the milestone has zero features.
///
/// Selection lives in local widget state (matching the existing
/// `_RoadmapSplitViewState` convention) — kept as a single nullable
/// `_selectedMilestone` field so a later `viewMode` toggle (Wave 7,
/// lanes|timeline) can sit alongside it without disturbing the selection.
class MilestoneLanesView extends StatefulWidget {
  const MilestoneLanesView({
    super.key,
    required this.milestones,
    required this.colors,
    required this.accent,
  });

  final List<RoadmapMilestone> milestones;
  final AppColors colors;
  final Color accent;

  @override
  State<MilestoneLanesView> createState() => _MilestoneLanesViewState();
}

class _MilestoneLanesViewState extends State<MilestoneLanesView> {
  RoadmapMilestone? _selectedMilestone;

  void _selectMilestone(RoadmapMilestone milestone) {
    setState(() => _selectedMilestone = milestone);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final accent = widget.accent;
    final selected = _selectedMilestone;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final milestone in widget.milestones) ...[
            MilestoneLane(
              milestone: milestone,
              colors: colors,
              accent: accent,
              selected: identical(milestone, selected),
              onTap: () => _selectMilestone(milestone),
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
          FeatureCard(feature: feature, colors: colors),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
