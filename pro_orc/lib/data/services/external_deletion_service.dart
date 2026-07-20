/// Pure command builders and URL parsers for active external-resource
/// deletion (Vercel projects, GitHub repositories).
///
/// These builders never spawn a process — they only compute the exact
/// argument list that a later execution layer (Wave 4) will pass to
/// `Process.run(command, args, runInShell: true)`. Dynamic values (project
/// names, owner/repo) are ALWAYS returned as discrete list elements, never
/// interpolated into a single command string, so shell metacharacters in a
/// resource identifier cannot break out of the intended argument boundary.
/// This mirrors the escaping discipline established in
/// `deletion_service.dart` (`_appleScriptEscape` / `buildFinderDeleteScript`)
/// per the project's 2026-07-13 command-injection lesson.
library;

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
