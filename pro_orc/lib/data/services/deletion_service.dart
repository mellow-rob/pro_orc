import 'dart:developer' as developer;
import 'dart:io';

/// Escapes a value to sit safely inside a double-quoted AppleScript string
/// literal: backslashes first (so the later quote-escape isn't doubled),
/// then double quotes.
String _appleScriptEscape(String value) {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

/// Builds the AppleScript command that tells Finder to move [projectPath] to
/// the Trash. Pure and exposed for testing so the escaping of the path is
/// verifiable without spawning a process.
String buildFinderDeleteScript(String projectPath) {
  final escaped = _appleScriptEscape(projectPath);
  return 'tell application "Finder" to delete POSIX file "$escaped"';
}

/// Moves a project directory to the macOS Trash (Papierkorb) instead of
/// permanently deleting it. Returns true if the move succeeded, false if the
/// directory was not found or the move failed.
///
/// Uses Finder via `osascript` so the directory lands in the Trash exactly as
/// if the user had dragged it there (undo-able, respects Trash permissions).
/// Falls back to `false` (no permanent deletion) if osascript fails — the
/// caller is expected to surface an error message rather than silently
/// falling back to `rm -rf`.
Future<bool> deleteProject(String projectPath) async {
  final dir = Directory(projectPath);
  if (!await dir.exists()) return false;

  try {
    final result = await Process.run('osascript', [
      '-e',
      buildFinderDeleteScript(projectPath),
    ], runInShell: true);

    if (result.exitCode != 0) {
      developer.log(
        'Failed to move $projectPath to Trash (exit ${result.exitCode}): ${result.stderr}',
        name: 'deletion_service',
      );
      return false;
    }

    return true;
  } catch (e) {
    developer.log(
      'Failed to move $projectPath to Trash: $e',
      name: 'deletion_service',
    );
    return false;
  }
}
