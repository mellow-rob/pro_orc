import 'package:pro_orc/data/models/project_group.dart';
import 'package:pro_orc/data/models/project_model.dart';

/// One renderable section of the merged Projekte tab: a group header plus
/// its (already type/hidden-filtered) member projects.
///
/// Sections always render their header even with zero visible [members]
/// (FR-021) — only the member list is filtered per active type-chip, never
/// the section itself.
class GroupSectionData {
  final ProjectGroup group;
  final List<ProjectModel> members;

  const GroupSectionData({required this.group, required this.members});

  /// Synthetic sentinel id for the "Ohne Gruppe" section, which has no
  /// backing row in `groupsProvider` (`groupId == null` in the DB).
  static const String ungroupedSentinelId = '__ungrouped__';

  bool get isUngrouped => group.id == ungroupedSentinelId;
}
