import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/app_config_table.dart';
import 'tables/project_settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [AppConfigTable, ProjectSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _connect());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(projectSettingsTable, projectSettingsTable.isHidden);
      }
    },
  );

  static QueryExecutor _connect() {
    return driftDatabase(
      name: 'pro_orc',
      native: DriftNativeOptions(
        databaseDirectory: () async =>
            (await getApplicationSupportDirectory()).path,
      ),
    );
  }

  /// Returns the single app config row (id=1), inserting defaults on first access.
  Future<AppConfigTableData> getConfig() async {
    final existing = await (select(appConfigTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();

    if (existing != null) return existing;

    await into(appConfigTable).insert(
      const AppConfigTableCompanion(),
    );

    return (select(appConfigTable)..where((t) => t.id.equals(1))).getSingle();
  }

  /// Updates app config fields on id=1 row.
  Future<void> updateConfig({
    String? scanDir,
    String? ignoreListJson,
    String? gitBinaryPath,
  }) async {
    await (update(appConfigTable)..where((t) => t.id.equals(1))).write(
      AppConfigTableCompanion(
        scanDir: scanDir != null ? Value(scanDir) : const Value.absent(),
        ignoreListJson: ignoreListJson != null
            ? Value(ignoreListJson)
            : const Value.absent(),
        gitBinaryPath: gitBinaryPath != null
            ? Value(gitBinaryPath)
            : const Value.absent(),
      ),
    );
  }

  /// Returns the set of folderIds marked as hidden.
  Future<Set<String>> getHiddenProjectIds() async {
    final rows = await (select(projectSettingsTable)
          ..where((t) => t.isHidden.equals(true)))
        .get();
    return rows.map((r) => r.folderId).toSet();
  }

  /// Returns project settings for a given folderId, or null if not found.
  Future<ProjectSettingsTableData?> getProjectSettings(
      String folderId) async {
    return (select(projectSettingsTable)
          ..where((t) => t.folderId.equals(folderId)))
        .getSingleOrNull();
  }

  /// Upserts project settings (insert or update on conflict).
  Future<void> upsertProjectSettings(
      ProjectSettingsTableCompanion companion) async {
    await into(projectSettingsTable).insertOnConflictUpdate(companion);
  }
}
