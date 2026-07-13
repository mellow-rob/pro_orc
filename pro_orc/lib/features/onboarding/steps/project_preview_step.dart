import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Step 3: Preview of discovered projects.
///
/// Shows a read-only list of project names found in the selected
/// scan directories. No interaction needed — purely informational.
class ProjectPreviewStep extends StatelessWidget {
  const ProjectPreviewStep({
    super.key,
    required this.projectNames,
    required this.isScanning,
  });

  final List<String> projectNames;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(
          LucideIcons.rocket,
          size: 48,
          color: colors.cyan.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          'Gefundene Projekte',
          style: TextStyle(
            color: colors.textPri,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildContent(colors)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContent(AppColors colors) {
    if (isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: colors.cyan),
            const SizedBox(height: 12),
            Text(
              'Suche Projekte...',
              style: TextStyle(color: colors.textDim, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (projectNames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Keine Projekte gefunden. Du kannst spaeter Projekte importieren.',
            style: TextStyle(color: colors.textDim, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: projectNames.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.bgElev.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.folder,
                size: 14,
                color: colors.cyan.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projectNames[index],
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
