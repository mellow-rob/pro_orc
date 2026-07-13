import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

Future<ProviderContainer> _containerWithInMemoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // membershipProvider now awaits projectsProvider.future (F-007 fix) —
      // override with an empty resolved list so tests don't hit the real
      // ProjectScanner/filesystem via the default scan dir.
      projectsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  await db.getGroups();
  return container;
}

void main() {
  group('membershipProvider', () {
    test(
      'build() starts empty synchronously, before the DB load resolves',
      () async {
        final container = await _containerWithInMemoryDb();
        expect(container.read(membershipProvider), isEmpty);
      },
    );

    test(
      'build() eager-loads every persisted assignment from the DB',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final groupId = await db.createGroup('Kundenprojekte');
        await db.setProjectGroup('wtv', groupId);
        await db.setProjectGroup('vf-tk-deck', null);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            projectsProvider.overrideWith((ref) async => []),
          ],
        );
        addTearDown(container.dispose);

        // Force build() to run, then let the async _loadFromDb() resolve —
        // mirrors a fresh app start where membershipProvider must reflect
        // prior assignments without any per-folderId ensureLoaded() call.
        container.read(membershipProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final membership = container.read(membershipProvider);
        expect(membership['wtv'], equals(groupId));
        expect(membership.containsKey('vf-tk-deck'), isTrue);
        expect(membership['vf-tk-deck'], isNull);
      },
    );

    test('assign() writes to DB and updates state', () async {
      final container = await _containerWithInMemoryDb();
      final db = container.read(appDatabaseProvider);
      final groupId = await db.createGroup('Vodafone');

      await container.read(membershipProvider.notifier).assign('wtv', groupId);

      expect(container.read(membershipProvider)['wtv'], equals(groupId));
      expect(await db.getProjectGroupId('wtv'), equals(groupId));
    });

    test('assign() replaces a prior group (1:1 membership)', () async {
      final container = await _containerWithInMemoryDb();
      final db = container.read(appDatabaseProvider);
      final groupA = await db.createGroup('Group A');
      final groupB = await db.createGroup('Group B');

      await container.read(membershipProvider.notifier).assign('wtv', groupA);
      await container.read(membershipProvider.notifier).assign('wtv', groupB);

      expect(container.read(membershipProvider)['wtv'], equals(groupB));
      expect(await db.getProjectGroupId('wtv'), equals(groupB));
    });

    test('assign() to Archiv is not a special case', () async {
      final container = await _containerWithInMemoryDb();
      final db = container.read(appDatabaseProvider);

      await container
          .read(membershipProvider.notifier)
          .assign('wtv', kArchiveGroupId);

      expect(
        container.read(membershipProvider)['wtv'],
        equals(kArchiveGroupId),
      );
      expect(await db.getProjectGroupId('wtv'), equals(kArchiveGroupId));
    });

    test('unassign() clears membership back to null ("Ohne Gruppe")', () async {
      final container = await _containerWithInMemoryDb();
      final db = container.read(appDatabaseProvider);
      final groupId = await db.createGroup('Vodafone');

      await container.read(membershipProvider.notifier).assign('wtv', groupId);
      await container.read(membershipProvider.notifier).unassign('wtv');

      expect(container.read(membershipProvider)['wtv'], isNull);
      expect(await db.getProjectGroupId('wtv'), isNull);
    });

    test(
      'ensureLoaded() reads current DB state for a folderId into state',
      () async {
        final container = await _containerWithInMemoryDb();
        final db = container.read(appDatabaseProvider);
        final groupId = await db.createGroup('Vodafone');
        await db.setProjectGroup('wtv', groupId);

        await container.read(membershipProvider.notifier).ensureLoaded('wtv');

        expect(container.read(membershipProvider)['wtv'], equals(groupId));
      },
    );

    test(
      'refreshFromDb() re-reads all tracked folderIds, reflecting an external dissolve',
      () async {
        final container = await _containerWithInMemoryDb();
        final db = container.read(appDatabaseProvider);
        final groupId = await db.createGroup('Kundenprojekte');

        await container
            .read(membershipProvider.notifier)
            .assign('wtv', groupId);
        await container
            .read(membershipProvider.notifier)
            .assign('vf-tk-deck', groupId);

        // Simulate a dissolve happening directly at the DB layer (as
        // groupsProvider.dissolve does via AppDatabase.deleteGroup).
        await db.deleteGroup(groupId);

        await container.read(membershipProvider.notifier).refreshFromDb();

        final membership = container.read(membershipProvider);
        expect(membership['wtv'], isNull);
        expect(membership['vf-tk-deck'], isNull);
      },
    );
  });
}
