import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/memory_data.dart';

/// Encodes an absolute project path to Claude's dash-separated format.
///
/// Replaces every `/` and `_` with `-` (matching Claude's actual behavior).
/// Example: `~/code/my_app` (expanded to `/home/user/code/my_app`) becomes `-home-user-code-my-app`.
String encodeProjectPath(String projectPath) {
  return projectPath.replaceAll('/', '-').replaceAll('_', '-').replaceAll(' ', '-');
}

/// Checks if a MEMORY.md exists at the given Claude project directory.
/// Returns [MemoryData] if found, null otherwise.
MemoryData? _checkMemoryAt(String projectDir) {
  final memoryPath = p.join(projectDir, 'memory', 'MEMORY.md');
  final memoryFile = File(memoryPath);
  if (!memoryFile.existsSync()) return null;

  final mtime = FileStat.statSync(memoryPath).modified;
  final isStale = DateTime.now().difference(mtime) > const Duration(days: 7);

  return MemoryData(
    hasMemory: true,
    lastConsolidated: mtime,
    isStale: isStale,
  );
}

/// Reads Claude rem-sleep memory consolidation status for a project.
///
/// Claude creates project directories with inconsistent naming:
/// - Sometimes `$HOME/code/my_app` → `-home-user-code-my-app`
/// - Sometimes with suffixes like `-gsd`
/// - Sometimes from parent directories (shorter prefix)
///
/// Strategy:
/// 1. Exact encoded path match
/// 2. Scan dirs that end with the encoded project name. Filter out dirs
///    that are much longer than expected (these belong to different parent
///    projects that happen to contain a subdirectory with the same name).
///
/// Returns [MemoryData.empty] if no memory file exists or on any error.
Future<MemoryData> readMemoryData(
  String projectPath, {
  String? claudeHomeDirOverride,
}) async {
  try {
    final claudeHome =
        claudeHomeDirOverride ?? p.join(Platform.environment['HOME']!, '.claude');
    final projectsDir = p.join(claudeHome, 'projects');
    final encodedPath = encodeProjectPath(projectPath);

    // Strategy 1: Exact encoded path
    final exactDir = p.join(projectsDir, encodedPath);
    final exactResult = _checkMemoryAt(exactDir);
    if (exactResult != null) return exactResult;

    // Strategy 2: Find dirs ending with the encoded project name
    final projectsDirEntity = Directory(projectsDir);
    if (!projectsDirEntity.existsSync()) return MemoryData.empty;

    final encodedName = encodeProjectPath(p.basename(projectPath));
    final maxDirLen = encodedPath.length + 10;

    MemoryData? bestMatch;
    DateTime? bestMtime;

    for (final entity in projectsDirEntity.listSync()) {
      if (entity is! Directory) continue;
      final dirName = p.basename(entity.path);

      // Must end with the encoded project name
      if (!dirName.endsWith(encodedName)) continue;

      // Must not be too long — longer dirs likely belong to a different
      // parent project that scanned this project as a subdirectory
      if (dirName.length > maxDirLen) continue;

      final result = _checkMemoryAt(entity.path);
      if (result == null) continue;

      // Pick the most recently consolidated memory
      if (bestMatch == null ||
          (result.lastConsolidated != null &&
              (bestMtime == null || result.lastConsolidated!.isAfter(bestMtime)))) {
        bestMatch = result;
        bestMtime = result.lastConsolidated;
      }
    }

    return bestMatch ?? MemoryData.empty;
  } catch (_) {
    return MemoryData.empty;
  }
}
