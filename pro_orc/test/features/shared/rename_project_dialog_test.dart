import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/rename_project_dialog.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ProjectModel makeProject({String displayName = 'My Project'}) {
    return ProjectModel(
      folderId: 'my-folder',
      displayName: displayName,
      path: '/tmp/my-folder',
      projectType: ProjectType.code,
    );
  }

  /// Pump a host scaffold with an "Open" button that shows the dialog.
  /// Caller awaits tester.tap(find.text('Open')) + pumpAndSettle.
  Future<void> pumpHost(WidgetTester tester, ProjectModel project) async {
    // Use a generous test surface so the dialog has room.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => RenameProjectDialog(project: project),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('RenameProjectDialog', () {
    testWidgets('text field is pre-filled with current displayName', (
      tester,
    ) async {
      await pumpHost(tester, makeProject(displayName: 'My Project'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, equals('My Project'));
    });

    testWidgets('shows folderId in hint text', (tester) async {
      await pumpHost(tester, makeProject());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"my-folder"'), findsOneWidget);
    });

    testWidgets('save button writes display name to DB', (tester) async {
      await pumpHost(tester, makeProject());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Renamed!');
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      final settings = await db.getProjectSettings('my-folder');
      expect(settings?.displayName, equals('Renamed!'));
    });

    testWidgets('reset button clears display name override', (tester) async {
      await db.setProjectDisplayName('my-folder', 'Old Override');

      await pumpHost(tester, makeProject(displayName: 'Old Override'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Zuruecksetzen'));
      await tester.pumpAndSettle();

      final settings = await db.getProjectSettings('my-folder');
      expect(settings?.displayName, isNull);
    });

    testWidgets('save button is disabled when text matches current name', (
      tester,
    ) async {
      await pumpHost(tester, makeProject(displayName: 'Same'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Speichern'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('cancel button closes without writing to DB', (tester) async {
      await pumpHost(tester, makeProject());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Should Not Save');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      final settings = await db.getProjectSettings('my-folder');
      expect(settings, isNull);
    });
  });
}
