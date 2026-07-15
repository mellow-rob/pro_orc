import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_id_chip.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Feature card for the tier-0 Roadmap drill-down (FR-016/FR-005): shown for
/// each feature ([RoadmapPhase]) of a selected milestone, matching mockup
/// `#roadmap .fcard`.
///
/// 4px status-colored left edge, a top row with a status tag (mockup
/// `.tag`) and a mono id (mockup `.fid`), a bold title, and a row of mono
/// chips (mockup `.chips span`) carrying the timeframe and dependencies —
/// the mockup's own chip content (date range, spec number) is illustrative;
/// this project's [RoadmapPhase] model does not carry a spec number, so the
/// timeframe and `dependsOn` entries fill the chip row instead.
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
      DisplayStatus.done => colors.emerald,
      DisplayStatus.research => colors.fuch,
      DisplayStatus.paused => const Color(0xFFF59E0B),
      DisplayStatus.archived => colors.textDis,
      null => colors.textDis,
    };
  }

  /// Mockup `.tag` label (`Fertig`/`Aktiv`/…) — reuses the existing status
  /// vocabulary, never a new word set (FR-003 precedent).
  String _tagLabel() {
    return switch (deriveDisplayStatus(feature.status)) {
      DisplayStatus.done => 'Fertig',
      DisplayStatus.building => 'Aktiv',
      DisplayStatus.planning => 'Geplant',
      DisplayStatus.paused => 'Pausiert',
      DisplayStatus.research => 'Recherche',
      DisplayStatus.archived => 'Archiviert',
      null => 'Unbekannt',
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
    final idChip = extractRoadmapIdChip(feature.name);

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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _StatusTag(
                          label: _tagLabel(),
                          color: statusColor,
                          colors: colors,
                        ),
                        if (idChip != null)
                          Text(
                            idChip,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: colors.textDim,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature.name,
                      style: TextStyle(
                        color: colors.textPri,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (timeframe != null || feature.dependsOn.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (timeframe != null)
                            _MonoChip(label: timeframe, colors: colors),
                          for (final dep in feature.dependsOn)
                            _MonoChip(label: dep, colors: colors),
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

/// Mockup `.tag` — status pill above the title (e.g. "Fertig"/"Aktiv").
class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.label,
    required this.color,
    required this.colors,
  });

  final String label;
  final Color color;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

/// Mockup `.chips span` — mono metadata chip (timeframe, dependency name).
class _MonoChip extends StatelessWidget {
  const _MonoChip({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colors.textPri.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: colors.textDim,
        ),
      ),
    );
  }
}
