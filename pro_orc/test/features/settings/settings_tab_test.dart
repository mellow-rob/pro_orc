import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/features/settings/settings_tab.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

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
  group('SettingsTab ignore pattern add', () {
    testWidgets('plus click with non-empty field adds the pattern', (
      tester,
    ) async {
      await _pump(tester);

      await tester.enterText(find.byKey(const Key('ignoreAddField')), 'build*');
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      await tester.pumpAndSettle();

      expect(find.text('build*'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'build*'), findsOneWidget);
    });

    testWidgets(
      'plus click with empty field adds nothing and focuses the field',
      (tester) async {
        await _pump(tester);

        final fieldFinder = find.byKey(const Key('ignoreAddField'));
        final fieldBefore = tester.widget<TextField>(fieldFinder);
        expect(fieldBefore.focusNode!.hasFocus, isFalse);
        final chipCountBefore = find.byType(Chip).evaluate().length;

        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.add_circle_outline),
        );
        await tester.pump();

        // No ignore-pattern chip was added — chip count is unchanged.
        expect(find.byType(Chip).evaluate().length, chipCountBefore);

        // The field now has focus instead of the click silently vanishing.
        final fieldAfter = tester.widget<TextField>(fieldFinder);
        expect(fieldAfter.focusNode!.hasFocus, isTrue);

        // Highlight is active immediately after the click...
        final containerFinder = find.ancestor(
          of: fieldFinder,
          matching: find.byType(AnimatedContainer),
        );
        final decoratedBoxBefore = tester.widget<AnimatedContainer>(
          containerFinder,
        );
        expect(
          (decoratedBoxBefore.decoration as BoxDecoration).boxShadow,
          isNotEmpty,
        );

        // ...and fades back out after the highlight duration elapses.
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();
        final decoratedBoxAfter = tester.widget<AnimatedContainer>(
          containerFinder,
        );
        expect(
          (decoratedBoxAfter.decoration as BoxDecoration).boxShadow,
          isEmpty,
        );
      },
    );
  });
}
