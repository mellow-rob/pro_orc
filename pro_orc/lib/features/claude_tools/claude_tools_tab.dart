import 'package:flutter/material.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Empty Claude Tools tab placeholder with GlassCard.
class ClaudeToolsTab extends StatelessWidget {
  const ClaudeToolsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Center(
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Claude Tools',
            style: TextStyle(color: colors.textPri, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
