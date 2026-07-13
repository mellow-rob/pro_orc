import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
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

ProjectModel _project(String folderId, {ProjectType? type = ProjectType.code}) {
  return ProjectModel(
    folderId: folderId,
    displayName: folderId,
    path: '/tmp/$folderId',
    projectType: type,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<ProjectModel> projects, {
  AppDatabase? db,
}) async {
  final database = db ?? AppDatabase(NativeDatabase.memory());
  if (db == null) addTearDown(database.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
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
  group('ProjectsTab', () {
    testWidgets('renders both Code and Research projects together', (
      tester,
    ) async {
      await _pump(tester, [
        _project('wtv', type: ProjectType.code),
        _project('vf-tk-deck', type: ProjectType.research),
      ]);

      expect(find.text('wtv'), findsOneWidget);
      expect(find.text('vf-tk-deck'), findsOneWidget);
    });

    testWidgets('shows filter chips Alle / Code / Research', (tester) async {
      await _pump(tester, [_project('wtv')]);

      expect(find.text('Alle'), findsOneWidget);
      expect(find.text('Code'), findsWidgets);
      expect(find.text('Research'), findsWidgets);
    });

    testWidgets('selecting Code filter hides Research projects but keeps '
        'the group heading', (tester) async {
      final container = await _pump(tester, [
        _project('wtv', type: ProjectType.code),
        _project('vf-tk-deck', type: ProjectType.research),
      ]);

      final group = await container
          .read(groupsProvider.notifier)
          .create('Vodafone');
      expect(group, isA<GroupActionSuccess>());
      final vodafone = container
          .read(groupsProvider)
          .firstWhere((g) => g.name == 'Vodafone');
      await container
          .read(membershipProvider.notifier)
          .assign('wtv', vodafone.id);
      await container
          .read(membershipProvider.notifier)
          .assign('vf-tk-deck', vodafone.id);
      await tester.pump();

      // `find.text('Code')` also matches the read-only TypeBadge label on
      // the 'wtv' card, so target the filter chip specifically via its
      // InkWell wrapper (see _FilterChip in projects_tab_header.dart) —
      // TypeBadge renders a plain Container, never an InkWell.
      await tester.tap(find.widgetWithText(InkWell, 'Code'));
      await tester.pump();

      expect(find.text('Vodafone'), findsOneWidget);
      expect(find.text('wtv'), findsOneWidget);
      expect(find.text('vf-tk-deck'), findsNothing);
    });

    testWidgets('view toggle switches between grid and list rendering', (
      tester,
    ) async {
      final container = await _pump(tester, [_project('wtv')]);

      expect(container.read(viewModeProvider), ViewMode.grid);

      final toggle = find.byKey(const ValueKey('view-mode-toggle'));
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump();

      expect(container.read(viewModeProvider), ViewMode.list);
    });

    testWidgets(
      'a project flagged is_hidden=1 in the DB is still shown (Privat '
      'feature removed — the UI no longer hides any project)',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.upsertProjectSettings(
          ProjectSettingsTableCompanion(
            folderId: const Value('secret-project'),
            isHidden: const Value(true),
          ),
        );

        await _pump(tester, [
          _project('wtv'),
          _project('secret-project'),
        ], db: db);

        expect(find.text('secret-project'), findsOneWidget);
        expect(find.text('wtv'), findsOneWidget);
      },
    );

    testWidgets('empty state shows when there are no projects at all', (
      tester,
    ) async {
      await _pump(tester, []);

      expect(find.text('Keine Projekte gefunden'), findsOneWidget);
    });
  });
}
