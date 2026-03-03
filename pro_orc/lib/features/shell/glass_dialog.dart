import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Shared glassmorphism dialog shell with backdrop blur.
///
/// Wraps child content in the standard dialog chrome:
/// transparent Dialog → ConstrainedBox → ClipRRect(14) →
/// BackdropFilter(sigma 20) → Container(bgSurf, padding 24).
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            blendMode: BlendMode.src,
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: colors.bgSurf,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
