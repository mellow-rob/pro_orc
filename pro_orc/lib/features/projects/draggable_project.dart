import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Wraps a project card/row in a plain `Draggable<String>` carrying the
/// project's `folderId` as payload (KERNENTSCHEIDUNG 4 — a desktop app has no
/// need for `LongPressDraggable`; a plain `Draggable` is the natural choice
/// and keeps the drag gesture instant).
///
/// The drag feedback is a lightweight, semi-transparent ghost of [child]
/// rather than the full interactive widget, to avoid jank while dragging.
class DraggableProject extends StatelessWidget {
  const DraggableProject({
    super.key,
    required this.folderId,
    required this.child,
  });

  final String folderId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Draggable<String>(
      data: folderId,
      feedback: Opacity(
        opacity: 0.85,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 280,
            height: 240,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.cyan.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: child,
    );
  }
}
