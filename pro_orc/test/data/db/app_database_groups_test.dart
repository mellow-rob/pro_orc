import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';

void main() {
  group('AppDatabase project groups', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Archiv system group exists from first access', () async {
      final groups = await db.getGroups();
      final archiv = groups.where((g) => g.id == kArchiveGroupId);
      expect(archiv.length, equals(1));
      expect(archiv.single.name, equals('Archiv'));
      expect(archiv.single.isSystem, isTrue);
    });

    test(
      'createGroup returns a generated id distinct from the Archiv sentinel',
      () async {
        final id = await db.createGroup('Vodafone');
        expect(id, isNot(equals(kArchiveGroupId)));

        final groups = await db.getGroups();
        final created = groups.where((g) => g.id == id);
        expect(created.length, equals(1));
        expect(created.single.name, equals('Vodafone'));
        expect(created.single.isSystem, isFalse);
      },
    );

    test('createGroup generates distinct ids for distinct calls', () async {
      final idA = await db.createGroup('A');
      final idB = await db.createGroup('B');
      expect(idA, isNot(equals(idB)));
    });

    test(
      'renameGroup updates the name but keeps the id (round-trips)',
      () async {
        final id = await db.createGroup('Launch Partners');
        await db.renameGroup(id, 'Renamed Partners');

        final groups = await db.getGroups();
        final renamed = groups.where((g) => g.id == id);
        expect(renamed.single.name, equals('Renamed Partners'));
      },
    );

    test(
      'deleteGroup removes the group and nulls out member groupId',
      () async {
        final id = await db.createGroup('Kundenprojekte');
        await db.setProjectGroup('wtv', id);
        await db.setProjectGroup('vf-tk-deck', id);

        await db.deleteGroup(id);

        final groups = await db.getGroups();
        expect(groups.where((g) => g.id == id), isEmpty);

        expect(await db.getProjectGroupId('wtv'), isNull);
        expect(await db.getProjectGroupId('vf-tk-deck'), isNull);
      },
    );

    test('setProjectGroup replaces prior membership (1:1)', () async {
      final groupA = await db.createGroup('Group A');
      final groupB = await db.createGroup('Group B');

      await db.setProjectGroup('wtv', groupA);
      expect(await db.getProjectGroupId('wtv'), equals(groupA));

      await db.setProjectGroup('wtv', groupB);
      expect(await db.getProjectGroupId('wtv'), equals(groupB));
    });

    test(
      'setProjectGroup(folderId, null) clears membership ("Ohne Gruppe")',
      () async {
        final groupA = await db.createGroup('Group A');
        await db.setProjectGroup('wtv', groupA);

        await db.setProjectGroup('wtv', null);
        expect(await db.getProjectGroupId('wtv'), isNull);
      },
    );

    test(
      'getProjectGroupId returns null for a project with no settings row',
      () async {
        expect(await db.getProjectGroupId('never-seen'), isNull);
      },
    );

    test('Archiv collapse state defaults to true', () async {
      expect(await db.getCollapseState(kArchiveGroupId), isTrue);
    });

    test('user-created group collapse state defaults to false', () async {
      final id = await db.createGroup('Vodafone');
      expect(await db.getCollapseState(id), isFalse);
    });

    test('setCollapseState persists and round-trips', () async {
      final id = await db.createGroup('Vodafone');
      await db.setCollapseState(id, true);
      expect(await db.getCollapseState(id), isTrue);

      await db.setCollapseState(id, false);
      expect(await db.getCollapseState(id), isFalse);
    });

    test(
      'setCollapseState on Archiv overrides the default and round-trips',
      () async {
        await db.setCollapseState(kArchiveGroupId, false);
        expect(await db.getCollapseState(kArchiveGroupId), isFalse);
      },
    );

    test('ensureSystemGroups is idempotent across repeated calls', () async {
      await db.ensureSystemGroups();
      await db.ensureSystemGroups();

      final groups = await db.getGroups();
      expect(groups.where((g) => g.id == kArchiveGroupId).length, equals(1));
      expect(await db.getCollapseState(kArchiveGroupId), isTrue);
    });

    test(
      'ensureSystemGroups does not reset a manually expanded Archiv',
      () async {
        await db.setCollapseState(kArchiveGroupId, false);
        await db.ensureSystemGroups();
        expect(await db.getCollapseState(kArchiveGroupId), isFalse);
      },
    );

    test('getViewMode defaults to "grid" when never set', () async {
      expect(await db.getViewMode(), equals('grid'));
    });

    test('setViewMode persists and round-trips', () async {
      await db.setViewMode('list');
      expect(await db.getViewMode(), equals('list'));

      await db.setViewMode('grid');
      expect(await db.getViewMode(), equals('grid'));
    });

    test('isProjectOrganizationSeedApplied defaults to false', () async {
      expect(await db.isProjectOrganizationSeedApplied(), isFalse);
    });

    test(
      'markProjectOrganizationSeedApplied flips the flag and persists it',
      () async {
        await db.markProjectOrganizationSeedApplied();
        expect(await db.isProjectOrganizationSeedApplied(), isTrue);
      },
    );
  });

  group('AppDatabase v4→v5 migration', () {
    test('upgrades a v4 database without data loss', () async {
      final dir = await Directory.systemTemp.createTemp(
        'pro_orc_migration_test',
      );
      addTearDown(() => dir.delete(recursive: true));
      final dbFile = File(p.join(dir.path, 'test.sqlite'));

      // Build a real v4-shaped database on disk via raw SQL: the exact
      // schema pre-Wave-1 (schemaVersion 4, after the v2 isHidden/v3
      // themeMode/v4 vaultDir columns, no groups/view-mode/seed-flag/
      // collapse-state). `user_version` is what Drift reads as `from` when
      // it reopens this file — see onUpgrade's `if (from < 5)` block.
      final seedDb = NativeDatabase(dbFile);
      final rawSeed = DatabaseConnection(seedDb);
      await rawSeed.executor.ensureOpen(_NoopUser());
      await rawSeed.executor.runCustom('''
        CREATE TABLE app_config_table (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          scan_dir TEXT NOT NULL DEFAULT '',
          ignore_list_json TEXT NOT NULL DEFAULT '[".*","node_modules","build",".dart_tool"]',
          git_binary_path TEXT NOT NULL DEFAULT 'git',
          theme_mode TEXT NOT NULL DEFAULT 'dark',
          vault_dir TEXT NOT NULL DEFAULT ''
        );
      ''');
      await rawSeed.executor.runCustom('''
        CREATE TABLE project_settings_table (
          folder_id TEXT NOT NULL PRIMARY KEY,
          project_type TEXT NULL,
          display_name TEXT NULL,
          type_set_at INTEGER NULL,
          is_hidden INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await rawSeed.executor.runInsert(
        "INSERT INTO app_config_table (id, theme_mode) VALUES (1, 'light')",
        const [],
      );
      await rawSeed.executor.runInsert(
        "INSERT INTO project_settings_table (folder_id, is_hidden) VALUES ('wtv', 1)",
        const [],
      );
      await rawSeed.executor.runCustom('PRAGMA user_version = 4;');
      await seedDb.close();

      // Reopen the same file via the real v5 AppDatabase — Drift reads
      // `user_version` (4) and runs onUpgrade(from: 4, to: 5).
      final v5Db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(v5Db.close);

      // Pre-existing v4 data survived the migration untouched.
      final settings = await v5Db.getProjectSettings('wtv');
      expect(settings, isNotNull);
      expect(settings!.isHidden, isTrue);
      expect(await v5Db.getThemeMode(), equals('light'));

      // New v5 schema surface is present and usable.
      final groups = await v5Db.getGroups();
      expect(groups.where((g) => g.id == kArchiveGroupId), isNotEmpty);
      expect(await v5Db.getViewMode(), equals('grid'));
      expect(await v5Db.isProjectOrganizationSeedApplied(), isFalse);
      expect(await v5Db.getCollapseState(kArchiveGroupId), isTrue);

      final id = await v5Db.createGroup('Vodafone');
      await v5Db.setProjectGroup('wtv', id);
      expect(await v5Db.getProjectGroupId('wtv'), equals(id));

      // Pre-existing member survives alongside the new groupId column.
      final updatedSettings = await v5Db.getProjectSettings('wtv');
      expect(updatedSettings!.isHidden, isTrue);
    });
  });
}

class _NoopUser extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => 4;
}
