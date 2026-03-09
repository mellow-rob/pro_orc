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
}
