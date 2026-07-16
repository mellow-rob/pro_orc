import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/roadmap/feature_card.dart';
import 'package:pro_orc/features/shared/roadmap/milestone_lane.dart';
import 'package:pro_orc/features/shared/roadmap/structured_spec_renderer_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// One status-grouped bucket of milestones, matching mockup v2's three
/// `.rm-section-label` groups: Aktiv, Fertig, Geplant, in that display
/// order. A group with zero milestones is omitted entirely — the mockup
/// never invents an empty "Geplant" placeholder group (FR-003).
enum _LaneGroup { active, done, planned }

extension on _LaneGroup {
  /// Mockup `.rm-section-label` text (`Aktiv`/`Fertig`/`Geplant`).
  String get label => switch (this) {
    _LaneGroup.active => 'Aktiv',
    _LaneGroup.done => 'Fertig',
    _LaneGroup.planned => 'Geplant',
  };
}

/// Classifies a milestone's raw status into one of the three lane groups
/// (FR-003: "gruppiert unter Aktiv/Fertig/Geplant"). Anything not
/// recognized as done/planning defaults to [_LaneGroup.active] so in-flight
/// or unrecognized statuses (e.g. "building", "paused", "research") still
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

/// Milestone accordion (FR-003, mockup v2 pane `#roadmap`): one compact row
/// per milestone grouped under subtle Aktiv/Fertig/Geplant section labels.
/// Only active milestone(s) start expanded; clicking a row toggles its
/// accordion; the expanded body renders that milestone's features as
/// compact indented [FeatureCard] rows (not cards/grids); clicking a
/// feature row opens the existing structured spec dialog.
///
/// [selectedMilestone]/[onMilestoneSelected] remain the single controlled
/// value hoisted by `ProjectDetailPanel` (feature 002) so the
/// last-interacted-with milestone survives a Roadmap<->Zeitstrahl tab
/// round-trip (FR-009) — this widget additionally keeps its own internal
/// per-milestone expand/collapse state (SC-001: only the active milestone's
/// body is visible on first render) and folds a tap on any row into both:
/// it toggles that row's local expanded state AND reports the tap via
/// [onMilestoneSelected] so the hoisted selection tracks the
/// most-recently-toggled milestone for the cross-tab persistence contract.
class MilestoneLanesView extends StatefulWidget {
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

  /// The most-recently toggled milestone, owned by the parent so it
  /// survives a view-mode switch (lanes <-> timeline tab).
  final RoadmapMilestone? selectedMilestone;

  final ValueChanged<RoadmapMilestone> onMilestoneSelected;

  @override
  State<MilestoneLanesView> createState() => _MilestoneLanesViewState();
}

class _MilestoneLanesViewState extends State<MilestoneLanesView> {
  /// Milestones whose accordion body is currently expanded, tracked by
  /// identity (milestone names are not guaranteed unique across tiers).
  ///
  /// Deliberately NOT re-synced from `widget.selectedMilestone` in
  /// `didUpdateWidget`: every toggle already reports through
  /// `onMilestoneSelected`, so a naive "re-add the hoisted selection to
  /// `_expanded`" reaction would immediately re-expand a milestone the user
  /// just collapsed (the parent's `selectedMilestone` still points at it).
  /// The one-time initialization below already covers the "mount with an
  /// already-selected milestone" case (e.g. after a tab round-trip, this
  /// widget remounts fresh with `_initialized == false`).
  final Set<RoadmapMilestone> _expanded = {};
  bool _initialized = false;

  void _initializeExpandedIfNeeded() {
    if (_initialized) return;
    _initialized = true;
    // SC-001: only active milestone(s) start expanded.
    for (final milestone in widget.milestones) {
      if (_groupFor(milestone) == _LaneGroup.active) {
        _expanded.add(milestone);
      }
    }
    final selected = widget.selectedMilestone;
    if (selected != null) _expanded.add(selected);
  }

  void _toggle(RoadmapMilestone milestone) {
    setState(() {
      if (_expanded.contains(milestone)) {
        _expanded.remove(milestone);
      } else {
        _expanded.add(milestone);
      }
    });
    widget.onMilestoneSelected(milestone);
  }

  @override
  Widget build(BuildContext context) {
    _initializeExpandedIfNeeded();
    final grouped = _groupMilestones(widget.milestones);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in grouped.entries) ...[
            _GroupLabel(group: entry.key, colors: widget.colors),
            const SizedBox(height: 8),
            Column(
              children: [
                for (final milestone in entry.value) ...[
                  _AccordionItem(
                    milestone: milestone,
                    colors: widget.colors,
                    accent: widget.accent,
                    expanded: _expanded.contains(milestone),
                    onToggle: () => _toggle(milestone),
                  ),
                  if (milestone != entry.value.last)
                    const SizedBox(height: 6),
                ],
              ],
            ),
            if (entry.key != grouped.keys.last) const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

/// Mockup `.rm-section-label` — subtle uppercase group label.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.group, required this.colors});

  final _LaneGroup group;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      group.label.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.1,
        color: colors.textDim,
      ),
    );
  }
}

/// One accordion item (mockup `.m-item`): the [MilestoneLane] row plus its
/// expandable feature-row body.
class _AccordionItem extends StatelessWidget {
  const _AccordionItem({
    required this.milestone,
    required this.colors,
    required this.accent,
    required this.expanded,
    required this.onToggle,
  });

  final RoadmapMilestone milestone;
  final AppColors colors;
  final Color accent;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textPri.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MilestoneLane(
            milestone: milestone,
            colors: colors,
            accent: accent,
            selected: expanded,
            expanded: expanded,
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
              child: _FeatureRowsBody(milestone: milestone, colors: colors),
            ),
        ],
      ),
    );
  }
}

/// Expanded accordion body: compact indented feature rows (FR-003), or the
/// mockup's placeholder text when the milestone has zero feature specs
/// (FR-014 precedent).
class _FeatureRowsBody extends StatelessWidget {
  const _FeatureRowsBody({required this.milestone, required this.colors});

  final RoadmapMilestone milestone;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    if (milestone.phases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Keine Feature-Spec-Dateien fuer diesen Meilenstein hinterlegt.',
          style: TextStyle(
            color: colors.textDim,
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in milestone.phases)
          FeatureCard(
            feature: feature,
            colors: colors,
            onTap: () => showStructuredSpecRenderer(
              context,
              specPath: feature.specPath,
              planPath: feature.planPath,
              title: feature.name,
              status: feature.status,
            ),
          ),
      ],
    );
  }
}
