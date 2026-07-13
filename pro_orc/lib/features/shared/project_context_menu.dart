import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/delete_project_dialog.dart';
import 'package:pro_orc/features/shared/group_assignment_menu.dart';
import 'package:pro_orc/features/shared/rename_project_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

/// Shows the shared project context menu on right-click (or the card's
/// visible "..." button, per UX Variant 2 discoverability).
///
/// [moveTarget] is the project type to flip to (e.g. `ProjectType.research`
/// for code cards, `ProjectType.code` for research cards) — this entry used
/// to imply a tab jump ("Verschieben nach Code/Research"); since the type is
/// now a badge rather than a tab (FR-020), it is relabeled "Als Code/Research
/// markieren" but the underlying `ProjectType` flip is unchanged.
void showProjectContextMenu({
  required BuildContext context,
  required TapUpDetails details,
  required bool isHidden,
  required WidgetRef ref,
  required ProjectModel project,
  required ProjectType moveTarget,
}) {
  final position = RelativeRect.fromLTRB(
    details.globalPosition.dx,
    details.globalPosition.dy,
    _overlaySize(context).width - details.globalPosition.dx,
    _overlaySize(context).height - details.globalPosition.dy,
  );
  _showAt(
    context: context,
    position: position,
    isHidden: isHidden,
    ref: ref,
    project: project,
    moveTarget: moveTarget,
  );
}

/// Same menu as [showProjectContextMenu], anchored to an arbitrary
/// [position] instead of a right-click's [TapUpDetails] — used by the
/// card's visible "..." button.
void showProjectContextMenuAt({
  required BuildContext context,
  required Offset position,
  required bool isHidden,
  required WidgetRef ref,
  required ProjectModel project,
  required ProjectType moveTarget,
}) {
  final overlaySize = _overlaySize(context);
  final rect = RelativeRect.fromLTRB(
    position.dx,
    position.dy,
    overlaySize.width - position.dx,
    overlaySize.height - position.dy,
  );
  _showAt(
    context: context,
    position: rect,
    isHidden: isHidden,
    ref: ref,
    project: project,
    moveTarget: moveTarget,
  );
}

Size _overlaySize(BuildContext context) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return overlay.size;
}

void _showAt({
  required BuildContext context,
  required RelativeRect position,
  required bool isHidden,
  required WidgetRef ref,
  required ProjectModel project,
  required ProjectType moveTarget,
}) {
  final moveLabel = switch (moveTarget) {
    ProjectType.code => 'Als Code markieren',
    ProjectType.research => 'Als Research markieren',
  };
  final hasGroup = ref.read(membershipProvider)[project.folderId] != null;

  showMenu<String>(
    context: context,
    position: position,
    items: [
      PopupMenuItem(
        value: 'toggle_hidden',
        child: Text(isHidden ? 'Oeffentlich' : 'Privat'),
      ),
      PopupMenuItem(value: 'move', child: Text(moveLabel)),
      const PopupMenuItem(value: 'assign_group', child: Text('Gruppe zuweisen')),
      if (hasGroup)
        const PopupMenuItem(
          value: 'unassign_group',
          child: Text('Aus Gruppe entfernen'),
        ),
      const PopupMenuItem(value: 'rename', child: Text('Umbenennen…')),
      const PopupMenuItem(value: 'ignore', child: Text('Ignorieren')),
      const PopupMenuItem(value: 'terminal', child: Text('Terminal')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'delete', child: Text('Projekt loeschen')),
    ],
  ).then((value) async {
    if (!context.mounted) return;
    switch (value) {
      case 'toggle_hidden':
        ref.read(hiddenProjectsProvider.notifier).toggle(project.folderId);
      case 'move':
        final db = ref.read(appDatabaseProvider);
        await db.upsertProjectSettings(
          ProjectSettingsTableCompanion(
            folderId: Value(project.folderId),
            projectType: Value(moveTarget.name),
          ),
        );
        ref.invalidate(projectsProvider);
      case 'assign_group':
        await showGroupAssignmentMenu(
          context: context,
          position: position,
          ref: ref,
          project: project,
        );
      case 'unassign_group':
        await ref.read(membershipProvider.notifier).unassign(project.folderId);
      case 'rename':
        if (context.mounted) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => RenameProjectDialog(project: project),
          );
        }
      case 'ignore':
        final db = ref.read(appDatabaseProvider);
        await db.addIgnorePattern(project.folderId);
        ref.invalidate(projectsProvider);
      case 'terminal':
        QuickActionsService().openInTerminal(project.path);
      case 'delete':
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
