import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart'
    show deriveVercelProjectName, isVercelDashboardProjectUrl;
import 'package:pro_orc/data/services/memory_reader.dart';
import 'package:pro_orc/data/services/vercel_detection_service.dart';

/// In-memory, process-lifetime cache of `orgId` -> resolved team slug (or
/// `null` for "resolution attempted and failed"). A Vercel team's slug
/// essentially never changes during an app session, so this avoids shelling
/// out to `vercel teams list` once per project every time the Links tab (or
/// the delete dialog) is opened — see
/// `2026-07-23-vercel-url-uses-orgid-not-slug.md`. Deliberately a simple
/// static map, not persisted to disk: it only needs to survive within one
/// running app instance.
final Map<String, String?> _teamSlugCache = {};

/// Clears [_teamSlugCache]. Test-only — production code never needs to
/// invalidate this cache mid-session (a team's slug doesn't change), but
/// tests exercising different resolution outcomes for the same `orgId`
/// fixture must not leak a cached result from one test into the next.
@visibleForTesting
void resetVercelTeamSlugCacheForTesting() {
  _teamSlugCache.clear();
}

/// Resolves [orgId] to its Vercel dashboard URL slug via [service],
/// consulting/populating [_teamSlugCache] first so the CLI is invoked at
/// most once per distinct `orgId` per app session. Never throws — returns
/// `null` on any resolution failure (see
/// [VercelDetectionService.resolveTeamSlug]).
Future<String?> _resolveTeamSlugCached(
  String orgId,
  VercelDetectionService service,
) async {
  if (_teamSlugCache.containsKey(orgId)) {
    return _teamSlugCache[orgId];
  }
  final slug = await service.resolveTeamSlug(orgId);
  _teamSlugCache[orgId] = slug;
  return slug;
}

/// Detects all external resources linked to [project].
///
/// Covers:
/// - CLN-02: GitHub repository (from GitData.githubUrl)
/// - CLN-03: Figma and other external URLs (scanned from .md files)
/// - CLN-04: Claude Memory directory (~/.claude/projects/...)
/// - CLN-05: Vercel project (from the CLI's own `.vercel/project.json`)
///
/// [vercelDetectionService] resolves a Vercel team's opaque `orgId` to its
/// dashboard URL slug (injectable for tests; defaults to the real CLI).
///
/// Returns an empty list on any error. Individual detection steps are
/// wrapped separately so one failure does not abort the rest.
Future<List<ExternalResource>> detectExternalResources(
  ProjectModel project, {
  VercelDetectionService vercelDetectionService =
      const VercelDetectionService(),
}) async {
  final resources = <ExternalResource>[];
  final seenUris = <String>{};
  // Secondary dedup key for Vercel resources specifically: the synthetic
  // `.vercel/project.json` URL and a human-written `.md` dashboard URL for
  // the SAME project can legitimately differ byte-for-byte (opaque orgId vs.
  // team slug, or CLI slug-resolution failing) — comparing by `projectName`
  // catches that duplicate even when `seenUris` (exact-string) doesn't. See
  // 2026-07-23-vercel-url-uses-orgid-not-slug.
  final seenVercelProjectNames = <String>{};

  // CLN-02: GitHub
  try {
    final githubUrl = project.git?.githubUrl;
    if (githubUrl != null && githubUrl.isNotEmpty) {
      resources.add(
        ExternalResource(
          type: ExternalResourceType.github,
          label: 'GitHub-Repository',
          uri: githubUrl,
          hint:
              'Repository via `gh repo delete` loeschen oder manuell auf GitHub',
        ),
      );
      seenUris.add(githubUrl);
    }
  } catch (e) {
    developer.log(
      'Failed to detect GitHub resource: $e',
      name: 'resource_detector',
    );
  }

  // CLN-05: Vercel, from the CLI's own `.vercel/project.json` — a
  // structured ground-truth source (written by `vercel link`), unlike the
  // .md text scan below which only ever finds a Vercel project if a README
  // happens to self-link its own deployment URL (the uncommon case, not the
  // common one — see 2026-07-21-vercel-detection-requires-md-link). Read
  // directly via project.path: ProjectScanner skips hidden directories
  // during scan, so `.vercel/` is never reachable via project.mdFiles.
  try {
    final vercelResource = await _detectVercelProjectJson(
      project.path,
      vercelDetectionService,
    );
    if (vercelResource != null && !seenUris.contains(vercelResource.uri)) {
      resources.add(vercelResource);
      seenUris.add(vercelResource.uri);
      final projectName = deriveVercelProjectName(vercelResource.uri);
      if (projectName != null) seenVercelProjectNames.add(projectName);
    }
  } catch (e) {
    developer.log(
      'Failed to detect .vercel/project.json resource: $e',
      name: 'resource_detector',
    );
  }

  // CLN-04: Claude Memory directory
  try {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final encodedPath = encodeProjectPath(project.path);
      final claudeProjectDir = p.join(home, '.claude', 'projects', encodedPath);
      if (Directory(claudeProjectDir).existsSync()) {
        resources.add(
          ExternalResource(
            type: ExternalResourceType.claudeMemory,
            label: 'Claude Memory',
            uri: claudeProjectDir,
            hint: 'Claude-Projektverzeichnis loeschen (Memory + Einstellungen)',
          ),
        );
        seenUris.add(claudeProjectDir);
      }
    }
  } catch (e) {
    developer.log(
      'Failed to detect Claude memory resource: $e',
      name: 'resource_detector',
    );
  }

  // CLN-03: Figma and other URLs from .md files.
  // Reuses project.mdFiles (already discovered by ProjectScanner._scanMdFiles)
  // instead of re-walking the directory tree — avoids scanning .planning/ twice.
  try {
    final urlResources = await _scanMdFilesForUrls(
      project.mdFiles,
      seenUris,
      seenVercelProjectNames,
    );
    resources.addAll(urlResources);
  } catch (e) {
    developer.log(
      'Failed to scan .md files for URLs: $e',
      name: 'resource_detector',
    );
  }

  return resources;
}

/// Extracts external URLs from the given [mdFiles] that are not already in
/// [seenUris]. Stops after 10 URLs.
///
/// Only URLs matching a known resource domain (see [_classifyUrl]) are
/// considered at all — generic documentation/marketing domains (e.g.
/// nextjs.org) are not "resources to clean up" and are skipped entirely
/// rather than listed as a generic hint-only entry (previously the
/// `_classifyUrl` fallback branch; removed as part of
/// 2026-07-20-delete-dialog-resource-over-detection — that fallback is what
/// caused doc-link floods on every scaffold README). This also makes the
/// previously-considered "dedup by domain" unnecessary: with the fallback
/// gone, a domain only ever produces an entry when it matches a specific,
/// cleanup-relevant resource pattern, and a project can legitimately link
/// several distinct resources under the same domain (e.g. two different
/// `vercel.com/{scope}/{project}` dashboards for prod + preview) — deduping
/// by domain would incorrectly drop the second one.
///
/// [seenVercelProjectNames] additionally suppresses a Vercel entry whose
/// derived project name was already emitted by `.vercel/project.json`
/// detection, even when the two URLs differ byte-for-byte (opaque orgId vs.
/// team slug) — see 2026-07-23-vercel-url-uses-orgid-not-slug. Mutated
/// in-place as new Vercel entries are found here, so two distinct md-scanned
/// Vercel URLs for the same project name (unlikely, but possible) also dedup
/// against each other, not just against the `.vercel/project.json` entry.
Future<List<ExternalResource>> _scanMdFilesForUrls(
  List<MdFileInfo>? mdFiles,
  Set<String> seenUris,
  Set<String> seenVercelProjectNames,
) async {
  if (mdFiles == null || mdFiles.isEmpty) return [];

  final urlRegex = RegExp(r'https?://[^\s)>\]]+');
  final foundUrls = <String, ExternalResource>{};

  for (final mdFile in mdFiles) {
    if (foundUrls.length >= 10) break;

    final file = File(mdFile.path);
    try {
      final stat = await file.stat();
      if (stat.size > 100 * 1024) continue; // skip files > 100KB

      final content = await file.readAsString();
      for (final match in urlRegex.allMatches(content)) {
        final url = match
            .group(0)!
            .trimRight()
            .replaceAll(RegExp(r'[.,;:]+$'), '');
        if (seenUris.contains(url)) continue;
        if (foundUrls.containsKey(url)) continue;
        if (foundUrls.length >= 10) break;

        // Parse domain
        Uri? parsed;
        try {
          parsed = Uri.parse(url);
        } catch (e) {
          developer.log(
            'Skipping unparsable URL "$url": $e',
            name: 'resource_detector',
          );
          continue;
        }
        final host = parsed.host.toLowerCase();
        if (host.isEmpty) continue;

        final resource = _classifyUrl(url, host, parsed);
        if (resource == null) continue; // not a known resource domain

        if (resource.type == ExternalResourceType.vercel) {
          final projectName = deriveVercelProjectName(resource.uri);
          if (projectName != null) {
            if (seenVercelProjectNames.contains(projectName)) {
              continue; // same Vercel project already found, different URL form
            }
            seenVercelProjectNames.add(projectName);
          }
        }

        foundUrls[url] = resource;
      }
    } catch (e) {
      developer.log(
        'Failed to read md file ${mdFile.path}: $e',
        name: 'resource_detector',
      );
    }
  }

  return foundUrls.values.toList();
}

/// Classifies a URL by its domain into an [ExternalResource], or returns
/// `null` if the domain is not a known, cleanup-relevant resource service.
///
/// Deliberately an allowlist (Figma, Vercel, Firebase — GitHub is sourced
/// separately from `GitData.githubUrl`, never from `.md` text) rather than a
/// denylist of "noise" domains: a denylist grows forever and still lets any
/// unlisted documentation/marketing domain (nextjs.org, MDN, npm, etc.)
/// through as a generic `other` entry. Framework scaffold READMEs
/// (`create-next-app` and similar) routinely link many such doc pages, which
/// flooded the deletion dialog before this fix
/// (2026-07-20-delete-dialog-resource-over-detection).
ExternalResource? _classifyUrl(String url, String host, Uri parsed) {
  if (host == 'figma.com' || host.endsWith('.figma.com')) {
    return ExternalResource(
      type: ExternalResourceType.figma,
      label: 'Figma-Design',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  // Real Firebase project consoles/hosting only — exact/suffix host
  // matching. The previous `host.contains('firebase')` also matched
  // `firebase.google.com/docs/...` documentation links, misclassifying them
  // as "Firebase-Projekt" entries.
  if (host == 'firebase.google.com' ||
      host == 'console.firebase.google.com' ||
      host.endsWith('.firebaseapp.com') ||
      host.endsWith('.web.app')) {
    // firebase.google.com itself is the marketing/docs site, not a project
    // console — only its console subdomain and hosted-project domains
    // count as a real, cleanup-relevant resource.
    if (host == 'firebase.google.com') return null;
    return ExternalResource(
      type: ExternalResourceType.other,
      label: 'Firebase-Projekt',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  if (host == 'vercel.com' || host.endsWith('.vercel.com')) {
    // Path-validated: only a real `<scope>/<project>` dashboard URL
    // classifies as an actively-deletable Vercel project. Boilerplate
    // links like `vercel.com/new?utm_...` (shipped by every
    // create-next-app README) do not validate and are dropped entirely —
    // they are not a linked project, just a generic "deploy" call to
    // action.
    if (!isVercelDashboardProjectUrl(url)) return null;
    return ExternalResource(
      type: ExternalResourceType.vercel,
      label: 'Vercel-Projekt',
      uri: url,
      hint:
          'Vercel-Projekt via `vercel project remove` loeschen oder '
          'manuell im Dashboard',
    );
  }

  // Deployment URLs (<project>-<hash>.vercel.app) do not carry a derivable
  // dashboard project name and stay hint-only (see
  // external_deletion_service.dart::deriveVercelProjectName).
  if (host.endsWith('.vercel.app') || host == 'vercel.app') {
    return ExternalResource(
      type: ExternalResourceType.other,
      label: 'Vercel-Deployment',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  // Not a known resource domain — skip entirely (see doc comment above).
  return null;
}

/// Reads `<projectPath>/.vercel/project.json` (written by `vercel link`) and,
/// if present and valid, returns an actively-deletable Vercel resource.
///
/// Unlike [_classifyUrl] (which only ever fires on a literal URL found in
/// project prose), this reads Vercel's own structured link metadata
/// directly from disk — so it works even when the project's `.md` files
/// never mention the deployment URL at all, which is the common case, not
/// the exception (2026-07-21-vercel-detection-requires-md-link).
///
/// The resource's `uri` is a `https://vercel.com/<scope>/<name>` dashboard
/// URL rather than a made-up custom scheme: this keeps it a perfectly
/// ordinary input to [isVercelDashboardProjectUrl] / `deriveVercelProjectName`
/// (both already validate and parse `vercel.com/<scope>/<project>` paths —
/// no separate code path needed for deletion).
///
/// `<scope>` must be the team's human-readable URL **slug**
/// (e.g. `roberts-projects-fb13711c`), not the opaque `orgId`
/// (e.g. `team_yABWsykG53iYgFAWXpvnYn7m`) stored in `project.json` — Vercel
/// dashboard URLs 404 on the opaque id even for a correctly logged-in team
/// member. [vercelDetectionService] resolves `orgId` -> slug via
/// `vercel teams list` (cached per `orgId` for the app session, see
/// [_teamSlugCache]); see 2026-07-23-vercel-url-uses-orgid-not-slug for the
/// full incident writeup.
///
/// Slug resolution can fail (CLI not installed, not logged in, network
/// down, timeout) — [detectExternalResources] must never hang or crash on
/// that. On failure this falls back to the pre-fix `orgId`-scoped URL: it
/// stays non-routable (same as today, no new regression) but the resource
/// is still listed and still correctly attributed for deletion purposes.
/// The `.md`/`.vercel/project.json` duplicate-chip case in that fallback
/// path is caught by the caller's `projectName`-based dedup instead of URL
/// equality (see [detectExternalResources]'s `seenVercelProjectNames`).
///
/// Returns `null` (silently, no throw) when `.vercel/project.json` does not
/// exist, is not valid JSON, or has no non-empty `projectName` — mirroring
/// the error-tolerance of the other detection steps in
/// [detectExternalResources].
Future<ExternalResource?> _detectVercelProjectJson(
  String projectPath,
  VercelDetectionService vercelDetectionService,
) async {
  final file = File(p.join(projectPath, '.vercel', 'project.json'));
  if (!await file.exists()) return null;

  Map<String, dynamic> data;
  try {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) return null;
    data = decoded;
  } catch (e) {
    developer.log(
      'Skipping invalid ${file.path}: $e',
      name: 'resource_detector',
    );
    return null;
  }

  final projectName = data['projectName'];
  if (projectName is! String || projectName.isEmpty) return null;

  final orgId = data['orgId'];
  String? scope;
  if (orgId is String && orgId.isNotEmpty) {
    scope = await _resolveTeamSlugCached(orgId, vercelDetectionService);
    // Resolution failed — fall back to the opaque id so the resource is
    // still listed (non-routable, matching pre-fix behavior) rather than
    // dropped or left to crash the detection pipeline.
    scope ??= orgId;
  }
  final uri = scope != null
      ? 'https://vercel.com/$scope/$projectName'
      : 'https://vercel.com/_/$projectName';

  return ExternalResource(
    type: ExternalResourceType.vercel,
    label: 'Vercel-Projekt',
    uri: uri,
    hint:
        'Vercel-Projekt via `vercel project remove` loeschen oder '
        'manuell im Dashboard',
  );
}
