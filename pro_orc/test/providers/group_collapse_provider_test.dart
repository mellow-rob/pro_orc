import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/group_collapse_provider.dart';

Future<ProviderContainer> _containerWithInMemoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  await db.getGroups();
  return container;
}

void main() {
  group('groupCollapseProvider', () {
    test(
      'build() loads collapse state for all existing groups, Archiv defaults true',
      () async {
        final container = await _containerWithInMemoryDb();
        final db = container.read(appDatabaseProvider);
        final groupId = await db.createGroup('Vodafone');

        container.read(groupCollapseProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(groupCollapseProvider);
        expect(state[kArchiveGroupId], isTrue);
        expect(state[groupId], isFalse);
      },
    );

    test('toggle() flips and persists a group\'s collapse state', () async {
      final container = await _containerWithInMemoryDb();
      final db = container.read(appDatabaseProvider);
      final groupId = await db.createGroup('Vodafone');

      container.read(groupCollapseProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await container.read(groupCollapseProvider.notifier).toggle(groupId);

      expect(container.read(groupCollapseProvider)[groupId], isTrue);
      expect(await db.getCollapseState(groupId), isTrue);

      await container.read(groupCollapseProvider.notifier).toggle(groupId);

      expect(container.read(groupCollapseProvider)[groupId], isFalse);
      expect(await db.getCollapseState(groupId), isFalse);
    });

    test(
      'toggle() on Archiv flips it from its collapsed default to expanded',
      () async {
        final container = await _containerWithInMemoryDb();
        final db = container.read(appDatabaseProvider);

        container.read(groupCollapseProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await container
            .read(groupCollapseProvider.notifier)
            .toggle(kArchiveGroupId);

        expect(container.read(groupCollapseProvider)[kArchiveGroupId], isFalse);
        expect(await db.getCollapseState(kArchiveGroupId), isFalse);
      },
    );

    test('collapse state persists across a provider rebuild', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final groupId = await db.createGroup('Vodafone');
      await db.setCollapseState(groupId, true);

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      container.read(groupCollapseProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(groupCollapseProvider)[groupId], isTrue);
    });
  });
}
