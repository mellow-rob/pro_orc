import 'gsd_data.dart';
import 'git_data.dart';

/// Metadata for a .md file discovered in a project directory.
class MdFileInfo {
  final String name; // "STATE.md"
  final String relativePath; // ".planning/STATE.md"
  final String path; // absoluter Pfad
  final String? role; // "Aktueller Stand", "Projekt-Instruktionen", etc.

  const MdFileInfo({
    required this.name,
    required this.relativePath,
    required this.path,
    this.role,
  });
}

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
  final List<String>? usedAgents; // agent names found in .planning/ files
  final List<MdFileInfo>? mdFiles; // .md files discovered in project

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
    this.usedAgents,
    this.mdFiles,
  });
}
