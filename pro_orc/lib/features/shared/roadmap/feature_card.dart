import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Feature card for the tier-0 Roadmap drill-down (FR-016): shown for each
/// feature ([RoadmapPhase]) of a selected milestone.
///
/// Status-colored left edge (same color mapping as [DisplayStatusBadge] —
/// no parallel status vocabulary, just its color reused visually), title,
/// timeframe (start -> finished/target), and dependency chips.
///
/// When [onTap] is provided, tapping the card opens the Wave 5 structured
/// spec/plan renderer for this feature (FR-017). Optional so existing call
/// sites/tests that only render the card visually keep working unchanged.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.feature,
    required this.colors,
    this.onTap,
  });

  final RoadmapPhase feature;
  final AppColors colors;
  final VoidCallback? onTap;

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

  String _formatDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  /// Same color mapping as `DisplayStatusBadge._resolve` — reused here for
  /// the card's left edge accent, not a new status vocabulary.
  Color _statusColor(AppColors colors) {
    return switch (deriveDisplayStatus(feature.status)) {
      DisplayStatus.building => colors.cyan,
      DisplayStatus.planning => const Color(0xFFE0A020),
      DisplayStatus.done => const Color(0xFF22C55E),
      DisplayStatus.research => colors.fuch,
      DisplayStatus.paused => const Color(0xFFF59E0B),
      DisplayStatus.archived => colors.textDis,
      null => colors.textDis,
    };
  }

  String? _timeframeLabel() {
    final start = feature.start;
    final end = feature.finished ?? feature.target;
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      return '${_formatDate(start)} – ${_formatDate(end)}';
    }
    return _formatDate((start ?? end)!);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(colors);
    final timeframe = _timeframeLabel();

    final card = GlassCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('feature_card_status_edge'),
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      feature.name,
                      style: TextStyle(
                        color: colors.textPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timeframe != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 12,
                            color: colors.textDim,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeframe,
                            style: TextStyle(
                              color: colors.textDim,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (feature.dependsOn.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final dep in feature.dependsOn)
                            _DependencyChip(label: dep, colors: colors),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _DependencyChip extends StatelessWidget {
  const _DependencyChip({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: colors.textSec, fontSize: 10)),
    );
  }
}
