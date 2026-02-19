import 'gsd_data.dart';
import 'git_data.dart';

class ProjectModel {
  final String folderId; // folder name, canonical ID
  final String displayName; // PROJECT.md H1 or folder name fallback
  final String path; // absolute path
  final String? projectType; // null = unclassified
  final String? description; // from PROJECT.md or CLAUDE.md
  final GsdData? gsd; // null if no .planning/
  final GitData? git; // null if not a git repo
  final bool hasParseError; // true = show warning icon on card
  final bool isStale; // >30 days since last activity

  const ProjectModel({
    required this.folderId,
    required this.displayName,
    required this.path,
    this.projectType,
    this.description,
    this.gsd,
    this.git,
    this.hasParseError = false,
    this.isStale = false,
  });
}
