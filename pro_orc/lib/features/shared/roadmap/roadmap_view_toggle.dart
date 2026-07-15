import 'package:flutter/material.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Which view the tier-0 Roadmap tab currently renders below the toggle.
enum RoadmapViewMode {
  /// Milestone lanes with click-to-drill-down feature cards (Wave 4).
  lanes,

  /// Timeline/Gantt view of the same milestones + features (Wave 6).
  timeline,
}

/// Segmented-control-style toggle to switch between the milestone-lane list
/// and the timeline/Gantt view (FR-022).
///
/// Modeled on the existing `_TabButton`/`_buildTabSwitch` pattern in
/// `project_detail_panel.dart` — deliberately not a new interaction pattern
/// (per the Wave 7 brief/Clarifications).
class RoadmapViewToggle extends StatelessWidget {
  const RoadmapViewToggle({
    super.key,
    required this.mode,
    required this.colors,
    required this.accent,
    required this.onChanged,
  });

  final RoadmapViewMode mode;
  final AppColors colors;
  final Color accent;
  final ValueChanged<RoadmapViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ViewToggleButton(
          label: 'Übersicht',
          selected: mode == RoadmapViewMode.lanes,
          colors: colors,
          accent: accent,
          onTap: () => onChanged(RoadmapViewMode.lanes),
        ),
        const SizedBox(width: 8),
        _ViewToggleButton(
          label: 'Zeitstrahl',
          selected: mode == RoadmapViewMode.timeline,
          colors: colors,
          accent: accent,
          onTap: () => onChanged(RoadmapViewMode.timeline),
        ),
      ],
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.4) : colors.bgElev,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : colors.textDim,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
