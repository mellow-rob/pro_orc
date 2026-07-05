import 'dart:convert';
import 'dart:io';

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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(projectSettingsTable, projectSettingsTable.isHidden);
      }
      if (from < 3) {
        await m.addColumn(appConfigTable, appConfigTable.themeMode);
      }
      if (from < 4) {
        await m.addColumn(appConfigTable, appConfigTable.vaultDir);
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

  /// Default scan directory: ~/project_orchestration
  static String get _defaultScanDir {
    final home = Platform.environment['HOME']!;
    return '$home/project_orchestration';
  }

  /// Returns the single app config row (id=1), inserting defaults on first access.
  /// If scanDir is empty, auto-populates with ~/project_orchestration.
  Future<AppConfigTableData> getConfig() async {
    final existing = await (select(appConfigTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();

    if (existing != null) {
      // Auto-populate empty scanDir with default
      if (existing.scanDir.isEmpty) {
        await updateConfig(scanDir: _defaultScanDir);
        return existing.copyWith(scanDir: _defaultScanDir);
      }
      return existing;
    }

    await into(appConfigTable).insert(
      AppConfigTableCompanion(
        scanDir: Value(_defaultScanDir),
      ),
    );

    return (select(appConfigTable)..where((t) => t.id.equals(1))).getSingle();
  }

  /// Returns the list of scan directories from scanDir field.
  /// Supports both legacy single-path strings and JSON arrays.
  Future<List<String>> getScanDirs() async {
    final config = await getConfig();
    final raw = config.scanDir;
    if (raw.isEmpty) return [_defaultScanDir];

    // Try JSON array first
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final dirs = decoded.whereType<String>().where((s) => s.isNotEmpty).toList();
          return dirs.isEmpty ? [_defaultScanDir] : dirs;
        }
      } catch (_) {
        // Fall through to single path
      }
    }

    // Legacy single path
    return [raw];
  }

  /// Saves the list of scan directories as a JSON array.
  Future<void> setScanDirs(List<String> dirs) async {
    await updateConfig(scanDir: jsonEncode(dirs));
  }

  /// Updates app config fields on id=1 row.
  Future<void> updateConfig({
    String? scanDir,
    String? ignoreListJson,
    String? gitBinaryPath,
    String? themeMode,
    String? vaultDir,
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
        themeMode: themeMode != null ? Value(themeMode) : const Value.absent(),
        vaultDir: vaultDir != null ? Value(vaultDir) : const Value.absent(),
      ),
    );
  }

  /// Returns the configured Obsidian vault path, or null when unset (empty).
  /// Null lets the [LearningReader] fall back to its `$HOME/N3URAL-Vault`
  /// default rather than baking a per-machine HOME into the DB.
  Future<String?> getVaultDir() async {
    final config = await getConfig();
    final trimmed = config.vaultDir.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Persists the Obsidian vault path. Pass null or an empty/whitespace string
  /// to clear the override (reader then uses its default).
  Future<void> setVaultDir(String? path) async {
    await getConfig(); // ensure id=1 row exists
    await updateConfig(vaultDir: path?.trim() ?? '');
  }

  /// Returns the persisted theme mode preference: 'light', 'dark', or
  /// 'system'. Defaults to 'dark' (via the column default) if never set.
  Future<String> getThemeMode() async {
    final config = await getConfig();
    return config.themeMode;
  }

  /// Persists the theme mode preference. [mode] must be one of 'light',
  /// 'dark', 'system'.
  Future<void> setThemeMode(String mode) async {
    // Ensure the id=1 config row exists before updating it — updateConfig
    // is a no-op if the row hasn't been created yet (first-ever DB access).
    await getConfig();
    await updateConfig(themeMode: mode);
  }

  /// Adds a pattern to the ignore list (if not already present).
  Future<void> addIgnorePattern(String pattern) async {
    final config = await getConfig();
    List<String> patterns = [];
    try {
      final decoded = jsonDecode(config.ignoreListJson);
      if (decoded is List) {
        patterns = decoded.whereType<String>().toList();
      }
    } catch (_) {}
    if (!patterns.contains(pattern)) {
      patterns.add(pattern);
      await updateConfig(ignoreListJson: jsonEncode(patterns));
    }
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

  /// Sets a custom display name override for a project.
  ///
  /// Pass `null` or an empty/whitespace-only string to clear the override
  /// (the app will then fall back to PROJECT.md H1 or the folder name).
  Future<void> setProjectDisplayName(String folderId, String? name) async {
    final trimmed = name?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    await upsertProjectSettings(
      ProjectSettingsTableCompanion.insert(
        folderId: folderId,
        displayName: Value(value),
      ),
    );
  }
}
