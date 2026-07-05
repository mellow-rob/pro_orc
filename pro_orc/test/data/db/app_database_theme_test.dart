import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';

void main() {
  group('AppDatabase theme mode', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('defaults to "dark" when never set', () async {
      final mode = await db.getThemeMode();
      expect(mode, equals('dark'));
    });

    test('setThemeMode persists the value', () async {
      await db.setThemeMode('light');
      final mode = await db.getThemeMode();
      expect(mode, equals('light'));
    });

    test('setThemeMode("system") round-trips correctly', () async {
      await db.setThemeMode('system');
      final mode = await db.getThemeMode();
      expect(mode, equals('system'));
    });
  });
}
