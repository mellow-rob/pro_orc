import 'package:flutter/material.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// "Nächster Schritt" glass banner for the tier-0 Roadmap path (FR-005,
/// mockup `#roadmap .nextstep`).
///
/// Renders a compact mono-eyebrow label + a single-sentence summary derived
/// from the source tier's `NEXT.md` content — NOT the raw Markdown dump this
/// widget rendered before Wave 2 (that verbose "Wo stehen wir" hero now
/// lives in the Vision tab instead, see `VisionHero`). Only the first
/// non-empty, non-heading line of `nextMdContent` is shown, matching the
/// mockup's single-sentence banner copy; an explicit German empty state
/// covers missing/blank content, matching the project's "hide gracefully,
/// never show a raw gap" convention (see `SpecList`'s "Keine Specs..."
/// precedent).
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

  /// Picks the first non-empty line that isn't a Markdown heading (`#`) —
  /// the mockup banner shows one sentence, not the full NEXT.md body.
  static String? _summarize(String content) {
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;
      return line;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content = nextMdContent?.trim();
    final summary = (content == null || content.isEmpty)
        ? null
        : _summarize(content);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 8,
          children: [
            Text(
              'NÄCHSTER SCHRITT',
              style: TextStyle(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: accent,
              ),
            ),
            Text(
              summary ?? 'Kein nächster Schritt hinterlegt',
              style: TextStyle(
                color: summary == null ? colors.textDim : colors.textSec,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
