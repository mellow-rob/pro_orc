import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// The "Die Produktvision" section (mockup `#vision section .vision-grid`,
/// FR-004): a section head (eyebrow + serif H2 + description), then a
/// two-column grid — the vision lead as large serif prose with cyan-italic
/// accent spans on the left, the pillar glass cards on the right.
class VisionSection extends StatelessWidget {
  const VisionSection({super.key, required this.vision, required this.colors});

  final VisionData vision;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WOFÜR PRO ORC DA IST',
          style: N3Typography.eyebrow(colors: colors),
        ),
        const SizedBox(height: 8),
        Text(
          'Die Produktvision',
          style: N3Typography.display(colors: colors, fontSize: 30),
        ),
        const SizedBox(height: 12),
        Text(
          'Jede Roadmap-Entscheidung wird an diesem Versprechen gemessen — '
          'nicht an technischen Möglichkeiten.',
          style: TextStyle(color: colors.textSec, fontSize: 15),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            // Mockup grid-template-columns: 1.1fr .9fr — stack on narrow
            // widths instead of squeezing both columns unreadably thin.
            final isNarrow = constraints.maxWidth < 640;
            final lead = _VisionLeadProse(lead: vision.lead, colors: colors);
            final pillars = _PillarsColumn(
              pillars: vision.pillars,
              colors: colors,
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [lead, const SizedBox(height: 24), pillars],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: lead),
                const SizedBox(width: 36),
                Expanded(flex: 9, child: pillars),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Renders the vision lead as large serif prose, turning `**...**`
/// markdown-bold spans into cyan italic accent spans (mockup `.vision-lead
/// b { color: var(--cyan); font-style: italic; }`).
class _VisionLeadProse extends StatelessWidget {
  const _VisionLeadProse({required this.lead, required this.colors});

  final String lead;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final baseStyle = N3Typography.display(
      colors: colors,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ).copyWith(height: 1.4);

    return RichText(text: TextSpan(style: baseStyle, children: _spans()));
  }

  List<InlineSpan> _spans() {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var lastEnd = 0;

    for (final match in pattern.allMatches(lead)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: lead.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: colors.cyan,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < lead.length) {
      spans.add(TextSpan(text: lead.substring(lastEnd)));
    }
    return spans;
  }
}

class _PillarsColumn extends StatelessWidget {
  const _PillarsColumn({required this.pillars, required this.colors});

  final List<VisionPillar> pillars;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < pillars.length; i++) ...[
          if (i > 0) const SizedBox(height: 13),
          _PillarCard(pillar: pillars[i], colors: colors),
        ],
      ],
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.pillar, required this.colors});

  final VisionPillar pillar;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pillar.name,
              style: TextStyle(
                color: colors.textPri,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pillar.description,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
