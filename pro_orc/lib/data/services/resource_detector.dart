import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
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
Future<List<ExternalResource>> _scanMdFilesForUrls(
  List<MdFileInfo>? mdFiles,
  Set<String> seenUris,
) async {
  if (mdFiles == null || mdFiles.isEmpty) return [];

  final urlRegex = RegExp(r'https?://[^\s)>\]]+');
  final skipDomains = {'localhost', '127.0.0.1', 'example.com'};
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

        // Skip noise domains
        if (skipDomains.any((d) => host == d || host.endsWith('.$d'))) {
          continue;
        }

        final resource = _classifyUrl(url, host);
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

  if (host.contains('firebase')) {
    return ExternalResource(
      type: ExternalResourceType.other,
      label: 'Firebase-Projekt',
      uri: url,
      hint: 'Manuell im Browser oeffnen und ggf. loeschen',
    );
  }

  if (host == 'vercel.com' || host.endsWith('.vercel.com')) {
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
