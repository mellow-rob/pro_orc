import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Ghost GlassCard that invites the user to create a new project.
///
/// Appears as the last card in Code and Research tab grids. Uses a lower
/// background alpha (0.30) than standard GlassCard (0.55) to appear
/// visually lighter — "ghost" style. Hover raises alpha to 0.55, scales
/// slightly, and adds an accent-colored glow.
///
/// Parameters:
/// - [accentColor]: Cyan for Code tab, Fuchsia for Research tab.
/// - [onTap]: Fired when user clicks the card. Parent wires to dialog opening.
class AddProjectCard extends StatefulWidget {
  const AddProjectCard({
    super.key,
    required this.accentColor,
    required this.onTap,
  });

  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<AddProjectCard> createState() => _AddProjectCardState();
}

class _AddProjectCardState extends State<AddProjectCard> {
  bool _isHovered = false;

  static const double _borderRadius = 14.0;
  static const double _blurSigma = 12.0;
  static const Duration _animDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final bgAlpha = _isHovered ? 0.55 : 0.30;
    final shadow = _isHovered
        ? [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.20),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ]
        : <BoxShadow>[];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: _animDuration,
          child: AnimatedContainer(
            duration: _animDuration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_borderRadius),
              boxShadow: shadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_borderRadius),
              child: BackdropFilter(
                blendMode: BlendMode.src,
                filter: ImageFilter.blur(
                  sigmaX: _blurSigma,
                  sigmaY: _blurSigma,
                ),
                child: AnimatedContainer(
                  duration: _animDuration,
                  decoration: BoxDecoration(
                    color: colors.bgCard.withValues(alpha: bgAlpha),
                    borderRadius: BorderRadius.circular(_borderRadius),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: widget.accentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
