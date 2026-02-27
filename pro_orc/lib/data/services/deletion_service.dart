import 'dart:io';

/// Permanently deletes a project directory from the filesystem.
/// Returns true if deletion succeeded, false if directory not found or deletion failed.
///
/// This is the rm -rf equivalent — permanent, no Papierkorb/Trash.
/// Follows the project convention of returning false on errors (not throwing).
Future<bool> deleteProject(String projectPath) async {
  final dir = Directory(projectPath);
  if (!dir.existsSync()) return false;
  try {
    await dir.delete(recursive: true);
    return true;
  } catch (_) {
    return false;
  }
}
