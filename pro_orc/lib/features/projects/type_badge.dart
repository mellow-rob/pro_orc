import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Pill badge rendered top-left on project cards/rows to distinguish Code
/// vs Research projects in the merged Projekte tab.
///
/// The label text is mandatory (not color-only) per FR-020 accessibility
/// requirements — color alone must never be the sole differentiator.
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final ProjectType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = switch (type) {
      ProjectType.code => colors.cyan,
      ProjectType.research => colors.fuch,
    };
    final label = switch (type) {
      ProjectType.code => 'Code',
      ProjectType.research => 'Research',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
