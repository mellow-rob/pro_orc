import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/group_name_validation.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

Future<ProviderContainer> _containerWithInMemoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // groupsProvider now awaits projectsProvider.future (F-007 fix) —
      // override with an empty resolved list so tests don't hit the real
      // ProjectScanner/filesystem via the default scan dir.
      projectsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  // Let ensureSystemGroups() (beforeOpen) settle before assertions.
  await db.getGroups();
  return container;
}

void main() {
  group('groupsProvider', () {
    test('build() loads groups from the DB, including Archiv', () async {
      final container = await _containerWithInMemoryDb();

      // Force build() to run and let its async _loadFromDb complete.
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.id == kArchiveGroupId), isTrue);
      expect(
        groups.firstWhere((g) => g.id == kArchiveGroupId).isSystem,
        isTrue,
      );
    });

    test('create() adds a new user group to state and DB', () async {
      final container = await _containerWithInMemoryDb();
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);

      final result = await container
          .read(groupsProvider.notifier)
          .create('Vodafone');

      expect(result, isA<GroupActionSuccess>());
      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.name == 'Vodafone' && !g.isSystem), isTrue);

      final db = container.read(appDatabaseProvider);
      final dbGroups = await db.getGroups();
      expect(dbGroups.any((g) => g.name == 'Vodafone'), isTrue);
    });

    test('create() rejects an empty/whitespace-only name', () async {
      final container = await _containerWithInMemoryDb();
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);

      final result = await container
          .read(groupsProvider.notifier)
          .create('   ');

      expect(result, isA<GroupActionNameRejected>());
      final rejected = result as GroupActionNameRejected;
      expect(rejected.validation, isA<GroupNameEmpty>());

      final db = container.read(appDatabaseProvider);
      final dbGroups = await db.getGroups();
      expect(dbGroups.length, equals(1)); // only Archiv
    });

    test(
      'create() rejects a duplicate name (case-insensitive, trimmed)',
      () async {
        final container = await _containerWithInMemoryDb();
        container.read(groupsProvider);
        await Future<void>.delayed(Duration.zero);

        await container.read(groupsProvider.notifier).create('Vodafone');
        final result = await container
            .read(groupsProvider.notifier)
            .create('  vodafone ');

        expect(result, isA<GroupActionNameRejected>());
        final rejected = result as GroupActionNameRejected;
        expect(rejected.validation, isA<GroupNameDuplicate>());
      },
    );

    test(
      'create() rejects "Archiv" in any casing/whitespace as reserved',
      () async {
        final container = await _containerWithInMemoryDb();
        container.read(groupsProvider);
        await Future<void>.delayed(Duration.zero);

        for (final candidate in ['Archiv', 'archiv', ' ARCHIV ', 'ArChIv']) {
          final result = await container
              .read(groupsProvider.notifier)
              .create(candidate);
          expect(
            result,
            isA<GroupActionNameRejected>(),
            reason: 'expected "$candidate" to be rejected',
          );
          final rejected = result as GroupActionNameRejected;
          expect(rejected.validation, isA<GroupNameDuplicate>());
        }
      },
    );

    test('rename() renames a user-created group', () async {
      final container = await _containerWithInMemoryDb();
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);

      final createResult = await container
          .read(groupsProvider.notifier)
          .create('Launch Partners');
      expect(createResult, isA<GroupActionSuccess>());
      final created = container
          .read(groupsProvider)
          .firstWhere((g) => g.name == 'Launch Partners');

      final result = await container
          .read(groupsProvider.notifier)
          .rename(created.id, 'Renamed Partners');

      expect(result, isA<GroupActionSuccess>());
      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.name == 'Renamed Partners'), isTrue);
      expect(groups.any((g) => g.name == 'Launch Partners'), isFalse);
    });

    test('rename() rejects a duplicate/reserved target name', () async {
      final container = await _containerWithInMemoryDb();
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);

      await container.read(groupsProvider.notifier).create('Vodafone');
      final createResult = await container
          .read(groupsProvider.notifier)
          .create('Neural AI Produkte');
      expect(createResult, isA<GroupActionSuccess>());
      final target = container
          .read(groupsProvider)
          .firstWhere((g) => g.name == 'Neural AI Produkte');

      final result = await container
          .read(groupsProvider.notifier)
          .rename(target.id, 'vodafone');

      expect(result, isA<GroupActionNameRejected>());
      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.name == 'Neural AI Produkte'), isTrue);
    });

    test(
      'rename() allows renaming a group to its own current name (no-op collision)',
      () async {
        final container = await _containerWithInMemoryDb();
        container.read(groupsProvider);
        await Future<void>.delayed(Duration.zero);

        await container.read(groupsProvider.notifier).create('Vodafone');
        final target = container
            .read(groupsProvider)
            .firstWhere((g) => g.name == 'Vodafone');

        final result = await container
            .read(groupsProvider.notifier)
            .rename(target.id, 'Vodafone');

        expect(result, isA<GroupActionSuccess>());
      },
    );

    test('rename() refuses to rename the Archiv system group', () async {
      final container = await _containerWithInMemoryDb();
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);

      final result = await container
          .read(groupsProvider.notifier)
          .rename(kArchiveGroupId, 'My Archive');

      expect(result, isA<GroupActionSystemGroupRejected>());
      final db = container.read(appDatabaseProvider);
      final groups = await db.getGroups();
      expect(
        groups.firstWhere((g) => g.id == kArchiveGroupId).name,
        equals('Archiv'),
      );
    });

    test(
      'dissolve() deletes a user-created group and ungroups its members',
      () async {
        final container = await _containerWithInMemoryDb();
        container.read(groupsProvider);
        await Future<void>.delayed(Duration.zero);

        final createResult = await container
            .read(groupsProvider.notifier)
            .create('Kundenprojekte');
        expect(createResult, isA<GroupActionSuccess>());
        final group = container
            .read(groupsProvider)
            .firstWhere((g) => g.name == 'Kundenprojekte');

        await container
            .read(membershipProvider.notifier)
            .assign('wtv', group.id);
        await container
            .read(membershipProvider.notifier)
            .assign('vf-tk-deck', group.id);

        final result = await container
            .read(groupsProvider.notifier)
            .dissolve(group.id);

        expect(result, isA<GroupActionSuccess>());
        final groups = container.read(groupsProvider);
        expect(groups.any((g) => g.id == group.id), isFalse);

        final db = container.read(appDatabaseProvider);
        expect(await db.getProjectGroupId('wtv'), isNull);
        expect(await db.getProjectGroupId('vf-tk-deck'), isNull);

        final membership = container.read(membershipProvider);
        expect(membership['wtv'], isNull);
        expect(membership['vf-tk-deck'], isNull);
      },
    );

    test('dissolve() refuses to dissolve the Archiv system group', () async {
      final container = await _containerWithInMemoryDb();
      container.read(groupsProvider);
      await Future<void>.delayed(Duration.zero);

      final result = await container
          .read(groupsProvider.notifier)
          .dissolve(kArchiveGroupId);

      expect(result, isA<GroupActionSystemGroupRejected>());
      final db = container.read(appDatabaseProvider);
      final groups = await db.getGroups();
      expect(groups.any((g) => g.id == kArchiveGroupId), isTrue);
    });
  });
}
