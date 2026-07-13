import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/a1_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/projects/a1_badge.dart';
import 'package:pro_orc/features/projects/project_card.dart';
import 'package:pro_orc/features/projects/type_badge.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:watcher/watcher.dart';

Future<void> _pump(
  WidgetTester tester,
  ProjectModel project, {
  AppDatabase? db,
}) async {
  final database = db ?? AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        watcherProvider.overrideWith((ref) => const Stream<WatchEvent>.empty()),
      ],
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(body: ProjectCard(project: project)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the Code TypeBadge for a code project', (tester) async {
    await _pump(
      tester,
      const ProjectModel(
        folderId: 'demo',
        displayName: 'Demo',
        path: '/tmp/demo',
        projectType: ProjectType.code,
      ),
    );

    expect(find.byType(TypeBadge), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
  });

  testWidgets('shows the Research TypeBadge for a research project', (
    tester,
  ) async {
    await _pump(
      tester,
      const ProjectModel(
        folderId: 'demo',
        displayName: 'Demo',
        path: '/tmp/demo',
        projectType: ProjectType.research,
      ),
    );

    expect(find.text('Research'), findsOneWidget);
  });

  testWidgets('shows the A1Badge when the project has a1 data', (tester) async {
    await _pump(
      tester,
      const ProjectModel(
        folderId: 'demo',
        displayName: 'Demo',
        path: '/tmp/demo',
        projectType: ProjectType.code,
        a1: A1Data(
          phases: [
            A1Phase(name: 'M1', checkedTasks: 1, totalTasks: 4, planPath: 'x'),
          ],
        ),
      ),
    );

    expect(find.byType(A1Badge), findsOneWidget);
    expect(find.text('a1'), findsOneWidget);
  });

  testWidgets('does not show a1 progress text when a1 is null', (tester) async {
    await _pump(
      tester,
      const ProjectModel(
        folderId: 'demo',
        displayName: 'Demo',
        path: '/tmp/demo',
        projectType: ProjectType.code,
      ),
    );

    expect(find.text('a1'), findsNothing);
  });

  testWidgets('renders the project display name and description', (
    tester,
  ) async {
    await _pump(
      tester,
      const ProjectModel(
        folderId: 'demo',
        displayName: 'Demo Projekt',
        path: '/tmp/demo',
        projectType: ProjectType.research,
        description: 'Eine Beschreibung',
      ),
    );

    expect(find.text('Demo Projekt'), findsOneWidget);
    expect(find.text('Eine Beschreibung'), findsOneWidget);
  });
}
