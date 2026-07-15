import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/roadmap/structured_spec_renderer_dialog.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// One status-grouped bucket of milestones, matching the mockup's three
/// `.lane` rows (`#roadmap .lanes .lane`): Aktiv, Fertig, Geplant, in that
/// display order. A group with zero milestones is omitted entirely (the
/// mockup never shows an empty lane).
enum _LaneGroup { active, done, planned }

extension on _LaneGroup {
  /// Mockup `.badge` label text (`Aktiv`/`Fertig`/`Geplant`).
  String get badgeLabel => switch (this) {
    _LaneGroup.active => 'Aktiv',
    _LaneGroup.done => 'Fertig',
    _LaneGroup.planned => 'Geplant',
  };

  /// Mockup `.lane .when h3` serif heading ("In Arbeit"/"Ausgeliefert"/
  /// "Geplant").
  String get heading => switch (this) {
    _LaneGroup.active => 'In Arbeit',
    _LaneGroup.done => 'Ausgeliefert',
    _LaneGroup.planned => 'Geplant',
  };

  /// Mockup `.lane .when .sub` — a short description line under the
  /// heading. Kept generic (not milestone-count-dependent) since the
  /// mockup's own sub-lines ("Der aktuelle Fokus", "v2.2 bis v3.1") are
  /// project-specific prose we cannot derive from data.
  String get sub => switch (this) {
    _LaneGroup.active => 'Der aktuelle Fokus',
    _LaneGroup.done => 'Bereits ausgeliefert',
    _LaneGroup.planned => 'Als Naechstes geplant',
  };

  /// Mockup `.badge.active-b`/`.done-b`/`.planned-b` colors.
  Color badgeColor(AppColors colors) => switch (this) {
    _LaneGroup.active => colors.cyan,
    _LaneGroup.done => colors.emerald,
    _LaneGroup.planned => colors.textSec,
  };

  Color badgeBackground(AppColors colors) => switch (this) {
    _LaneGroup.active => colors.cyan.withValues(alpha: 0.12),
    _LaneGroup.done => colors.emerald.withValues(alpha: 0.12),
    _LaneGroup.planned => colors.bgElev,
  };
}

/// Classifies a milestone's raw status into one of the three lane groups
/// (FR-005: "lanes grouped Aktiv→Fertig→Geplant"). Anything not recognized
/// as done/planning defaults to [_LaneGroup.active] so in-flight or
/// unrecognized statuses (e.g. "building", "paused", "research") still
/// surface prominently rather than being silently dropped into "Geplant".
_LaneGroup _groupFor(RoadmapMilestone milestone) {
  final status = deriveDisplayStatus(milestone.status);
  if (status == DisplayStatus.done) return _LaneGroup.done;
  if (status == DisplayStatus.planning) return _LaneGroup.planned;
  return _LaneGroup.active;
}

/// Groups milestones into the three lane buckets, preserving each
/// milestone's original relative order within its bucket, and omitting
/// buckets with zero milestones.
Map<_LaneGroup, List<RoadmapMilestone>> _groupMilestones(
  List<RoadmapMilestone> milestones,
) {
  final grouped = <_LaneGroup, List<RoadmapMilestone>>{};
  for (final milestone in milestones) {
    final group = _groupFor(milestone);
    grouped.putIfAbsent(group, () => []).add(milestone);
  }
  return {
    for (final group in _LaneGroup.values)
      if (grouped.containsKey(group)) group: grouped[group]!,
  };
}

/// Milestone lanes (grouped by status, FR-005) + feature-card drill-down for
/// the tier-0 Roadmap path (FR-013/FR-014/FR-016).
///
/// Renders one lane section per status group (Aktiv → Fertig → Geplant),
/// each with a [MilestoneLane] per milestone; tapping a lane selects it and
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
    final grouped = _groupMilestones(milestones);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in grouped.entries)
                    _LaneSection(
                      group: entry.key,
                      milestones: entry.value,
                      colors: colors,
                      accent: accent,
                      selected: selected,
                      onMilestoneSelected: onMilestoneSelected,
                      isFirst: entry.key == grouped.keys.first,
                    ),
                ],
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 28),
            _FeatureCardsSection(milestone: selected, colors: colors),
          ],
        ],
      ),
    );
  }
}

/// One status-grouped lane section (mockup `.lane`): a left "when" column
/// (badge + serif heading + sub-line) and a right column of tappable
/// [MilestoneLane] rows.
class _LaneSection extends StatelessWidget {
  const _LaneSection({
    required this.group,
    required this.milestones,
    required this.colors,
    required this.accent,
    required this.selected,
    required this.onMilestoneSelected,
    required this.isFirst,
  });

  final _LaneGroup group;
  final List<RoadmapMilestone> milestones;
  final AppColors colors;
  final Color accent;
  final RoadmapMilestone? selected;
  final ValueChanged<RoadmapMilestone> onMilestoneSelected;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: isFirst
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.textPri.withValues(alpha: 0.08)),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 185,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LaneBadge(group: group, colors: colors),
                const SizedBox(height: 12),
                Text(
                  group.heading,
                  style: N3Typography.display(
                    colors: colors,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group.sub,
                  style: TextStyle(color: colors.textDim, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 26),
          Expanded(
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
                  if (milestone != milestones.last) const SizedBox(height: 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mockup `.badge` pill (e.g. "Aktiv"/"Fertig"/"Geplant").
class _LaneBadge extends StatelessWidget {
  const _LaneBadge({required this.group, required this.colors});

  final _LaneGroup group;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: group.badgeBackground(colors),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        group.badgeLabel.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.1,
          color: group.badgeColor(colors),
        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mockup `.fcards` uses a 2-column grid; fall back to a single
        // column when the pane is too narrow for two comfortable cards.
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: columns == 2 ? 2.1 : 2.6,
          children: [
            for (final feature in milestone.phases)
              FeatureCard(
                feature: feature,
                colors: colors,
                onTap: () => showStructuredSpecRenderer(
                  context,
                  specPath: feature.specPath,
                  planPath: feature.planPath,
                ),
              ),
          ],
        );
      },
    );
  }
}
