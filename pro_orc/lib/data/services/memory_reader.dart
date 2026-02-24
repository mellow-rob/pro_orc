import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/memory_data.dart';

/// Encodes an absolute project path to Claude's dash-separated format.
///
/// Replaces every `/` with `-`.
/// Example: `/Users/rob/code/foo` becomes `-Users-rob-code-foo`.
String encodeProjectPath(String projectPath) {
  return projectPath.replaceAll('/', '-');
}

/// Reads Claude rem-sleep memory consolidation status for a project.
///
/// Looks for `MEMORY.md` at `{claudeHome}/projects/{encodedPath}/memory/MEMORY.md`.
/// The [claudeHomeDirOverride] parameter allows tests to use a temp dir
/// instead of `~/.claude`.
///
/// Returns [MemoryData.empty] if no memory file exists or on any error.
Future<MemoryData> readMemoryData(
  String projectPath, {
  String? claudeHomeDirOverride,
}) async {
  try {
    final claudeHome =
        claudeHomeDirOverride ?? p.join(Platform.environment['HOME']!, '.claude');
    final encodedPath = encodeProjectPath(projectPath);
    final memoryPath =
        p.join(claudeHome, 'projects', encodedPath, 'memory', 'MEMORY.md');

    final memoryFile = File(memoryPath);
    if (!memoryFile.existsSync()) {
      return MemoryData.empty;
    }

    final mtime = FileStat.statSync(memoryPath).modified;
    final isStale = DateTime.now().difference(mtime) > const Duration(days: 7);

    return MemoryData(
      hasMemory: true,
      lastConsolidated: mtime,
      isStale: isStale,
    );
  } catch (_) {
    return MemoryData.empty;
  }
}
