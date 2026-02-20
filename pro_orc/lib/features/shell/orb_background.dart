import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Animated atmospheric orb background widget.
///
/// Paints 3 drifting radial-gradient orbs (2 cyan, 1 fuchsia) on a
/// [CustomPainter] canvas. Each controller has a different period so
/// natural desync emerges without explicit phase offsets.
///
/// Intended to be used as [Positioned.fill] in a [Stack] behind a
/// transparent [Scaffold].
class OrbBackground extends StatefulWidget {
  const OrbBackground({super.key});

  @override
  State<OrbBackground> createState() => _OrbBackgroundState();
}

class _OrbBackgroundState extends State<OrbBackground>
    with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final AnimationController _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);

    _c2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 23),
    )..repeat(reverse: true);

    _c3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _OrbPainter(
          c1: _c1,
          c2: _c2,
          c3: _c3,
          colors: colors,
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.c1,
    required this.c2,
    required this.c3,
    required this.colors,
  }) : super(repaint: Listenable.merge([c1, c2, c3]));

  final Animation<double> c1;
  final Animation<double> c2;
  final Animation<double> c3;
  final AppColors colors;

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = size.shortestSide;

    // Orb 1 — Cyan, top-left drift
    _drawOrb(
      canvas: canvas,
      center: Offset(w * (0.15 + 0.20 * c1.value), h * (0.20 + 0.15 * c1.value)),
      radius: s * 0.35,
      color: colors.cyanOrb,
      opacity: 0.18,
    );

    // Orb 2 — Fuchsia, bottom-right drift
    _drawOrb(
      canvas: canvas,
      center: Offset(w * (0.70 + 0.18 * c2.value), h * (0.65 + 0.18 * c2.value)),
      radius: s * 0.40,
      color: colors.fuchOrb,
      opacity: 0.14,
    );

    // Orb 3 — Cyan, top-right, slower
    _drawOrb(
      canvas: canvas,
      center: Offset(w * (0.75 - 0.15 * c3.value), h * (0.15 + 0.12 * c3.value)),
      radius: s * 0.28,
      color: colors.cyanOrb,
      opacity: 0.10,
    );
  }

  void _drawOrb({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);
  }
}
