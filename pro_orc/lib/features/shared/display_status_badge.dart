import 'package:flutter/material.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Generic status badge chip — maps [DisplayStatus] to a colored label.
///
/// Successor of the removed GSD-specific `GsdStatusBadge`: same
/// color/label logic, generic naming (no GSD dependency).
class DisplayStatusBadge extends StatelessWidget {
  const DisplayStatusBadge({super.key, this.status});

  final DisplayStatus? status;

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
      DisplayStatus.building => ('In Progress', colors.cyan),
      DisplayStatus.planning => ('Planned', const Color(0xFFE0A020)),
      DisplayStatus.done => ('Complete', const Color(0xFF22C55E)),
      DisplayStatus.research => ('Research', colors.fuch),
      DisplayStatus.paused => ('Paused', const Color(0xFFF59E0B)),
      DisplayStatus.archived => ('Archived', colors.textDis),
      null => ('Not Started', colors.textDis),
    };
  }
}
