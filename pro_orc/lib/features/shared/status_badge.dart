import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// GSD status badge chip — maps project status string to a colored label.
///
/// Supported status values and their colors:
/// - 'building'  -> "In Progress"  (cyan)
/// - 'planning'  -> "Planned"      (amber-yellow)
/// - 'done'      -> "Complete"     (green)
/// - 'research'  -> "Research"     (fuchsia)
/// - 'paused'    -> "Paused"       (amber)
/// - null/other  -> "Not Started"  (textDis / grey)
class GsdStatusBadge extends StatelessWidget {
  const GsdStatusBadge({super.key, this.status});

  final String? status;

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
      'building' => ('In Progress', colors.cyan),
      'planning' => ('Planned', const Color(0xFFE0A020)),
      'done' => ('Complete', const Color(0xFF22C55E)),
      'research' => ('Research', colors.fuch),
      'paused' => ('Paused', const Color(0xFFF59E0B)),
      _ => ('Not Started', colors.textDis),
    };
  }
}
