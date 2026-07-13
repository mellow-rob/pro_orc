import 'dart:developer' as developer;
import 'dart:io';

/// Result of reading a project's display name + description from its root
/// markdown files.
class ProjectMetadata {
  final String? displayName;
  final String? description;

  const ProjectMetadata({this.displayName, this.description});

  static const empty = ProjectMetadata();
}

// PROJECT.md / CLAUDE.md — H1 heading (first match)
final _rH1 = RegExp(r'^#\s+(.+)$', multiLine: true);

// PROJECT.md / CLAUDE.md — Description section heading then first paragraph
final _rDescSection = RegExp(
  r'^##\s+(?:Core Value|Kernwert|Was ist das|What This Is|What is this|Project Overview|Project Purpose|Projektbeschreibung|One-Liner)\s*\n+([\s\S]+?)(?:\n\n|\n##|$)',
  multiLine: true,
  caseSensitive: false,
);

// Fallback: first non-empty paragraph after H1 heading (no ## required)
final _rAfterH1 = RegExp(r'^#\s+.+\n+([^\n#][^\n]*)', multiLine: true);

// Strip bold markers **text**
final _rBold = RegExp(r'\*\*([^*]+)\*\*');

/// Reads a project's display name and description from `.planning/PROJECT.md`
/// or root `PROJECT.md` (if present), falling back to `CLAUDE.md`. Returns
/// [ProjectMetadata.empty] when none of these exist or yield usable content.
Future<ProjectMetadata> readProjectMetadata(String projectPath) async {
  String? displayName;
  String? description;

  final projectContent =
      await _safeRead('$projectPath/.planning/PROJECT.md') ??
      await _safeRead('$projectPath/PROJECT.md');
  if (projectContent != null) {
    final h1 = _rH1.firstMatch(projectContent);
    if (h1 != null) displayName = h1.group(1)?.trim();
    description = _extractDescription(projectContent);
  }

  if (description == null) {
    final claudeContent = await _safeRead('$projectPath/CLAUDE.md');
    if (claudeContent != null) {
      if (displayName == null) {
        final h1 = _rH1.firstMatch(claudeContent);
        if (h1 != null) {
          final name = h1.group(1)?.trim();
          // Don't use generic "CLAUDE.md" as display name
          if (name != null && name != 'CLAUDE.md') displayName = name;
        }
      }
      description = _extractDescription(claudeContent);
    }
  }

  return ProjectMetadata(displayName: displayName, description: description);
}

/// Reads a file safely; returns null on any error.
Future<String?> _safeRead(String path) async {
  try {
    return await File(path).readAsString();
  } catch (e) {
    developer.log('Failed to read $path: $e', name: 'project_metadata_reader');
    return null;
  }
}

/// Extracts a description from content using the standard heading patterns.
/// Falls back to first paragraph after H1 if no matching section found.
String? _extractDescription(String content) {
  // Strategy 1: Known section headings
  final descMatch = _rDescSection.firstMatch(content);
  String? desc;
  if (descMatch != null) {
    desc = descMatch.group(1)?.trim() ?? '';
    desc = desc.split('\n\n').first.trim();
  }

  // Strategy 2: First paragraph after H1
  if (desc == null || desc.isEmpty) {
    final h1Match = _rAfterH1.firstMatch(content);
    if (h1Match != null) {
      desc = h1Match.group(1)?.trim();
    }
  }

  if (desc == null || desc.isEmpty) return null;
  desc = desc.replaceAllMapped(_rBold, (m) => m.group(1)!);
  if (desc.length > 500) desc = desc.substring(0, 500);
  // Filter out placeholder text
  if (desc.contains('[Projektbeschreibung hier einfuegen]')) return null;
  return desc.isEmpty ? null : desc;
}
