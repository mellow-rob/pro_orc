import 'package:pro_orc/data/models/memory_data.dart';

/// Encodes an absolute project path to Claude's dash-separated format.
///
/// Replaces every `/` with `-`.
/// Example: `/Users/rob/code/foo` becomes `-Users-rob-code-foo`.
String encodeProjectPath(String projectPath) {
  throw UnimplementedError('encodeProjectPath not yet implemented');
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
  throw UnimplementedError('readMemoryData not yet implemented');
}
