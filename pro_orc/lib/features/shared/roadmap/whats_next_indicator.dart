import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Compact "What's next" indicator for the Roadmap tab's detail hero
/// (FR-011).
///
/// Reuses `GsdData.currentPhase` (parsed by the existing `GsdParser` — `N of
/// N` / phase-heading extraction) verbatim; no new parser is introduced.
/// Renders nothing when the current phase can't be parsed, matching the
/// project's "hide gracefully, never show a raw error" convention.
class WhatsNextIndicator extends StatelessWidget {
  const WhatsNextIndicator({
    super.key,
    required this.currentPhase,
    required this.colors,
    required this.accent,
  });

  final String? currentPhase;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (currentPhase == null || currentPhase!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_forward_rounded, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            'Was kommt als naechstes: Phase $currentPhase',
            style: TextStyle(
              color: colors.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
