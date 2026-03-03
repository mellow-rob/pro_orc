import 'package:flutter/material.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Pinned banner at the bottom of a tab showing count of hidden/private projects.
///
/// Tap toggles between expanded (showing hidden cards) and collapsed.
class HiddenProjectsBanner extends StatelessWidget {
  const HiddenProjectsBanner({
    super.key,
    required this.hiddenCount,
    required this.isExpanded,
    required this.onToggle,
    required this.accentColor,
  });

  final int hiddenCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: onToggle,
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  color: colors.textDim,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '$hiddenCount private ${hiddenCount == 1 ? 'Projekt' : 'Projekte'}',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  isExpanded ? 'Verbergen' : 'Anzeigen',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: accentColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
