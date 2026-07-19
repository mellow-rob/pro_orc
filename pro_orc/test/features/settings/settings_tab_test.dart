import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/features/settings/settings_tab.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Fake for [FileSelectorPlatform] — the plugin's platform interface is
/// designed to be swapped out via `FileSelectorPlatform.instance` for
/// testing (see file_selector_platform_interface). Only the single method
/// the ignore-list picker uses is overridden; the picked path is fixed at
/// construction time.
class _FakeFileSelectorPlatform extends FileSelectorPlatform {
  _FakeFileSelectorPlatform(this.pathToReturn);

  final String? pathToReturn;

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return pathToReturn;
  }
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: const Scaffold(body: SettingsTab()),
      ),
    ),
  );
  // Initial frame shows the loading spinner while _loadSettings() awaits.
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final originalFileSelector = FileSelectorPlatform.instance;

  tearDown(() {
    FileSelectorPlatform.instance = originalFileSelector;
  });

  group('SettingsTab ignore pattern add (folder picker)', () {
    testWidgets(
      'plus click opens the picker; picked folder basename becomes a chip '
      'and is persisted',
      (tester) async {
        FileSelectorPlatform.instance = _FakeFileSelectorPlatform(
          '/Users/rob/code/build-artifacts',
        );

        final container = await _pump(tester);
        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.add_circle_outline),
        );
        await tester.pumpAndSettle();

        expect(find.text('build-artifacts'), findsOneWidget);
        expect(find.widgetWithText(Chip, 'build-artifacts'), findsOneWidget);

        final db = container.read(appDatabaseProvider);
        final config = await db.getConfig();
        expect(config.ignoreListJson, contains('build-artifacts'));
      },
    );

    testWidgets('picker cancelled (null) adds nothing and writes nothing', (
      tester,
    ) async {
      FileSelectorPlatform.instance = _FakeFileSelectorPlatform(null);

      final container = await _pump(tester);
      final db = container.read(appDatabaseProvider);
      final chipCountBefore = find.byType(Chip).evaluate().length;
      final ignoreListJsonBefore = (await db.getConfig()).ignoreListJson;

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip).evaluate().length, chipCountBefore);
      final configAfter = await db.getConfig();
      expect(configAfter.ignoreListJson, ignoreListJsonBefore);
    });

    testWidgets('picking a folder whose basename is already ignored adds no '
        'second chip', (tester) async {
      // "build" is part of the DB's default ignore list (see
      // app_config_table.dart) — use a basename that isn't, so the
      // duplicate is unambiguously caused by this test's own first pick.
      FileSelectorPlatform.instance = _FakeFileSelectorPlatform(
        '/Users/rob/code/dist-artifacts',
      );

      final container = await _pump(tester);

      // Add it once.
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'dist-artifacts'), findsOneWidget);

      // Pick a different path with the same basename. The chip added
      // above may have pushed the button below the fold in the test
      // viewport — that's a real, harmless scroll offset (not a hidden
      // widget), so tap with warnIfMissed: false rather than fighting
      // the scroll position.
      FileSelectorPlatform.instance = _FakeFileSelectorPlatform(
        '/Users/rob/other/dist-artifacts',
      );
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'dist-artifacts'), findsOneWidget);

      final db = container.read(appDatabaseProvider);
      final config = await db.getConfig();
      expect('dist-artifacts'.allMatches(config.ignoreListJson).length, 1);
    });
  });
}
