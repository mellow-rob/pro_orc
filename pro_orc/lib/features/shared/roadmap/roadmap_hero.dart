import 'package:flutter/material.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// "Wo stehen wir / Naechster Schritt" hero section for the tier-0 Roadmap
/// path (FR-012).
///
/// Surfaces the raw content of the source tier's `NEXT.md` as-is — no
/// Markdown parsing here (structured rendering is Wave 5's scope). Renders
/// an explicit German empty state when no content is available, matching
/// the project's "hide gracefully, never show a raw gap" convention (see
/// `SpecList`'s "Keine Specs..." precedent).
class RoadmapHero extends StatelessWidget {
  const RoadmapHero({
    super.key,
    required this.nextMdContent,
    required this.colors,
    required this.accent,
  });

  /// Raw `NEXT.md` content (`RoadmapData.nextMdContent`), or null/blank when
  /// the source tier does not supply one.
  final String? nextMdContent;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final content = nextMdContent?.trim();

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  'Wo stehen wir',
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (content == null || content.isEmpty)
              Text(
                'Kein naechster Schritt hinterlegt',
                style: TextStyle(color: colors.textDim, fontSize: 12),
              )
            else
              Text(
                content,
                style: TextStyle(
                  color: colors.textSec,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
