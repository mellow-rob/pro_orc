import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Full-window shell with outer glow shadows and no border.
///
/// Uses [AppColors] tokens from the ThemeExtension for all color references.
/// No border is rendered (locked decision: no borders on cards/shells).
/// All alpha values use `withValues(alpha:)` — `withOpacity` is deprecated.
class GlowBorderShell extends StatelessWidget {
  const GlowBorderShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgBase,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colors.cyan.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: colors.fuch.withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
    );
  }
}
