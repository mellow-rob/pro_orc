import 'package:flutter/material.dart';
import 'package:pro_orc/features/shared/roadmap/structured_spec_renderer.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Opens [StructuredSpecRenderer] for a feature's spec/plan paths in a
/// glassmorphism dialog (FR-017), following the same
/// `showGeneralDialog` + slide/fade transition pattern as
/// `claude_tool_detail_panel.dart`'s detail dialogs.
Future<void> showStructuredSpecRenderer(
  BuildContext context, {
  required String? specPath,
  required String? planPath,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      final colors = Theme.of(context).extension<AppColors>()!;
      return GlassDialog(
        maxWidth: 720,
        child: SizedBox(
          height: 560,
          child: StructuredSpecRenderer(
            specPath: specPath,
            planPath: planPath,
            colors: colors,
          ),
        ),
      );
    },
  );
}
