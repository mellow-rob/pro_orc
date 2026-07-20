import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart'
    show isVercelDashboardProjectUrl;
import 'package:pro_orc/data/services/memory_reader.dart';

/// Detects all external resources linked to [project].
///
/// Covers:
/// - CLN-02: GitHub repository (from GitData.githubUrl)
/// - CLN-03: Figma and other external URLs (scanned from .md files)
/// - CLN-04: Claude Memory directory (~/.claude/projects/...)
///
/// Returns an empty list on any error. Individual detection steps are
/// wrapped separately so one failure does not abort the rest.
Future<List<ExternalResource>> detectExternalResources(
  ProjectModel project,
) async {
  final resources = <ExternalResource>[];
  final seenUris = <String>{};

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
    final urlResources = await _scanMdFilesForUrls(project.mdFiles, seenUris);
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
Future<List<ExternalResource>> _scanMdFilesForUrls(
  List<MdFileInfo>? mdFiles,
  Set<String> seenUris,
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
