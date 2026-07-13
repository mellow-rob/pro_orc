import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/providers/database_provider.dart';

/// Per-group collapse state, keyed by groupId (FR-018). "Archiv" defaults
/// to collapsed (seeded by Wave 1's `ensureSystemGroups`); user-created
/// groups default to expanded.
class GroupCollapseNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    _loadFromDb();
    return const {};
  }

  Future<void> _loadFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final groups = await db.getGroups();
    final loaded = <String, bool>{};
    for (final group in groups) {
      loaded[group.id] = await db.getCollapseState(group.id);
    }
    state = loaded;
  }

  /// Toggles [groupId]'s collapse state (defaulting the current value to
  /// `false`/expanded if not yet tracked) and persists the result.
  Future<void> toggle(String groupId) async {
    final next = !(state[groupId] ?? false);
    final db = ref.read(appDatabaseProvider);
    await db.setCollapseState(groupId, next);
    state = {...state, groupId: next};
  }
}

final groupCollapseProvider =
    NotifierProvider<GroupCollapseNotifier, Map<String, bool>>(
      GroupCollapseNotifier.new,
    );
