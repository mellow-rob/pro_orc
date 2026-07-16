import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_id_chip.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Compact feature row for the Roadmap milestone-accordion body (FR-003,
/// mockup v2 `#roadmap .f-row`): a small status dot, a mono id, the feature
/// title, and a small status tag — NOT a card. Replaces the Wave 4
/// `FeatureCard` grid-of-cards drill-down, which mockup v2 rejected as too
/// large/cluttered for an expanded accordion body.
///
/// When [onTap] is provided, tapping the row opens the structured spec/plan
/// renderer for this feature (same dialog contract as before). Optional so
/// existing call sites/tests that only render the row visually keep working
/// unchanged.
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

  /// Same color mapping as `MilestoneLane.statusDotColor` — reused here for
  /// the row's status dot, not a new status vocabulary.
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

  /// Mockup `.ftag` label (`Fertig`/`Aktiv`/…) — reuses the existing status
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(colors);
    final idChip = extractRoadmapIdChip(feature.name);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            key: const Key('feature_card_status_edge'),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          if (idChip != null) ...[
            Text(
              idChip,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: colors.textDim,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              feature.name,
              style: TextStyle(color: colors.textPri, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _StatusTag(label: _tagLabel(), color: statusColor),
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      ),
    );
  }
}

/// Mockup `.ftag` — small status pill trailing the feature row.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}
