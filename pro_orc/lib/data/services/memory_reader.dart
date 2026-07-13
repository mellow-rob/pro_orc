import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/memory_data.dart';

/// Encodes an absolute project path to Claude's dash-separated format.
///
/// Replaces every `/`, `_`, ` `, and `.` with `-` (matching Claude's actual
/// behavior). Example: `~/code/my_app` (expanded to `/home/user/code/my_app`)
/// becomes `-home-user-code-my-app`. Dots matter too: `n3ural.a1` encodes to
/// `n3ural-a1`, otherwise memory dirs for dotted project names are missed.
String encodeProjectPath(String projectPath) {
  return projectPath
      .replaceAll('/', '-')
      .replaceAll('_', '-')
      .replaceAll(' ', '-')
      .replaceAll('.', '-');
}

/// Checks if a MEMORY.md exists at the given Claude project directory.
/// Returns [MemoryData] if found, null otherwise.
Future<MemoryData?> _checkMemoryAt(String projectDir) async {
  final memoryPath = p.join(projectDir, 'memory', 'MEMORY.md');
  final memoryFile = File(memoryPath);
  if (!await memoryFile.exists()) return null;

  final mtime = (await memoryFile.stat()).modified;
  final isStale = DateTime.now().difference(mtime) > const Duration(days: 7);

  return MemoryData(hasMemory: true, lastConsolidated: mtime, isStale: isStale);
}

/// Returns the mtime of the MEMORY.md that [readMemoryData] would find for
/// [projectPath], or null if none exists. Uses the same exact + fuzzy match
/// strategy as [readMemoryData] but only stats the file (no read), making it
/// cheap enough to call on every rescan as a cache-invalidation signature —
/// unlike the project directory's own mtime, this actually changes when
/// rem-sleep consolidates a new MEMORY.md.
Future<DateTime?> memoryFileSignature(
  String projectPath, {
  String? claudeHomeDirOverride,
}) async {
  try {
    final claudeHome =
        claudeHomeDirOverride ??
        p.join(Platform.environment['HOME']!, '.claude');
    final projectsDir = p.join(claudeHome, 'projects');
    final encodedPath = encodeProjectPath(projectPath);

    // Strategy 1: exact encoded path.
    final exactMemoryFile = File(
      p.join(projectsDir, encodedPath, 'memory', 'MEMORY.md'),
    );
    if (await exactMemoryFile.exists()) {
      return (await exactMemoryFile.stat()).modified;
    }

    // Strategy 2: fuzzy suffix match, bounded by length (mirrors
    // readMemoryData's approach for Claude's inconsistent dir naming).
    final projectsDirEntity = Directory(projectsDir);
    if (!await projectsDirEntity.exists()) return null;

    final encodedName = encodeProjectPath(p.basename(projectPath));
    final maxDirLen = encodedPath.length + 10;

    DateTime? latest;
    await for (final entity in projectsDirEntity.list()) {
      if (entity is! Directory) continue;
      final dirName = p.basename(entity.path);
      if (!dirName.endsWith(encodedName)) continue;
      if (dirName.length > maxDirLen) continue;

      final memoryFile = File(p.join(entity.path, 'memory', 'MEMORY.md'));
      if (!await memoryFile.exists()) continue;
      final mtime = (await memoryFile.stat()).modified;
      if (latest == null || mtime.isAfter(latest)) latest = mtime;
    }

    return latest;
  } catch (e) {
    developer.log(
      'Failed to compute memory file signature for $projectPath: $e',
      name: 'memory_reader',
    );
    return null;
  }
}

/// Reads Claude rem-sleep memory consolidation status for a project.
///
/// Claude creates project directories with inconsistent naming:
/// - Sometimes `$HOME/code/my_app` → `-home-user-code-my-app`
/// - Sometimes with extra suffixes appended
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
        claudeHomeDirOverride ??
        p.join(Platform.environment['HOME']!, '.claude');
    final projectsDir = p.join(claudeHome, 'projects');
    final encodedPath = encodeProjectPath(projectPath);

    // Strategy 1: Exact encoded path
    final exactDir = p.join(projectsDir, encodedPath);
    final exactResult = await _checkMemoryAt(exactDir);
    if (exactResult != null) return exactResult;

    // Strategy 2: Find dirs ending with the encoded project name
    final projectsDirEntity = Directory(projectsDir);
    if (!await projectsDirEntity.exists()) return MemoryData.empty;

    final encodedName = encodeProjectPath(p.basename(projectPath));
    final maxDirLen = encodedPath.length + 10;

    MemoryData? bestMatch;
    DateTime? bestMtime;

    await for (final entity in projectsDirEntity.list()) {
      if (entity is! Directory) continue;
      final dirName = p.basename(entity.path);

      // Must end with the encoded project name
      if (!dirName.endsWith(encodedName)) continue;

      // Must not be too long — longer dirs likely belong to a different
      // parent project that scanned this project as a subdirectory
      if (dirName.length > maxDirLen) continue;

      final result = await _checkMemoryAt(entity.path);
      if (result == null) continue;

      // Pick the most recently consolidated memory
      if (bestMatch == null ||
          (result.lastConsolidated != null &&
              (bestMtime == null ||
                  result.lastConsolidated!.isAfter(bestMtime)))) {
        bestMatch = result;
        bestMtime = result.lastConsolidated;
      }
    }

    return bestMatch ?? MemoryData.empty;
  } catch (e) {
    developer.log(
      'Failed to read memory data for $projectPath: $e',
      name: 'memory_reader',
    );
    return MemoryData.empty;
  }
}
