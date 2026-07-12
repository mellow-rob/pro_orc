import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/data/models/group_section_data.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/projects/group_section.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/group_collapse_provider.dart';
import 'package:pro_orc/providers/view_mode_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:watcher/watcher.dart';

ProjectModel _project(String id) => ProjectModel(
  folderId: id,
  displayName: id,
  path: '/tmp/$id',
  projectType: ProjectType.code,
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  GroupSectionData data, {
  ViewMode viewMode = ViewMode.grid,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      watcherProvider.overrideWith((ref) => const Stream<WatchEvent>.empty()),
    ],
  );
  addTearDown(container.dispose);
  if (viewMode == ViewMode.list) {
    await container.read(viewModeProvider.notifier).set(ViewMode.list);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: SingleChildScrollView(child: GroupSection(data: data)),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('GroupSection — user group', () {
    testWidgets('shows name and member count pill', (tester) async {
      const group = ProjectGroup(id: 'g1', name: 'Vodafone', isSystem: false);
      final data = GroupSectionData(group: group, members: [_project('a')]);

      await _pump(tester, data);

      expect(find.text('Vodafone'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows the ⋯ placeholder button', (tester) async {
      const group = ProjectGroup(id: 'g1', name: 'Vodafone', isSystem: false);
      final data = GroupSectionData(group: group, members: []);

      await _pump(tester, data);

      expect(find.byIcon(LucideIcons.ellipsis100), findsOneWidget);
    });

    testWidgets('shows call-to-action text when empty', (tester) async {
      const group = ProjectGroup(id: 'g1', name: 'Leer', isSystem: false);
      final data = GroupSectionData(group: group, members: []);

      await _pump(tester, data);

      expect(find.textContaining('Noch keine Projekte'), findsOneWidget);
    });

    testWidgets('tapping the header toggles collapse state', (tester) async {
      const group = ProjectGroup(id: 'g1', name: 'Vodafone', isSystem: false);
      final data = GroupSectionData(group: group, members: [_project('a')]);

      final container = await _pump(tester, data);
      await tester.pump();

      expect(find.text('a'), findsOneWidget);

      await tester.tap(find.text('Vodafone'));
      await tester.pump();

      expect(container.read(groupCollapseProvider)['g1'], isTrue);
      expect(find.text('a'), findsNothing);
    });
  });

  group('GroupSection — Archiv system group', () {
    testWidgets('shows the archive icon and no ⋯ button', (tester) async {
      const group = ProjectGroup(
        id: kArchiveGroupId,
        name: 'Archiv',
        isSystem: true,
      );
      final data = GroupSectionData(group: group, members: [_project('a')]);

      await _pump(tester, data);

      expect(find.byIcon(LucideIcons.archive100), findsOneWidget);
      expect(find.byIcon(LucideIcons.ellipsis100), findsNothing);
    });

    testWidgets('starts collapsed by default (body not in tree)', (
      tester,
    ) async {
      const group = ProjectGroup(
        id: kArchiveGroupId,
        name: 'Archiv',
        isSystem: true,
      );
      final data = GroupSectionData(group: group, members: [_project('a')]);

      await _pump(tester, data);
      await tester.pump();

      expect(find.text('a'), findsNothing);
    });

    testWidgets('members are dimmed via Opacity(0.6) once expanded', (
      tester,
    ) async {
      const group = ProjectGroup(
        id: kArchiveGroupId,
        name: 'Archiv',
        isSystem: true,
      );
      final data = GroupSectionData(group: group, members: [_project('a')]);

      final container = await _pump(tester, data);
      await tester.pump();

      // Force-expand via the provider (mirrors user toggling it once).
      await container
          .read(groupCollapseProvider.notifier)
          .toggle(kArchiveGroupId);
      await tester.pump();

      expect(find.text('a'), findsOneWidget);
      final opacityFinder = find.ancestor(
        of: find.text('a'),
        matching: find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == 0.6,
        ),
      );
      expect(opacityFinder, findsOneWidget);
    });
  });
}
