import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Result of a project creation operation.
///
/// [success] is false only if the directory creation itself failed.
/// All other failures (git init, file writes) are collected in [warnings].
class ProjectCreationResult {
  final String projectPath;
  final bool success;
  final List<String> warnings;

  const ProjectCreationResult({
    required this.projectPath,
    required this.success,
    this.warnings = const [],
  });
}

/// Creates a new project directory with optional scaffolding.
///
/// Steps (in order):
/// 1. Create project directory (fails entire operation if this fails)
/// 2. GSD Skeleton: .planning/{PROJECT,STATE,ROADMAP,REQUIREMENTS}.md
/// 3. CLAUDE.md starter template
/// 4. .gitignore from template (flutter / nodejs / python)
/// 5. Research README.md (if projectType == 'research' and no GSD skeleton)
/// 6. git init + initial commit (warnings on failure, never fails overall)
///
/// All [Process.run] calls use [runInShell: true] because macOS GUI apps
/// do not inherit Homebrew PATH.
Future<ProjectCreationResult> createProject({
  required String scanDir,
  required String folderName, // Already kebab-case
  required String displayName, // Original user input
  required String projectType, // 'code' or 'research'
  bool gitInit = false,
  bool gsdSkeleton = false,
  bool claudeMd = false,
  String gitignoreTemplate = 'none', // 'flutter', 'nodejs', 'python', 'none'
}) async {
  final projectPath = path.join(scanDir, folderName);
  final warnings = <String>[];

  // --- 1. Create directory ---
  final dir = Directory(projectPath);
  if (dir.existsSync()) {
    return ProjectCreationResult(
      projectPath: projectPath,
      success: false,
      warnings: ['Ordner existiert bereits: $projectPath'],
    );
  }

  try {
    await dir.create(recursive: true);
  } catch (e) {
    return ProjectCreationResult(
      projectPath: projectPath,
      success: false,
      warnings: ['Ordner konnte nicht erstellt werden: $e'],
    );
  }

  // --- 2. GSD Skeleton ---
  if (gsdSkeleton) {
    try {
      final planningDir = Directory(path.join(projectPath, '.planning'));
      await planningDir.create(recursive: true);

      await File(path.join(planningDir.path, 'PROJECT.md')).writeAsString(
        _gsdProjectMd(displayName),
      );
      await File(path.join(planningDir.path, 'STATE.md')).writeAsString(
        _gsdStateMd(),
      );
      await File(path.join(planningDir.path, 'ROADMAP.md')).writeAsString(
        _gsdRoadmapMd(displayName),
      );
      await File(path.join(planningDir.path, 'REQUIREMENTS.md')).writeAsString(
        _gsdRequirementsMd(displayName),
      );
    } catch (e) {
      warnings.add('GSD Skeleton konnte nicht erstellt werden: $e');
    }
  }

  // --- 3. CLAUDE.md ---
  if (claudeMd) {
    try {
      await File(path.join(projectPath, 'CLAUDE.md')).writeAsString(
        _claudeMdContent(displayName),
      );
    } catch (e) {
      warnings.add('CLAUDE.md konnte nicht erstellt werden: $e');
    }
  }

  // --- 4. .gitignore ---
  if (gitignoreTemplate != 'none') {
    try {
      final content = _gitignoreContent(gitignoreTemplate);
      if (content != null) {
        await File(path.join(projectPath, '.gitignore')).writeAsString(content);
      }
    } catch (e) {
      warnings.add('.gitignore konnte nicht erstellt werden: $e');
    }
  }

  // --- 5. Research README.md ---
  if (projectType == 'research' && !gsdSkeleton) {
    try {
      await File(path.join(projectPath, 'README.md')).writeAsString(
        '# $displayName\n\n[Projektbeschreibung hier einfuegen]\n',
      );
    } catch (e) {
      warnings.add('README.md konnte nicht erstellt werden: $e');
    }
  }

  // --- 6. git init + initial commit ---
  if (gitInit) {
    final gitWarning = await _gitInitAndCommit(projectPath, displayName);
    if (gitWarning != null) {
      warnings.add(gitWarning);
    }
  }

  return ProjectCreationResult(
    projectPath: projectPath,
    success: true,
    warnings: warnings,
  );
}

// ---------------------------------------------------------------------------
// git helpers
// ---------------------------------------------------------------------------

Future<String?> _gitInitAndCommit(
    String projectPath, String displayName) async {
  try {
    final initResult = await _runWithTimeout(
      'git',
      ['init'],
      projectPath,
    );
    if (initResult.exitCode != 0) {
      return 'git init fehlgeschlagen: ${initResult.stderr}';
    }

    final addResult = await _runWithTimeout(
      'git',
      ['add', '-A'],
      projectPath,
    );
    if (addResult.exitCode != 0) {
      return 'git add fehlgeschlagen: ${addResult.stderr}';
    }

    final commitResult = await _runWithTimeout(
      'git',
      ['commit', '-m', 'Initial commit: $displayName'],
      projectPath,
    );
    if (commitResult.exitCode != 0) {
      return 'git commit fehlgeschlagen: ${commitResult.stderr}';
    }

    return null; // success
  } catch (e) {
    return 'git-Fehler: $e';
  }
}

Future<ProcessResult> _runWithTimeout(
  String executable,
  List<String> arguments,
  String workingDirectory,
) {
  final processFuture = Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  final timeoutFuture = Future<ProcessResult>.delayed(
    const Duration(seconds: 5),
    () => throw TimeoutException(
        'Git-Befehl hat zu lange gedauert', const Duration(seconds: 5)),
  );

  return Future.any([processFuture, timeoutFuture]);
}

// ---------------------------------------------------------------------------
// File content templates
// ---------------------------------------------------------------------------

String _gsdProjectMd(String displayName) => '''
# $displayName

## Beschreibung

[Projektbeschreibung hier einfuegen]

## Status

Neues Projekt, noch nicht gestartet.

## Ziele

[Projektziele hier definieren]
''';

String _gsdStateMd() => '''
# Project State

## Current Position

Phase: -
Status: Nicht gestartet

## Accumulated Context

### Decisions

[Entscheidungen werden hier dokumentiert]

### Blockers/Concerns

[Keine]

## Session Continuity

Last session: -
Stopped at: Projekt erstellt
''';

String _gsdRoadmapMd(String displayName) => '''
# Roadmap: $displayName

## Phases

[Phasen hier definieren]

---

## Milestone Overview

| Milestone | Description | Status |
|-----------|-------------|--------|
| v1.0      | MVP         | planned |
''';

String _gsdRequirementsMd(String displayName) => '''
# Requirements: $displayName

## Functional Requirements

| ID   | Requirement | Priority | Status  |
|------|-------------|----------|---------|
| F-01 | [Erste Anforderung] | high | open |

## Non-Functional Requirements

| ID   | Requirement | Priority | Status  |
|------|-------------|----------|---------|
| N-01 | [Erste nicht-funktionale Anforderung] | medium | open |

## Out of Scope

[Was explizit nicht Teil dieses Projekts ist]
''';

String _claudeMdContent(String displayName) => '''
# CLAUDE.md

## Project Overview

**$displayName** — [Projektbeschreibung hier einfuegen]

## Build & Run Commands

```bash
# [Build-Befehle hier einfuegen]
```

## Architecture

[Architektur hier beschreiben]

## Conventions

[Konventionen hier definieren]
''';

String? _gitignoreContent(String template) {
  switch (template) {
    case 'flutter':
      return '''
.dart_tool/
.packages
build/
.flutter-plugins
.flutter-plugins-dependencies
*.iml
.idea/
.vscode/
*.lock
.DS_Store
''';
    case 'nodejs':
      return '''
node_modules/
dist/
build/
.env
.env.local
*.log
.DS_Store
.vscode/
.idea/
coverage/
''';
    case 'python':
      return '''
__pycache__/
*.py[cod]
.env
.venv/
venv/
dist/
build/
*.egg-info/
.DS_Store
.idea/
.vscode/
''';
    default:
      return null;
  }
}
