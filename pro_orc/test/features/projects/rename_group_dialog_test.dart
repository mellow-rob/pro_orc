import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/features/projects/rename_group_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<ProviderContainer> pumpHost(
    WidgetTester tester,
    ProjectGroup group,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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
    // Let groupsProvider load the DB-seeded groups before the dialog reads
    // them via ref (create/rename go through the notifier's own state).
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
                  onPressed: () => showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => RenameGroupDialog(group: group),
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

  group('RenameGroupDialog', () {
    testWidgets('text field is pre-filled with current name', (tester) async {
      await db.createGroup('Vodafone');
      final groups = await db.getGroups();
      final group = groups.firstWhere((g) => g.name == 'Vodafone');

      await pumpHost(
        tester,
        ProjectGroup(id: group.id, name: group.name, isSystem: false),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, equals('Vodafone'));
    });

    testWidgets('renames the group on save', (tester) async {
      await db.createGroup('Vodafone');
      final groups = await db.getGroups();
      final group = groups.firstWhere((g) => g.name == 'Vodafone');

      final container = await pumpHost(
        tester,
        ProjectGroup(id: group.id, name: group.name, isSystem: false),
      );

      await tester.enterText(find.byType(TextField), 'Vodafone Renamed');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final updated = container.read(groupsProvider);
      expect(
        updated.any((g) => g.id == group.id && g.name == 'Vodafone Renamed'),
        isTrue,
      );
    });

    testWidgets('shows inline error for duplicate name', (tester) async {
      await db.createGroup('Vodafone');
      await db.createGroup('Kundenprojekte');
      final groups = await db.getGroups();
      final group = groups.firstWhere((g) => g.name == 'Vodafone');

      await pumpHost(
        tester,
        ProjectGroup(id: group.id, name: group.name, isSystem: false),
      );

      await tester.enterText(find.byType(TextField), 'kundenprojekte');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Gruppe existiert bereits'), findsOneWidget);
    });

    testWidgets('shows inline error when renaming to reserved "Archiv"', (
      tester,
    ) async {
      await db.createGroup('Vodafone');
      final groups = await db.getGroups();
      final group = groups.firstWhere((g) => g.name == 'Vodafone');

      await pumpHost(
        tester,
        ProjectGroup(id: group.id, name: group.name, isSystem: false),
      );

      await tester.enterText(find.byType(TextField), 'Archiv');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Gruppe existiert bereits'), findsOneWidget);
    });

    testWidgets('cancel closes without renaming', (tester) async {
      await db.createGroup('Vodafone');
      final groups = await db.getGroups();
      final group = groups.firstWhere((g) => g.name == 'Vodafone');

      final container = await pumpHost(
        tester,
        ProjectGroup(id: group.id, name: group.name, isSystem: false),
      );

      await tester.enterText(find.byType(TextField), 'Should Not Save');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      final updated = container.read(groupsProvider);
      expect(
        updated.any((g) => g.id == group.id && g.name == 'Vodafone'),
        isTrue,
      );
    });
  });
}
