import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/memory_reader.dart';

/// Detects all external resources linked to [project].
///
/// Covers:
/// - CLN-01: Notion page (from GsdData.notionUrl)
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

  // CLN-01: Notion
  try {
    final notionUrl = project.gsd?.notionUrl;
    if (notionUrl != null && notionUrl.isNotEmpty) {
      resources.add(ExternalResource(
        type: ExternalResourceType.notion,
        label: 'Notion-Seite',
        uri: notionUrl,
        hint: 'Notion-Seite manuell im Browser loeschen',
      ));
      seenUris.add(notionUrl);
    }
  } catch (_) {}

  // CLN-02: GitHub
  try {
    final githubUrl = project.git?.githubUrl;
    if (githubUrl != null && githubUrl.isNotEmpty) {
      resources.add(ExternalResource(
        type: ExternalResourceType.github,
        label: 'GitHub-Repository',
        uri: githubUrl,
        hint: 'Repository via `gh repo delete` loeschen oder manuell auf GitHub',
      ));
      seenUris.add(githubUrl);
    }
  } catch (_) {}

  // CLN-04: Claude Memory directory
  try {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final encodedPath = encodeProjectPath(project.path);
      final claudeProjectDir = p.join(home, '.claude', 'projects', encodedPath);
      if (Directory(claudeProjectDir).existsSync()) {
        resources.add(ExternalResource(
          type: ExternalResourceType.claudeMemory,
          label: 'Claude Memory',
          uri: claudeProjectDir,
          hint: 'Claude-Projektverzeichnis loeschen (Memory + Einstellungen)',
        ));
        seenUris.add(claudeProjectDir);
      }
    }
  } catch (_) {}

  // CLN-03: Figma and other URLs from .md files
  try {
    final urlResources = await _scanMdFilesForUrls(project.path, seenUris);
    resources.addAll(urlResources);
  } catch (_) {}

  return resources;
}

/// Scans .md files in the project root and .planning/ (max 2 levels deep)
/// for external URLs not already in [seenUris].
Future<List<ExternalResource>> _scanMdFilesForUrls(
  String projectPath,
  Set<String> seenUris,
) async {
  final urlRegex = RegExp(r'https?://[^\s)>\]]+');
  final skipDomains = {'localhost', '127.0.0.1', 'example.com'};
  final foundUrls = <String, ExternalResource>{};

  Future<void> scanDir(String dirPath, int depth) async {
    if (depth > 2) return;
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory && depth < 2) {
        await scanDir(entity.path, depth + 1);
      } else if (entity is File && entity.path.endsWith('.md')) {
        try {
          final stat = await entity.stat();
          if (stat.size > 100 * 1024) continue; // skip files > 100KB

          final content = await entity.readAsString();
          for (final match in urlRegex.allMatches(content)) {
            final url = match.group(0)!.trimRight().replaceAll(RegExp(r'[.,;:]+$'), '');
            if (seenUris.contains(url)) continue;
            if (foundUrls.containsKey(url)) continue;
            if (foundUrls.length >= 10) break;

            // Parse domain
            Uri? parsed;
            try {
              parsed = Uri.parse(url);
            } catch (_) {
              continue;
            }
            final host = parsed.host.toLowerCase();
            if (host.isEmpty) continue;

            // Skip noise domains
            if (skipDomains.any((d) => host == d || host.endsWith('.$d'))) {
              continue;
            }

            final resource = _classifyUrl(url, host);
            foundUrls[url] = resource;
          }
        } catch (_) {}
      }
    }
  }

  // Scan project root (depth 1) and .planning/ (depth 1 + subdirs at depth 2)
  await scanDir(projectPath, 1);
  await scanDir(p.join(projectPath, '.planning'), 1);

  return foundUrls.values.toList();
}

/// Classifies a URL by its domain into an [ExternalResource].
ExternalResource _classifyUrl(String url, String host) {
  if (host.contains('figma.com')) {
    return ExternalResource(
      type: ExternalResourceType.figma,
      label: 'Figma-Design',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  if (host.contains('firebase') || host == 'console.firebase.google.com') {
    return ExternalResource(
      type: ExternalResourceType.other,
      label: 'Firebase-Projekt',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  if (host.contains('vercel.com')) {
    return ExternalResource(
      type: ExternalResourceType.other,
      label: 'Vercel-Deployment',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  // Default: use domain as label
  // Strip leading "www." for cleaner display
  final label = host.startsWith('www.') ? host.substring(4) : host;
  return ExternalResource(
    type: ExternalResourceType.other,
    label: label,
    uri: url,
    hint: 'Manuell im Browser oeffnen und ggf. loeschen',
  );
}
