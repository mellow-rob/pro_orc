import 'dart:developer' as developer;
import 'dart:io';

import 'package:pro_orc/data/models/deletion_result.dart';
import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';

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

/// Actively deletes each resource in [resources] via its matching CLI/
/// filesystem call, INDEPENDENTLY of the others (FR-008) — one resource's
/// failure never prevents another's attempt, and callers are expected to
/// run [deleteProject] (local folder/Trash) and the DB row deletion
/// regardless of these results, since this function's job is scoped
/// entirely to the external resources.
///
/// Figma (and any other hint-only type) resources in [resources] are
/// SKIPPED — no delete call is ever made for them (FR-010, permanent —
/// the public Figma API does not support file deletion). Only
/// `vercel`/`github`/`claudeMemory` are actually dispatched.
///
/// [onResult] fires once per attempted resource, in no particular order,
/// as soon as its [DeletionResult] is available — the dialog uses this to
/// flip each row from spinner to success/failure in place rather than
/// waiting for the whole batch.
///
/// [ghRunner] is injectable (mirroring the project's `whichCommand`
/// convention) so tests can simulate CLI outcomes without spawning real
/// processes.
Future<List<DeletionResult>> deleteSelectedExternalResources(
  List<ExternalResource> resources, {
  void Function(DeletionResult result)? onResult,
  ProcessRunner ghRunner = defaultProcessRunner,
}) async {
  final results = <DeletionResult>[];

  for (final resource in resources) {
    DeletionResult? result;

    try {
      switch (resource.type) {
        case ExternalResourceType.github:
          final ownerRepo = deriveGhOwnerRepo(resource.uri);
          result = ownerRepo == null
              ? DeletionResult.genericFailure(
                  resource.uri,
                  resource.type,
                  'GitHub-Repository konnte aus der URL nicht abgeleitet werden',
                )
              : await deleteGh(resource.uri, ownerRepo, runner: ghRunner);
        case ExternalResourceType.claudeMemory:
          result = await deleteClaudeMemory(resource.uri, resource.uri);
        case ExternalResourceType.vercel:
        case ExternalResourceType.figma:
        case ExternalResourceType.other:
          // Vercel active deletion, and Figma/other (permanently
          // hint-only per FR-010), are not dispatched here.
          continue;
      }
    } catch (e) {
      developer.log(
        'Failed to delete external resource ${resource.uri}: $e',
        name: 'deletion_service',
      );
      result = DeletionResult.genericFailure(
        resource.uri,
        resource.type,
        e.toString(),
      );
    }

    results.add(result);
    onResult?.call(result);
  }

  return results;
}
