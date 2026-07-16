import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_id_chip.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Tappable milestone row for the tier-0 Roadmap lanes (FR-005, mockup
/// `#roadmap .lane li`): a small status dot, a mono id-chip (e.g. `m8`), the
/// milestone title, and a right-aligned mono date — with a hover highlight
/// and a chevron affordance. Tapping selects the milestone so its features
/// render as cards below (FR-016).
class MilestoneLane extends StatefulWidget {
  const MilestoneLane({
    super.key,
    required this.milestone,
    required this.colors,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final RoadmapMilestone milestone;
  final AppColors colors;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mrz',
    'Apr',
    'Mai',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Okt',
    'Nov',
    'Dez',
  ];

  static String _formatTarget(DateTime target) =>
      '${_monthNames[target.month - 1]} ${target.year}';

  /// Status-dot color (mockup `.st.done`/`.st.active`/`.st.planned`) — reuses
  /// the shared status vocabulary, no parallel color mapping.
  static Color statusDotColor(String rawStatus, AppColors colors) {
    return switch (deriveDisplayStatus(rawStatus)) {
      DisplayStatus.done => colors.emerald,
      DisplayStatus.building => colors.cyan,
      DisplayStatus.research => colors.fuch,
      DisplayStatus.paused => colors.amber,
      DisplayStatus.archived => colors.textDis,
      DisplayStatus.planning || null => colors.textDim,
    };
  }

  @override
  State<MilestoneLane> createState() => _MilestoneLaneState();
}

class _MilestoneLaneState extends State<MilestoneLane> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final milestone = widget.milestone;
    final target = milestone.target;
    final chip = extractRoadmapIdChip(milestone.name);
    final dotColor = MilestoneLane.statusDotColor(milestone.status, colors);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _hovered ? colors.bgElev : Colors.transparent,
              border: Border.all(
                color: widget.selected
                    ? widget.accent.withValues(alpha: 0.6)
                    : (_hovered
                          ? colors.textPri.withValues(alpha: 0.08)
                          : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                if (chip != null) ...[
                  _MonoIdChip(label: chip, colors: colors),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    milestone.name,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (target != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    MilestoneLane._formatTarget(target),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: colors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mono id-chip (mockup `.mchip`, e.g. `m8`) shown left of the milestone
/// title.
class _MonoIdChip extends StatelessWidget {
  const _MonoIdChip({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bgSurf,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.textPri.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: colors.cyanLo,
        ),
      ),
    );
  }
}
