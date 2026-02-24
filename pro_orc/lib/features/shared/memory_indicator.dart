import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/memory_data.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Memory status indicator — shows Claude memory consolidation status for a project.
///
/// Visual states based on [MemoryData]:
/// - No memory (null): gray/disabled icon — no consolidation present
/// - Memory, fresh: violet icon — memory exists and is up to date
/// - Memory, stale: amber icon — memory exists but needs refreshing
///
/// Tooltip shows German date text or "Keine Memory vorhanden".
class MemoryIndicator extends StatelessWidget {
  const MemoryIndicator({
    super.key,
    required this.memory,
    required this.colors,
  });

  final MemoryData? memory;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final iconColor = _resolveColor();
    final tooltip = _resolveTooltip();

    return Tooltip(
      message: tooltip,
      child: Icon(
        LucideIcons.bookMarked100,
        color: iconColor,
        size: 13,
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
