import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard_data.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Compact, clickable vision teaser card for the Übersicht tab (FR-002,
/// mockup v2 `#uebersicht .vision-teaser`): the vision lead sentence (max 2
/// lines, ellipsis), a row of the same 4 real counts the Vision tab's
/// scorecard shows, and a trailing "Vision ansehen →" affordance. Tapping
/// anywhere on the card invokes [onTap] (the caller switches the detail
/// panel to the Vision tab).
///
/// Only ever built by [ProjectDetailPanel] when [visionProvider] resolves
/// non-null — there is no internal "no vision data" fallback here, mirroring
/// the Vision tab button's own gating (a project without `VISION.md` never
/// sees this card at all).
class VisionTeaserCard extends StatelessWidget {
  const VisionTeaserCard({
    super.key,
    required this.vision,
    required this.scorecard,
    required this.colors,
    required this.onTap,
  });

  final VisionData vision;
  final VisionScorecardData scorecard;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'VISION & ROADMAP',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.9,
                          color: colors.cyan,
                        ),
                      ),
                    ),
                    Text(
                      'Vision ansehen →',
                      style: TextStyle(
                        color: colors.cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  vision.lead,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 22,
                  runSpacing: 10,
                  children: [
                    _TeaserCount(
                      value: scorecard.milestonesDone,
                      label: 'Meilensteine fertig',
                      color: colors.emerald,
                      labelColor: colors.textSec,
                    ),
                    _TeaserCount(
                      value: scorecard.milestonesActive,
                      label: 'Meilensteine aktiv',
                      color: colors.cyan,
                      labelColor: colors.textSec,
                    ),
                    _TeaserCount(
                      value: scorecard.featuresTotal,
                      label: 'Features gesamt',
                      color: colors.violet,
                      labelColor: colors.textSec,
                    ),
                    _TeaserCount(
                      value: scorecard.featuresDone,
                      label: 'Features fertig',
                      color: colors.amber,
                      labelColor: colors.textSec,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mockup `.vt-count` — one number + label pair in the teaser's count row.
class _TeaserCount extends StatelessWidget {
  const _TeaserCount({
    required this.value,
    required this.label,
    required this.color,
    required this.labelColor,
  });

  final int value;
  final String label;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            height: 1,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
