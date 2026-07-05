import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Pulsing dot shown on a project card when at least one Claude Code session
/// is currently active (`SessionInfo.isActive`, i.e. its `.jsonl` was
/// modified within the last 5 minutes).
///
/// Read-only indicator — no interaction, purely informational ("something is
/// running here right now").
class SessionLiveIndicator extends StatefulWidget {
  const SessionLiveIndicator({super.key, required this.colors});

  final AppColors colors;

  @override
  State<SessionLiveIndicator> createState() => _SessionLiveIndicatorState();
}

class _SessionLiveIndicatorState extends State<SessionLiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Aktive Claude-Session',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = 0.35 + (_controller.value * 0.65);
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.colors.emerald.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.emerald.withValues(alpha: opacity * 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
