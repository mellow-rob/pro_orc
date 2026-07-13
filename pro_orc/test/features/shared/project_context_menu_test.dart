import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/project_context_menu.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ProjectModel makeProject({String folderId = 'wtv'}) {
    return ProjectModel(
      folderId: folderId,
      displayName: folderId,
      path: '/tmp/$folderId',
      projectType: ProjectType.code,
    );
  }

  Future<ProviderContainer> pumpHost(
    WidgetTester tester,
    ProjectModel project,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(groupsProvider);
    container.read(membershipProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Scaffold(
            body: Center(
              child: Consumer(
                builder: (context, ref, _) => GestureDetector(
                  onSecondaryTapUp: (details) => showProjectContextMenu(
                    context: context,
                    details: details,
                    isHidden: false,
                    ref: ref,
                    project: project,
                    moveTarget: ProjectType.research,
                  ),
                  child: const SizedBox(
                    width: 100,
                    height: 100,
                    child: Text('Card'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> rightClick(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Card')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('showProjectContextMenu — group assignment', () {
    testWidgets('shows "Gruppe zuweisen" and no "Aus Gruppe entfernen" '
        'when project is ungrouped', (tester) async {
      await pumpHost(tester, makeProject());
      await rightClick(tester);

      expect(find.text('Gruppe zuweisen'), findsOneWidget);
      expect(find.text('Aus Gruppe entfernen'), findsNothing);
    });

    testWidgets('relabels "move" entry to "Als Research markieren"', (
      tester,
    ) async {
      await pumpHost(tester, makeProject());
      await rightClick(tester);

      expect(find.text('Als Research markieren'), findsOneWidget);
      expect(find.textContaining('Verschieben nach'), findsNothing);
    });

    testWidgets('shows "Aus Gruppe entfernen" when project has a group', (
      tester,
    ) async {
      final container = await pumpHost(tester, makeProject());
      await container.read(membershipProvider.notifier).assign('wtv', kArchiveGroupId);
      await tester.pump();

      await rightClick(tester);

      expect(find.text('Aus Gruppe entfernen'), findsOneWidget);
    });

    testWidgets('submenu lists all groups including Archiv and assigns on tap', (
      tester,
    ) async {
      await db.createGroup('Vodafone');
      final container = await pumpHost(tester, makeProject());
      await tester.pump();

      await rightClick(tester);
      await tester.tap(find.text('Gruppe zuweisen'));
      await tester.pumpAndSettle();

      expect(find.text('Vodafone'), findsOneWidget);
      expect(find.text('Archiv'), findsOneWidget);
      expect(find.text('Neue Gruppe…'), findsOneWidget);

      await tester.tap(find.text('Vodafone'));
      await tester.pumpAndSettle();

      final groups = container.read(groupsProvider);
      final vodafoneId = groups.firstWhere((g) => g.name == 'Vodafone').id;
      expect(container.read(membershipProvider)['wtv'], equals(vodafoneId));
    });

    testWidgets('assigning to a new group replaces the previous one (1:1)', (
      tester,
    ) async {
      await db.createGroup('Vodafone');
      await db.createGroup('Kundenprojekte');
      final container = await pumpHost(tester, makeProject());
      await tester.pump();

      final groups = container.read(groupsProvider);
      final vodafoneId = groups.firstWhere((g) => g.name == 'Vodafone').id;
      final kundenId = groups.firstWhere((g) => g.name == 'Kundenprojekte').id;

      await container.read(membershipProvider.notifier).assign('wtv', vodafoneId);
      await tester.pump();

      await rightClick(tester);
      await tester.tap(find.text('Gruppe zuweisen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kundenprojekte'));
      await tester.pumpAndSettle();

      expect(container.read(membershipProvider)['wtv'], equals(kundenId));
      expect(container.read(membershipProvider)['wtv'], isNot(equals(vodafoneId)));
    });

    testWidgets('"Neue Gruppe…" creates a group and assigns in one step', (
      tester,
    ) async {
      final container = await pumpHost(tester, makeProject());
      await tester.pump();

      await rightClick(tester);
      await tester.tap(find.text('Gruppe zuweisen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Gruppe…'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Launch Partners');
      await tester.tap(find.text('Erstellen'));
      await tester.pumpAndSettle();

      final groups = container.read(groupsProvider);
      final newGroup = groups.firstWhere((g) => g.name == 'Launch Partners');
      expect(container.read(membershipProvider)['wtv'], equals(newGroup.id));
    });

    testWidgets('"Aus Gruppe entfernen" unassigns the project', (
      tester,
    ) async {
      await db.createGroup('Vodafone');
      final container = await pumpHost(tester, makeProject());
      await tester.pump();

      final groups = container.read(groupsProvider);
      final vodafoneId = groups.firstWhere((g) => g.name == 'Vodafone').id;
      await container.read(membershipProvider.notifier).assign('wtv', vodafoneId);
      await tester.pump();

      await rightClick(tester);
      await tester.tap(find.text('Aus Gruppe entfernen'));
      await tester.pumpAndSettle();

      expect(container.read(membershipProvider)['wtv'], isNull);
    });
  });
}
