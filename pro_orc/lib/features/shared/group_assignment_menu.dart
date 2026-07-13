import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/projects/create_group_dialog.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';

/// Second-level menu for "Gruppe zuweisen" (FR-008/009): lists every group
/// including "Archiv", plus "Neue Gruppe...". Selecting a group assigns
/// [project] to it (1:1 — replaces any prior group via
/// [ProjectGroupMembershipNotifier.assign]). Selecting "Neue Gruppe..."
/// opens [CreateGroupDialog] and assigns the project to the newly created
/// group in one step (FR-009).
///
/// Reuses the parent context-menu's anchor [position] rather than the
/// original click point, since this menu opens after the first one closes.
Future<void> showGroupAssignmentMenu({
  required BuildContext context,
  required RelativeRect position,
  required WidgetRef ref,
  required ProjectModel project,
}) async {
  final groups = ref.read(groupsProvider);
  final sorted = [...groups]..sort((a, b) {
    if (a.isSystem != b.isSystem) return a.isSystem ? 1 : -1;
    return a.name.compareTo(b.name);
  });

  final value = await showMenu<String>(
    context: context,
    position: position,
    items: [
      for (final group in sorted)
        PopupMenuItem(value: group.id, child: Text(group.name)),
      const PopupMenuDivider(),
      const PopupMenuItem(value: '__new__', child: Text('Neue Gruppe…')),
    ],
  );

  if (value == null || !context.mounted) return;

  if (value == '__new__') {
    final newGroupId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateGroupDialog(),
    );
    if (newGroupId != null) {
      await ref
          .read(membershipProvider.notifier)
          .assign(project.folderId, newGroupId);
    }
    return;
  }

  await ref.read(membershipProvider.notifier).assign(project.folderId, value);
}

/// Re-exported for callers that need to render the group list without
/// opening the menu (e.g. tests asserting item order).
List<ProjectGroup> sortedGroupsForAssignment(List<ProjectGroup> groups) {
  final sorted = [...groups]..sort((a, b) {
    if (a.isSystem != b.isSystem) return a.isSystem ? 1 : -1;
    return a.name.compareTo(b.name);
  });
  return sorted;
}
