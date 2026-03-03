import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/gsd_status.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// GSD status badge chip — maps [GsdStatus] to a colored label.
class GsdStatusBadge extends StatelessWidget {
  const GsdStatusBadge({super.key, this.status});

  final GsdStatus? status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final (label, color) = _resolve(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (String, Color) _resolve(AppColors colors) {
    return switch (status) {
      GsdStatus.building => ('In Progress', colors.cyan),
      GsdStatus.planning => ('Planned', const Color(0xFFE0A020)),
      GsdStatus.done => ('Complete', const Color(0xFF22C55E)),
      GsdStatus.research => ('Research', colors.fuch),
      GsdStatus.paused => ('Paused', const Color(0xFFF59E0B)),
      GsdStatus.archived => ('Archived', colors.textDis),
      null => ('Not Started', colors.textDis),
    };
  }
}
