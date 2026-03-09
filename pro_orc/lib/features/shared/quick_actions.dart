import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Shared action definition for quick action buttons.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// Builds the standard quick action list for a project card.
List<QuickAction> buildProjectQuickActions(
  ProjectModel project,
  QuickActionsService qa,
) {
  return [
    QuickAction(
      icon: LucideIcons.folder100,
      tooltip: 'Finder',
      onPressed: () => qa.openInFinder(project.path),
    ),
    if (project.git?.githubUrl != null)
      QuickAction(
        icon: LucideIcons.externalLink100,
        tooltip: 'GitHub',
        onPressed: () => qa.openUrl(project.git!.githubUrl!),
      ),
    if (project.gsd?.notionUrl != null)
      QuickAction(
        icon: LucideIcons.fileText100,
        tooltip: 'Notion',
        onPressed: () => qa.openUrl(project.gsd!.notionUrl!),
      ),
    if (project.memory != null)
      QuickAction(
        icon: LucideIcons.moonStar100,
        tooltip: 'Claude Memory',
        onPressed: () => qa.openRemSleep(project.path),
      ),
  ];
}

/// Builds a row of compact icon-only quick action buttons (for cards).
Widget buildQuickActionRow(List<QuickAction> actions, AppColors colors) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: actions
        .map(
          (a) => SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 15,
              icon: Icon(a.icon, color: colors.textDim),
              tooltip: a.tooltip,
              splashRadius: 16,
              onPressed: a.onPressed,
            ),
          ),
        )
        .toList(),
  );
}
