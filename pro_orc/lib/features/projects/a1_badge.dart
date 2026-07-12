import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Small pill indicating a project is planned/tracked via `.a1/` (M6
/// roadmap/phase state). Renders nothing when the project has no a1 data —
/// mirrors [pro_orc.features.shared.memory_indicator.MemoryIndicator]'s
/// pattern of taking the raw model field and deciding visibility itself,
/// so callers (card, list row) don't duplicate the `isEmpty` check.
class A1Badge extends StatelessWidget {
  const A1Badge({super.key, required this.project});

  final ProjectModel project;

  bool get _isVisible => project.a1 != null && !project.a1!.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'a1',
        style: TextStyle(
          color: colors.cyan,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
