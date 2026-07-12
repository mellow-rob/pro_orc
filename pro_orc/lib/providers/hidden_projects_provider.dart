import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/providers/database_provider.dart';

class HiddenProjectsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFromDb();
    return {};
  }

  Future<void> _loadFromDb() async {
    final db = ref.read(appDatabaseProvider);
    final hidden = await db.getHiddenProjectIds();
    state = hidden;
  }

  Future<void> toggle(String folderId) async {
    final db = ref.read(appDatabaseProvider);
    final nowHidden = !state.contains(folderId);
    await db.upsertProjectSettings(
      ProjectSettingsTableCompanion(
        folderId: Value(folderId),
        isHidden: Value(nowHidden),
      ),
    );
    state = nowHidden
        ? {...state, folderId}
        : state.where((id) => id != folderId).toSet();
  }
}

final hiddenProjectsProvider =
    NotifierProvider<HiddenProjectsNotifier, Set<String>>(
      HiddenProjectsNotifier.new,
    );
