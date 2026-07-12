import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/providers/database_provider.dart';

/// Per-project group membership: `folderId -> groupId` (`null` = "Ohne
/// Gruppe"). Membership is strictly 1:1 — [assign] replaces any previous
/// group for that project (enforced by `AppDatabase.setProjectGroup`, a
/// single-column write, not a junction table).
///
/// The state only ever contains folderIds this notifier has been asked
/// about (via [ensureLoaded], [assign], or [unassign]) — it does not
/// preload every project in the scan, mirroring [HiddenProjectsNotifier]'s
/// lazy-on-mutation style but adding an explicit load hook for the read
/// side, since membership (unlike hidden-state) is per-project rather than
/// a single set loaded once.
class ProjectGroupMembershipNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() {
    return const {};
  }

  /// Loads (or re-loads) [folderId]'s current groupId from the DB into
  /// state. Safe to call repeatedly.
  Future<void> ensureLoaded(String folderId) async {
    final db = ref.read(appDatabaseProvider);
    final groupId = await db.getProjectGroupId(folderId);
    state = {...state, folderId: groupId};
  }

  /// Re-reads every folderId currently tracked in state from the DB. Used
  /// after a group dissolve (Wave 1's `deleteGroup` nulls out members'
  /// `groupId` directly in the DB) so any tracked project that belonged to
  /// the dissolved group reflects "Ohne Gruppe" immediately.
  Future<void> refreshFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final updated = <String, String?>{};
    for (final folderId in state.keys) {
      updated[folderId] = await db.getProjectGroupId(folderId);
    }
    state = updated;
  }

  /// Assigns [folderId] to [groupId] (1:1 — replaces any prior group).
  /// Passing the Archiv sentinel id is not a special case: it is just
  /// another group id.
  Future<void> assign(String folderId, String groupId) async {
    final db = ref.read(appDatabaseProvider);
    await db.setProjectGroup(folderId, groupId);
    state = {...state, folderId: groupId};
  }

  /// Unassigns [folderId] back to "Ohne Gruppe" (`groupId = null`).
  Future<void> unassign(String folderId) async {
    final db = ref.read(appDatabaseProvider);
    await db.setProjectGroup(folderId, null);
    state = {...state, folderId: null};
  }
}

final membershipProvider =
    NotifierProvider<ProjectGroupMembershipNotifier, Map<String, String?>>(
      ProjectGroupMembershipNotifier.new,
    );
