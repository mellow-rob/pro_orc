import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/db/tables/project_groups_table.dart'
    show kArchiveGroupId;
import 'package:pro_orc/data/models/group_section_data.dart';
import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

/// Computes the ordered list of [GroupSectionData] for the merged Projekte
/// tab (FR-011): user-created groups alphabetically, then the synthetic
/// "Ohne Gruppe" section, then "Archiv" (always last).
///
/// Design decision: this provider does NOT take a [ProjectType] filter
/// parameter. The type-filter (Alle/Code/Research chip) is applied by the
/// tab widget on top of the already-grouped sections, filtering only each
/// section's `members` list — never dropping a section outright, since
/// FR-021 requires section headings to stay visible even at zero visible
/// members under a filter. Keeping this provider filter-agnostic means its
/// output (grouping + ordering) is identical regardless of which chip is
/// active, and both the grid and the list view share that single source
/// of truth.
final groupedProjectsProvider = Provider<List<GroupSectionData>>((ref) {
  final projectsAsync = ref.watch(projectsProvider);
  final groups = ref.watch(groupsProvider);
  final membership = ref.watch(membershipProvider);

  final allProjects = projectsAsync.value ?? const <ProjectModel>[];

  final byGroupId = <String?, List<ProjectModel>>{};
  for (final project in allProjects) {
    final groupId = membership[project.folderId];
    (byGroupId[groupId] ??= []).add(project);
  }

  final userGroups = groups.where((g) => !g.isSystem).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final archiveGroups = groups.where((g) => g.isSystem).toList();

  final sections = <GroupSectionData>[
    for (final group in userGroups)
      GroupSectionData(group: group, members: byGroupId[group.id] ?? const []),
    GroupSectionData(
      group: const ProjectGroup(
        id: GroupSectionData.ungroupedSentinelId,
        name: 'Ohne Gruppe',
        isSystem: false,
      ),
      members: byGroupId[null] ?? const [],
    ),
    for (final group in archiveGroups)
      GroupSectionData(group: group, members: byGroupId[group.id] ?? const []),
  ];

  return sections;
});

/// Re-exported so callers that only need the Archiv sentinel id don't have
/// to reach into the DB table file directly.
const String archiveGroupId = kArchiveGroupId;
