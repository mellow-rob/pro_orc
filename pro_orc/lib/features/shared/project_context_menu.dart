import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/delete_project_dialog.dart';
import 'package:pro_orc/features/shared/rename_project_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

/// Shows the shared project context menu on right-click.
///
/// [moveTarget] is the project type to move to (e.g. `ProjectType.research` for
/// code cards, `ProjectType.code` for research cards).
void showProjectContextMenu({
  required BuildContext context,
  required TapUpDetails details,
  required bool isHidden,
  required WidgetRef ref,
  required ProjectModel project,
  required ProjectType moveTarget,
}) {
  final moveLabel = switch (moveTarget) {
    ProjectType.code => 'Verschieben nach Code',
    ProjectType.research => 'Verschieben nach Research',
  };
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      details.globalPosition.dx,
      details.globalPosition.dy,
      overlay.size.width - details.globalPosition.dx,
      overlay.size.height - details.globalPosition.dy,
    ),
    items: [
      PopupMenuItem(
        value: 'toggle_hidden',
        child: Text(isHidden ? 'Oeffentlich' : 'Privat'),
      ),
      PopupMenuItem(value: 'move', child: Text(moveLabel)),
      const PopupMenuItem(value: 'rename', child: Text('Umbenennen…')),
      const PopupMenuItem(value: 'ignore', child: Text('Ignorieren')),
      const PopupMenuItem(value: 'terminal', child: Text('Terminal')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'delete', child: Text('Projekt loeschen')),
    ],
  ).then((value) async {
    if (value == 'toggle_hidden') {
      ref.read(hiddenProjectsProvider.notifier).toggle(project.folderId);
    } else if (value == 'move') {
      final db = ref.read(appDatabaseProvider);
      await db.upsertProjectSettings(
        ProjectSettingsTableCompanion(
          folderId: Value(project.folderId),
          projectType: Value(moveTarget.name),
        ),
      );
      ref.invalidate(projectsProvider);
    } else if (value == 'rename') {
      if (context.mounted) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RenameProjectDialog(project: project),
        );
      }
    } else if (value == 'ignore') {
      final db = ref.read(appDatabaseProvider);
      await db.addIgnorePattern(project.folderId);
      ref.invalidate(projectsProvider);
    } else if (value == 'terminal') {
      QuickActionsService().openInTerminal(project.path);
    } else if (value == 'delete') {
      if (context.mounted) {
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DeleteProjectDialog(project: project),
        );
      }
    }
  });
}
