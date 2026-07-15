import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_status_badge.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Tappable milestone lane row for the tier-0 Roadmap hero view (FR-013).
///
/// Shows the milestone's status badge (via [RoadmapStatusBadge] /
/// `deriveDisplayStatus` — no parallel status vocabulary), title, and
/// target date. Tapping selects the milestone so its features render as
/// cards (FR-016).
class MilestoneLane extends StatelessWidget {
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

  String _formatTarget(DateTime target) =>
      '${_monthNames[target.month - 1]} ${target.year}';

  @override
  Widget build(BuildContext context) {
    final target = milestone.target;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: GlassCard(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: accent.withValues(alpha: 0.6))
                  : null,
            ),
            child: Row(
              children: [
                RoadmapStatusBadge(rawStatus: milestone.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    milestone.name,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (target != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.flag_outlined, size: 13, color: colors.textDim),
                  const SizedBox(width: 4),
                  Text(
                    _formatTarget(target),
                    style: TextStyle(color: colors.textDim, fontSize: 11),
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
