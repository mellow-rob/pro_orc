import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';

Future<ProviderContainer> _containerWithInMemoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  return container;
}

void main() {
  group('ViewMode string conversion', () {
    test('fromString converts "grid" and "list"', () {
      expect(ViewMode.fromString('grid'), equals(ViewMode.grid));
      expect(ViewMode.fromString('list'), equals(ViewMode.list));
    });

    test('fromString falls back to grid for unknown values', () {
      expect(ViewMode.fromString('unknown'), equals(ViewMode.grid));
      expect(ViewMode.fromString(''), equals(ViewMode.grid));
    });

    test('toDbString round-trips', () {
      for (final mode in ViewMode.values) {
        expect(ViewMode.fromString(mode.toDbString()), equals(mode));
      }
    });
  });

  group('viewModeProvider', () {
    test('build() defaults to grid when never set', () async {
      final container = await _containerWithInMemoryDb();
      container.read(viewModeProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(viewModeProvider), equals(ViewMode.grid));
    });

    test('set() persists the new mode via AppDatabase.setViewMode', () async {
      final container = await _containerWithInMemoryDb();
      container.read(viewModeProvider);
      await Future<void>.delayed(Duration.zero);

      await container.read(viewModeProvider.notifier).set(ViewMode.list);

      expect(container.read(viewModeProvider), equals(ViewMode.list));
      final db = container.read(appDatabaseProvider);
      expect(await db.getViewMode(), equals('list'));
    });

    test('toggle() flips grid <-> list and persists', () async {
      final container = await _containerWithInMemoryDb();
      container.read(viewModeProvider);
      await Future<void>.delayed(Duration.zero);

      await container.read(viewModeProvider.notifier).toggle();
      expect(container.read(viewModeProvider), equals(ViewMode.list));

      await container.read(viewModeProvider.notifier).toggle();
      expect(container.read(viewModeProvider), equals(ViewMode.grid));
    });

    test(
      'persisted view mode is re-read as initial state after restart',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.setViewMode('list');

        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        container.read(viewModeProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(viewModeProvider), equals(ViewMode.list));
      },
    );
  });
}
