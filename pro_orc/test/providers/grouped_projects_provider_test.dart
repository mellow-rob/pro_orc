import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/db/tables/project_groups_table.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/grouped_projects_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

ProjectModel _project(String folderId, {String? displayName}) {
  return ProjectModel(
    folderId: folderId,
    displayName: displayName ?? folderId,
    path: '/tmp/$folderId',
  );
}

Future<ProviderContainer> _containerWithProjects(
  List<ProjectModel> projects,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      projectsProvider.overrideWith((ref) async => projects),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(db.close);
  // Settle projectsProvider (FutureProvider — needs to resolve to `data`)
  // plus groupsProvider / hiddenProjectsProvider async build() calls,
  // mirroring the Wave 1/2 test pattern.
  await container.read(projectsProvider.future);
  container.read(groupsProvider);
  container.read(hiddenProjectsProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  group('groupedProjectsProvider', () {
    test(
      'orders sections: user groups alphabetically, then Ohne Gruppe, then Archiv',
      () async {
        final container = await _containerWithProjects([
          _project('alpha'),
          _project('beta'),
        ]);

        await container.read(groupsProvider.notifier).create('Zebra');
        await container.read(groupsProvider.notifier).create('Anton');

        final sections = container.read(groupedProjectsProvider);
        final names = sections.map((s) => s.group.name).toList();

        expect(names, ['Anton', 'Zebra', 'Ohne Gruppe', 'Archiv']);
      },
    );

    test(
      'Ohne Gruppe section contains projects with no group assignment',
      () async {
        final container = await _containerWithProjects([
          _project('alpha'),
          _project('beta'),
        ]);

        final sections = container.read(groupedProjectsProvider);
        final ungrouped = sections.firstWhere((s) => s.isUngrouped);

        expect(ungrouped.members.map((p) => p.folderId).toSet(), {
          'alpha',
          'beta',
        });
      },
    );

    test('members are placed in their assigned group section', () async {
      final container = await _containerWithProjects([
        _project('alpha'),
        _project('beta'),
      ]);

      final result = await container
          .read(groupsProvider.notifier)
          .create('Vodafone');
      expect(result, isA<GroupActionSuccess>());
      final group = container
          .read(groupsProvider)
          .firstWhere((g) => g.name == 'Vodafone');

      await container
          .read(membershipProvider.notifier)
          .assign('alpha', group.id);

      final sections = container.read(groupedProjectsProvider);
      final vodafoneSection = sections.firstWhere(
        (s) => s.group.name == 'Vodafone',
      );
      final ungrouped = sections.firstWhere((s) => s.isUngrouped);

      expect(vodafoneSection.members.map((p) => p.folderId).toList(), [
        'alpha',
      ]);
      expect(ungrouped.members.map((p) => p.folderId).toList(), ['beta']);
    });

    test(
      'empty user group still appears as a section with zero members',
      () async {
        final container = await _containerWithProjects([_project('alpha')]);

        await container.read(groupsProvider.notifier).create('Leere Gruppe');

        final sections = container.read(groupedProjectsProvider);
        final empty = sections.firstWhere(
          (s) => s.group.name == 'Leere Gruppe',
        );

        expect(empty.members, isEmpty);
      },
    );

    test('hidden projects are excluded from all sections', () async {
      final container = await _containerWithProjects([
        _project('alpha'),
        _project('beta'),
      ]);

      await container.read(hiddenProjectsProvider.notifier).toggle('alpha');

      final sections = container.read(groupedProjectsProvider);
      final allMembers = sections.expand((s) => s.members).toList();

      expect(allMembers.map((p) => p.folderId), isNot(contains('alpha')));
      expect(allMembers.map((p) => p.folderId), contains('beta'));
    });

    test('Archiv section always exists and reports its group id', () async {
      final container = await _containerWithProjects([_project('alpha')]);

      final sections = container.read(groupedProjectsProvider);
      final archive = sections.firstWhere((s) => s.group.name == 'Archiv');

      expect(archive.group.id, kArchiveGroupId);
      expect(archive.group.isSystem, isTrue);
    });
  });
}
