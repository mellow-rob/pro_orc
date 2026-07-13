import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/features/projects/create_group_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Force groupsProvider.build() to run and its async _loadFromDb() to
    // settle before the dialog is opened — otherwise the notifier's `state`
    // (read by validateGroupName inside create()) is still the empty initial
    // list when a pre-seeded duplicate/reserved name is tested.
    container.read(groupsProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<String>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const CreateGroupDialog(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return container;
  }

  group('CreateGroupDialog', () {
    testWidgets('creates a new group and closes on valid name', (
      tester,
    ) async {
      final container = await pumpHost(tester);

      await tester.enterText(find.byType(TextField), 'Launch Partners');
      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();

      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.name == 'Launch Partners'), isTrue);
      expect(find.byType(CreateGroupDialog), findsNothing);
    });

    testWidgets('shows inline error for duplicate name', (tester) async {
      await db.createGroup('Vodafone');
      final container = await pumpHost(tester);
      // Let groupsProvider pick up the pre-seeded group.
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'vodafone');
      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();

      expect(find.text('Gruppe existiert bereits'), findsOneWidget);
      expect(find.byType(CreateGroupDialog), findsOneWidget);
      final groups = container.read(groupsProvider);
      expect(groups.where((g) => g.name.toLowerCase() == 'vodafone').length, 1);
    });

    testWidgets('shows inline error for reserved name "Archiv"', (
      tester,
    ) async {
      await pumpHost(tester);

      await tester.enterText(find.byType(TextField), 'archiv');
      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();

      expect(find.text('Gruppe existiert bereits'), findsOneWidget);
    });

    testWidgets('cancel closes without creating a group', (tester) async {
      final container = await pumpHost(tester);

      await tester.enterText(find.byType(TextField), 'Should Not Exist');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.name == 'Should Not Exist'), isFalse);
    });

    testWidgets('dialog heading truncates with ellipsis and has a tooltip', (
      tester,
    ) async {
      await pumpHost(tester);

      final text = tester.widget<Text>(find.text('Neue Gruppe'));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.byTooltip('Neue Gruppe'), findsOneWidget);
    });
  });
}
