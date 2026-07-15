import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard_data.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// Hero section of the Vision tab (mockup `#vision .hero`, FR-004): eyebrow,
/// serif headline, lede, and a verdict pill summarizing live milestone
/// status.
class VisionHero extends StatelessWidget {
  const VisionHero({
    super.key,
    required this.vision,
    required this.projectName,
    required this.scorecard,
    required this.totalMilestones,
    required this.colors,
  });

  final VisionData vision;
  final String projectName;
  final VisionScorecardData scorecard;
  final int totalMilestones;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final headline = vision.title ?? projectName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRODUKTVISION · ROADMAP · STATUS',
          style: N3Typography.eyebrow(colors: colors),
        ),
        const SizedBox(height: 14),
        Text(
          headline,
          style: N3Typography.display(colors: colors, fontSize: 34),
        ),
        const SizedBox(height: 18),
        Text(
          vision.lead,
          style: TextStyle(color: colors.textSec, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 22),
        _VerdictPill(
          scorecard: scorecard,
          totalMilestones: totalMilestones,
          colors: colors,
        ),
      ],
    );
  }
}

/// The pill-shaped verdict badge: a green dot + a sentence derived from live
/// milestone counts, e.g. "Projekt aktiv — 8 von 9 Meilensteinen
/// abgeschlossen" (mockup `.verdict`).
class _VerdictPill extends StatelessWidget {
  const _VerdictPill({
    required this.scorecard,
    required this.totalMilestones,
    required this.colors,
  });

  final VisionScorecardData scorecard;
  final int totalMilestones;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final label = totalMilestones == 0
        ? 'Projekt aktiv — noch keine Meilensteine erfasst'
        : 'Projekt aktiv — ${scorecard.milestonesDone} von '
              '$totalMilestones Meilensteinen abgeschlossen';

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 9, 20, 9),
      decoration: BoxDecoration(
        color: colors.bgCard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPri.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors.emerald,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.emerald.withValues(alpha: 0.15),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: colors.textPri,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
