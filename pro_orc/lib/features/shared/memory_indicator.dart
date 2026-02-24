import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/memory_data.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Memory status indicator — shows Claude memory consolidation status for a project.
///
/// Renders as a clickable button with brain icon + "zzz" text.
/// Visual states based on [MemoryData]:
/// - No memory (null): gray/disabled — click triggers rem-sleep via [onTap]
/// - Memory, fresh: violet — memory exists and is up to date
/// - Memory, stale: amber — memory exists but needs refreshing
///
/// Tooltip shows German date text or "Keine Memory vorhanden".
class MemoryIndicator extends StatelessWidget {
  const MemoryIndicator({
    super.key,
    required this.memory,
    required this.colors,
    this.onTap,
  });

  final MemoryData? memory;
  final AppColors colors;

  /// Called when the indicator is tapped. Opens Terminal for rem-sleep.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = _resolveColor();
    final tooltip = _resolveTooltip();

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.brain100,
                color: iconColor,
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                'zzz',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveColor() {
    if (memory == null) return colors.textDis;
    if (memory!.isStale) return colors.amber;
    return colors.violet;
  }

  String _resolveTooltip() {
    if (memory == null) return 'Keine Memory vorhanden';
    final date = memory!.lastConsolidated;
    if (date == null) return 'Memory vorhanden';
    return 'Letzte Konsolidierung: ${_formatDate(date)}';
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}
