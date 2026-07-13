import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/group_name_validation.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

/// Result of a group-mutating action that can be refused for reasons the UI
/// (Wave 4) needs to distinguish: a name-validation failure, or an attempt
/// to rename/dissolve the system-owned "Archiv" group.
sealed class GroupActionResult {
  const GroupActionResult();
}

class GroupActionSuccess extends GroupActionResult {
  const GroupActionSuccess();
}

class GroupActionNameRejected extends GroupActionResult {
  final GroupNameValidation validation;

  const GroupActionNameRejected(this.validation);
}

/// Attempted to rename/dissolve a system-owned group (e.g. "Archiv").
class GroupActionSystemGroupRejected extends GroupActionResult {
  const GroupActionSystemGroupRejected();
}

/// Group not found in current state (defensive — should not normally occur).
class GroupActionNotFound extends GroupActionResult {
  const GroupActionNotFound();
}

class GroupsNotifier extends Notifier<List<ProjectGroup>> {
  @override
  List<ProjectGroup> build() {
    _loadFromDb();
    return const [];
  }

  Future<void> _loadFromDb() async {
    // Wait for projectsProvider's first resolution before reading groups —
    // it performs the one-time organization seed (F-014/015/016) and only
    // then can this read see the seeded "Vodafone"/"Neural AI
    // Produkte"/"Kundenprojekte" groups. Without this await, a first-launch
    // UI that reads groupsProvider before projectsProvider settles would see
    // an empty list even though the seed completes moments later (F-007).
    await ref.watch(projectsProvider.future);
    final db = ref.read(appDatabaseProvider);
    final rows = await db.getGroups();
    state = rows.map(_fromRow).toList();
  }

  ProjectGroup _fromRow(ProjectGroupsTableData row) {
    return ProjectGroup(id: row.id, name: row.name, isSystem: row.isSystem);
  }

  Future<GroupActionResult> create(String name) async {
    final validation = validateGroupName(name, state.map((g) => g.name));
    if (validation is! GroupNameValid) {
      return GroupActionNameRejected(validation);
    }

    final db = ref.read(appDatabaseProvider);
    final id = await db.createGroup(validation.trimmedName);
    state = [
      ...state,
      ProjectGroup(id: id, name: validation.trimmedName, isSystem: false),
    ];
    return const GroupActionSuccess();
  }

  Future<GroupActionResult> rename(String id, String name) async {
    final target = state.where((g) => g.id == id).firstOrNull;
    if (target == null) return const GroupActionNotFound();
    if (target.isSystem) return const GroupActionSystemGroupRejected();

    final validation = validateGroupName(
      name,
      state.map((g) => g.name),
      excludeName: target.name,
    );
    if (validation is! GroupNameValid) {
      return GroupActionNameRejected(validation);
    }

    final db = ref.read(appDatabaseProvider);
    await db.renameGroup(id, validation.trimmedName);
    state = [
      for (final group in state)
        if (group.id == id)
          group.copyWith(name: validation.trimmedName)
        else
          group,
    ];
    return const GroupActionSuccess();
  }

  Future<GroupActionResult> dissolve(String id) async {
    final target = state.where((g) => g.id == id).firstOrNull;
    if (target == null) return const GroupActionNotFound();
    if (target.isSystem) return const GroupActionSystemGroupRejected();

    final db = ref.read(appDatabaseProvider);
    await db.deleteGroup(id);
    state = state.where((g) => g.id != id).toList();

    // Dissolve resets member groupId to null in the DB (Wave 1's
    // deleteGroup) — refresh membership state so the UI reflects the
    // ungrouping immediately (FR-005).
    await ref.read(membershipProvider.notifier).refreshFromDb();

    return const GroupActionSuccess();
  }
}

final groupsProvider = NotifierProvider<GroupsNotifier, List<ProjectGroup>>(
  GroupsNotifier.new,
);
