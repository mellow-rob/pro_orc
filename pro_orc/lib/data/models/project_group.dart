/// Immutable view of a project group (user-created or the system-owned
/// "Archiv" group). Mirrors a row of `ProjectGroupsTable`.
class ProjectGroup {
  final String id;
  final String name;
  final bool isSystem;

  const ProjectGroup({
    required this.id,
    required this.name,
    required this.isSystem,
  });

  ProjectGroup copyWith({String? id, String? name, bool? isSystem}) {
    return ProjectGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isSystem == other.isSystem;

  @override
  int get hashCode => Object.hash(id, name, isSystem);

  @override
  String toString() =>
      'ProjectGroup(id: $id, name: $name, isSystem: $isSystem)';
}
