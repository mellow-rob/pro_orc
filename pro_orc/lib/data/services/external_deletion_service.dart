/// Command builders, URL parsers, and the execution layer for active
/// external-resource deletion (Vercel projects, GitHub repositories, Claude
/// memory directories).
///
/// The builders never spawn a process — they only compute the exact
/// argument list that the execution functions below pass to
/// `Process.run(command, args, runInShell: true)`. Dynamic values (project
/// names, owner/repo, paths) are ALWAYS returned as discrete list elements,
/// never interpolated into a single command string, so shell metacharacters
/// in a resource identifier cannot break out of the intended argument
/// boundary. This mirrors the escaping discipline established in
/// `deletion_service.dart` (`_appleScriptEscape` / `buildFinderDeleteScript`)
/// per the project's 2026-07-13 command-injection lesson.
library;

import 'dart:developer' as developer;
import 'dart:io';

import 'package:pro_orc/data/models/deletion_result.dart';
import 'package:pro_orc/data/models/external_resource.dart';

/// Builds the argument list for `vercel project remove <name> --yes`.
///
/// [projectName] is passed as a single, discrete argument — it is never
/// concatenated into a shell string, so metacharacters (`;`, `"`, `` ` ``,
/// `$()`) in the name cannot escape the argument boundary or chain an
/// additional command.
List<String> buildVercelDeleteArgs(String projectName) {
  return ['project', 'remove', projectName, '--yes'];
}

/// Builds the argument list for `gh repo delete <owner>/<repo> --yes`.
///
/// [ownerRepo] (already in `<owner>/<repo>` form) is passed as a single,
/// discrete argument for the same reason as [buildVercelDeleteArgs].
List<String> buildGhDeleteArgs(String ownerRepo) {
  return ['repo', 'delete', ownerRepo, '--yes'];
}

/// Derives the Vercel project name from a stored dashboard URL of the form
/// `https://vercel.com/<scope>/<project-name>` (the last non-empty path
/// segment).
///
/// Returns `null` when the name cannot be reliably derived — in particular
/// for deployment URLs of the form `<project>-<hash>.vercel.app`, which
/// encode the project name in the hostname rather than the path and cannot
/// be split from the deployment hash reliably. Callers MUST fall back to
/// hint-only display when this returns `null`.
String? deriveVercelProjectName(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();

  // Deployment URLs (*.vercel.app) do not carry a derivable dashboard
  // project name in their path — the project name is fused with a hash in
  // the hostname (e.g. "my-app-abc123.vercel.app").
  if (host.endsWith('.vercel.app') || host == 'vercel.app') {
    return null;
  }

  if (host != 'vercel.com' && !host.endsWith('.vercel.com')) {
    return null;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  return segments.last;
}

/// Derives the `<owner>/<repo>` argument from a stored GitHub URL such as
/// `https://github.com/<owner>/<repo>`.
///
/// Returns `null` when fewer than two path segments are present (owner and
/// repo cannot both be determined).
String? deriveGhOwnerRepo(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host != 'github.com' && !host.endsWith('.github.com')) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return null;

  return '${segments[0]}/${segments[1]}';
}

/// Signature matching `Process.run` — injectable so tests can simulate CLI
/// exit codes/stderr without spawning real processes or depending on the
/// machine's actual `gh`/`vercel` login state.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
    });

Future<ProcessResult> defaultProcessRunner(
  String executable,
  List<String> arguments, {
  bool runInShell = true,
}) {
  return Process.run(executable, arguments, runInShell: runInShell);
}

/// Deletes the GitHub repository at [ownerRepo] (`<owner>/<repo>`) via
/// `gh repo delete <owner>/<repo> --yes`.
///
/// [ownerRepo] is passed as a single discrete argument (see
/// [buildGhDeleteArgs]) — never interpolated into a shell string. [runner]
/// defaults to real `Process.run` and is overridable for tests.
///
/// Maps `gh`'s exit code/stderr to a [DeletionResult]:
/// - exit 0 → [DeletionResult.success]
/// - stderr mentions the missing `delete_repo` scope →
///   [DeletionResult.missingScope] (checked BEFORE the not-found check —
///   `gh` can return a 404 message on repos it cannot even see due to
///   missing scope, so a scope error must not be misread as
///   already-deleted; verified against the real locally installed `gh` CLI,
///   which emits both signals together for an unscoped token).
/// - stderr indicates the repo doesn't exist ("not found" / "404") →
///   [DeletionResult.alreadyDeleted] (FR-017 — idempotent success)
/// - stderr indicates no valid login ("not logged in" / "authentication") →
///   [DeletionResult.notAuthenticated]
/// - anything else → [DeletionResult.genericFailure] with a stderr gist
Future<DeletionResult> deleteGh(
  String uri,
  String ownerRepo, {
  ProcessRunner runner = defaultProcessRunner,
}) async {
  try {
    final result = await runner(
      'gh',
      buildGhDeleteArgs(ownerRepo),
      runInShell: true,
    );

    if (result.exitCode == 0) {
      return DeletionResult.success(uri, ExternalResourceType.github);
    }

    final stderrText = result.stderr.toString();
    final stderrLower = stderrText.toLowerCase();

    if (stderrLower.contains('delete_repo')) {
      return DeletionResult.missingScope(uri, ExternalResourceType.github);
    }
    if (stderrLower.contains('not found') || stderrLower.contains('404')) {
      return DeletionResult.alreadyDeleted(uri, ExternalResourceType.github);
    }
    if (stderrLower.contains('not logged in') ||
        stderrLower.contains('authentication') ||
        stderrLower.contains('unauthorized')) {
      return DeletionResult.notAuthenticated(uri, ExternalResourceType.github);
    }

    return DeletionResult.genericFailure(
      uri,
      ExternalResourceType.github,
      stderrText,
    );
  } catch (e) {
    developer.log(
      'Failed to delete GitHub repo $ownerRepo: $e',
      name: 'external_deletion_service',
    );
    return DeletionResult.genericFailure(
      uri,
      ExternalResourceType.github,
      e.toString(),
    );
  }
}

/// Deletes the Claude memory directory at [dir] from the filesystem.
///
/// Filesystem-only — no CLI/login dependency, matching
/// `delete_project_dialog.dart`'s `_isActivelyDeletable` treatment of
/// `claudeMemory` as always eligible (FR-005). A directory that no longer
/// exists is reported as [DeletionResult.alreadyDeleted] (FR-017), not a
/// failure.
Future<DeletionResult> deleteClaudeMemory(String uri, String dir) async {
  try {
    final directory = Directory(dir);
    if (!await directory.exists()) {
      return DeletionResult.alreadyDeleted(
        uri,
        ExternalResourceType.claudeMemory,
      );
    }

    await directory.delete(recursive: true);
    return DeletionResult.success(uri, ExternalResourceType.claudeMemory);
  } catch (e) {
    developer.log(
      'Failed to delete Claude memory dir $dir: $e',
      name: 'external_deletion_service',
    );
    return DeletionResult.genericFailure(
      uri,
      ExternalResourceType.claudeMemory,
      e.toString(),
    );
  }
}
