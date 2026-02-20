import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Reusable glassmorphism card widget with BackdropFilter blur.
///
/// Uses [BlendMode.src] to mitigate the white halo artifact that appears
/// on dark backgrounds with standard BackdropFilter.
///
/// No border is rendered (locked decision). All alpha values use
/// `withValues(alpha:)` — `withOpacity` is deprecated.
///
/// Access colors via [AppColors] ThemeExtension.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.blurSigma = 12.0,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        blendMode: BlendMode.src,
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: colors.bgCard.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}
