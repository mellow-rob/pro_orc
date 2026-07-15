import 'package:flutter/material.dart';

import 'package:pro_orc/features/shared/vision/vision_scorecard_data.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// Four glass stat tiles (mockup `.scorecard`, FR-004): milestones done
/// (emerald), milestones active (cyan), features total (violet), features
/// done (amber) — all computed from real `docs/product/` data, never
/// hardcoded.
class VisionScorecard extends StatelessWidget {
  const VisionScorecard({
    super.key,
    required this.data,
    required this.colors,
  });

  final VisionScorecardData data;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '${data.milestonesDone}',
            label: 'Meilensteine fertig',
            color: colors.emerald,
            colors: colors,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            value: '${data.milestonesActive}',
            label: 'Aktiv in Arbeit',
            color: colors.cyan,
            colors: colors,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            value: '${data.featuresTotal}',
            label: 'Features gesamt',
            color: colors.violet,
            colors: colors,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            value: '${data.featuresDone}',
            label: 'Features fertig',
            color: colors.amber,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.colors,
  });

  final String value;
  final String label;
  final Color color;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: N3Typography.display(
                colors: colors,
                fontSize: 38,
                color: color,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
