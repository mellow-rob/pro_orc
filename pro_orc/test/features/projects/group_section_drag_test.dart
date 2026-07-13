import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/data/models/group_section_data.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/projects/group_section.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:watcher/watcher.dart';

ProjectModel _project(String id) => ProjectModel(
  folderId: id,
  displayName: id,
  path: '/tmp/$id',
  projectType: ProjectType.code,
);

/// Pumps two stacked `GroupSection`s: a "source" section containing
/// [dragProject] and a "target" section (possibly empty) to drop onto.
/// Draggable/DragTarget widget tests require both the dragged widget and
/// the drop zone in the same tree so `tester.drag`/manual gesture can find
/// both hit-test targets.
Future<ProviderContainer> _pumpTwoSections(
  WidgetTester tester, {
  required ProjectGroup sourceGroup,
  required ProjectGroup targetGroup,
  required ProjectModel dragProject,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      watcherProvider.overrideWith((ref) => const Stream<WatchEvent>.empty()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                GroupSection(
                  key: const ValueKey('source'),
                  data: GroupSectionData(
                    group: sourceGroup,
                    members: [dragProject],
                  ),
                ),
                GroupSection(
                  key: const ValueKey('target'),
                  data: GroupSectionData(group: targetGroup, members: const []),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Drags from the center of [dragFinder] to the center of [dropFinder]
/// using manual gesture control (needed because `tester.drag` performs an
/// instantaneous move, which `Draggable` doesn't always register — using
/// discrete pointer moves matches how `DragTarget` tests are commonly
/// written in Flutter).
Future<void> _dragTo(
  WidgetTester tester,
  Finder dragFinder,
  Finder dropFinder,
) async {
  final dragStart = tester.getCenter(dragFinder);
  final dropCenter = tester.getCenter(dropFinder);

  final gesture = await tester.startGesture(dragStart);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(dropCenter);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('GroupSection drag & drop assignment (FR-007)', () {
    testWidgets('dragging a card onto another section assigns it there', (
      tester,
    ) async {
      const source = ProjectGroup(id: 'g1', name: 'Vodafone', isSystem: false);
      const target = ProjectGroup(
        id: 'g2',
        name: 'Kundenprojekte',
        isSystem: false,
      );
      final project = _project('wtv');

      final container = await _pumpTwoSections(
        tester,
        sourceGroup: source,
        targetGroup: target,
        dragProject: project,
      );
      await container.read(membershipProvider.notifier).assign('wtv', 'g1');
      await tester.pump();

      await _dragTo(
        tester,
        find.text('wtv'),
        find.text('Kundenprojekte'),
      );

      expect(container.read(membershipProvider)['wtv'], equals('g2'));
    });

    testWidgets(
      'dropping onto the section the project already belongs to is a '
      'silent no-op (no DB write)',
      (tester) async {
        const source = ProjectGroup(
          id: 'g1',
          name: 'Vodafone',
          isSystem: false,
        );
        const target = ProjectGroup(
          id: 'g1',
          name: 'Vodafone',
          isSystem: false,
        );
        final project = _project('wtv');

        final container = await _pumpTwoSections(
          tester,
          sourceGroup: source,
          targetGroup: target,
          dragProject: project,
        );
        await container.read(membershipProvider.notifier).assign('wtv', 'g1');
        await tester.pump();

        // Drop onto the OTHER rendered instance of the same group's
        // section header text — still group id 'g1', so this must no-op.
        final headings = find.text('Vodafone');
        expect(headings, findsNWidgets(2));

        await _dragTo(tester, find.text('wtv'), headings.last);

        expect(container.read(membershipProvider)['wtv'], equals('g1'));
      },
    );

    testWidgets('dropping onto Archiv assigns the project there', (
      tester,
    ) async {
      const source = ProjectGroup(id: 'g1', name: 'Vodafone', isSystem: false);
      const archiv = ProjectGroup(
        id: kArchiveGroupId,
        name: 'Archiv',
        isSystem: true,
      );
      final project = _project('wtv');

      final container = await _pumpTwoSections(
        tester,
        sourceGroup: source,
        targetGroup: archiv,
        dragProject: project,
      );
      await container.read(membershipProvider.notifier).assign('wtv', 'g1');
      await tester.pump();

      await _dragTo(tester, find.text('wtv'), find.text('Archiv'));

      expect(
        container.read(membershipProvider)['wtv'],
        equals(kArchiveGroupId),
      );
    });

    testWidgets('dropping onto "Ohne Gruppe" unassigns the project', (
      tester,
    ) async {
      const source = ProjectGroup(id: 'g1', name: 'Vodafone', isSystem: false);
      const ungrouped = ProjectGroup(
        id: GroupSectionData.ungroupedSentinelId,
        name: 'Ohne Gruppe',
        isSystem: false,
      );
      final project = _project('wtv');

      final container = await _pumpTwoSections(
        tester,
        sourceGroup: source,
        targetGroup: ungrouped,
        dragProject: project,
      );
      await container.read(membershipProvider.notifier).assign('wtv', 'g1');
      await tester.pump();

      await _dragTo(tester, find.text('wtv'), find.text('Ohne Gruppe'));

      expect(container.read(membershipProvider)['wtv'], isNull);
    });
  });
}
