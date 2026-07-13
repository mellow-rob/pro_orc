import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/projects/projects_tab.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:watcher/watcher.dart';

ProjectModel _project(String folderId) {
  return ProjectModel(
    folderId: folderId,
    displayName: folderId,
    path: '/tmp/$folderId',
    projectType: ProjectType.code,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<ProjectModel> projects,
) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      projectsProvider.overrideWith((ref) async => projects),
      watcherProvider.overrideWith((ref) => const Stream<WatchEvent>.empty()),
    ],
  );
  addTearDown(container.dispose);

  await container.read(projectsProvider.future);
  container.read(groupsProvider);
  container.read(membershipProvider);
  container.read(viewModeProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: const Scaffold(body: ProjectsTab()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  group('"+ Gruppe" header affordance (FR-019)', () {
    testWidgets('opens CreateGroupDialog and creates a new group', (
      tester,
    ) async {
      final container = await _pump(tester, [_project('wtv')]);

      await tester.tap(find.text('+ Gruppe'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Launch Partners');
      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();

      final groups = container.read(groupsProvider);
      expect(groups.any((g) => g.name == 'Launch Partners'), isTrue);
    });
  });

  group('No-duplicate-project audit (FR-017/SC-008)', () {
    testWidgets('no "duplicate project" affordance exists in the tab body', (
      tester,
    ) async {
      await _pump(tester, [_project('wtv')]);

      expect(find.textContaining('duplizieren'), findsNothing);
      expect(find.textContaining('Duplizieren'), findsNothing);
      expect(find.textContaining('Duplicate'), findsNothing);
      expect(find.textContaining('Kopie'), findsNothing);
    });

    testWidgets(
      'no "duplicate project" entry exists in the card context menu',
      (tester) async {
        await _pump(tester, [_project('wtv')]);

        final cardFinder = find.text('wtv');
        await tester.tap(
          find.ancestor(of: cardFinder, matching: find.byType(GestureDetector)),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('duplizieren'), findsNothing);
        expect(find.textContaining('Duplizieren'), findsNothing);
        expect(find.textContaining('Duplicate'), findsNothing);
        expect(find.textContaining('Kopie'), findsNothing);
      },
    );
  });
}
