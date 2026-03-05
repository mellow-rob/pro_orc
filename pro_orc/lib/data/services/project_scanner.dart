import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gsd_parser.dart';
import 'package:pro_orc/data/services/git_reader.dart';
import 'package:pro_orc/data/services/memory_reader.dart';
import 'package:pro_orc/data/services/project_importer_service.dart';

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Thrown when the configured scan directory does not exist.
class ScanDirectoryNotFoundError implements Exception {
  final String path;
  final String message;

  const ScanDirectoryNotFoundError({
    required this.path,
    required this.message,
  });

  @override
  String toString() => 'ScanDirectoryNotFoundError: $message (path: $path)';
}

// ---------------------------------------------------------------------------
// File cache
// ---------------------------------------------------------------------------

/// Caches GSD parse results keyed by project path + STATE.md mtime.
///
/// On repeated [ProjectScanner.scanAll] calls, projects whose files have not
/// changed (same mtime on STATE.md) are returned from cache without re-parsing.
class _FileCache {
  /// Map from "path:mtime" → cached [GsdParseResult].
  final Map<String, GsdParseResult> _cache = {};

  /// Returns the cache key for a project path and its STATE.md mtime.
  String _key(String projectPath, DateTime mtime) =>
      '$projectPath:${mtime.microsecondsSinceEpoch}';

  /// Returns the cached result for [projectPath] if its STATE.md mtime matches.
  /// Returns null if not cached or if mtime has changed.
  GsdParseResult? get(String projectPath, DateTime? mtime) {
    if (mtime == null) return null;
    return _cache[_key(projectPath, mtime)];
  }

  /// Stores a parse result for [projectPath] with the given STATE.md mtime.
  void put(String projectPath, DateTime mtime, GsdParseResult result) {
    _cache[_key(projectPath, mtime)] = result;
  }

  /// Returns the current mtime of STATE.md in [projectPath], or null if absent.
  Future<DateTime?> stateMtime(String projectPath) async {
    final statePath = p.join(projectPath, '.planning', 'STATE.md');
    try {
      final stat = await FileStat.stat(statePath);
      if (stat.type == FileSystemEntityType.notFound) return null;
      return stat.modified;
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// ProjectScanner
// ---------------------------------------------------------------------------

/// Top-level orchestration service for the Phase 7 data layer.
///
/// [scanAll] scans a flat directory, parses GSD data, reads git metadata,
/// resolves project types from the DB, and returns a complete list of
/// [ProjectModel] objects sorted by [ProjectModel.displayName].
class ProjectScanner {
  final AppDatabase _db;
  final _FileCache _cache = _FileCache();

  ProjectScanner(this._db);

  /// Scans the configured (or overridden) scan directory and returns a
  /// [List<ProjectModel>] sorted by displayName.
  ///
  /// If [scanDirOverride] is provided it takes precedence over the DB config
  /// value (useful for unit tests).
  ///
  /// Throws [ScanDirectoryNotFoundError] when the scan directory does not
  /// exist or is configured as an empty string.
  Future<List<ProjectModel>> scanAll({String? scanDirOverride}) async {
    // --- 1. Resolve scan directories ---
    List<String> scanDirs;
    String gitBinary = 'git';
    List<String> ignorePatterns = [];

    if (scanDirOverride != null) {
      scanDirs = [scanDirOverride];
    } else {
      scanDirs = await _db.getScanDirs();
      final config = await _db.getConfig();
      gitBinary = config.gitBinaryPath;
      ignorePatterns = _parseIgnoreList(config.ignoreListJson);
    }

    if (scanDirs.isEmpty) {
      throw ScanDirectoryNotFoundError(
        path: '',
        message: 'No scan directories configured',
      );
    }

    // If using override, still read ignore patterns from DB
    if (scanDirOverride != null) {
      try {
        final config = await _db.getConfig();
        gitBinary = config.gitBinaryPath;
        ignorePatterns = _parseIgnoreList(config.ignoreListJson);
      } catch (_) {
        // If DB read fails, proceed with empty ignore list
      }
    }

    // --- 2. List project directories from all scan dirs ---
    final projectPaths = <String>[];
    for (final scanDir in scanDirs) {
      try {
        final paths = await _listProjectPaths(scanDir, ignorePatterns);
        projectPaths.addAll(paths);
      } on ScanDirectoryNotFoundError {
        // When using a single override, propagate the error.
        // For multi-dir configs, skip non-existent dirs gracefully.
        if (scanDirOverride != null) rethrow;
      }
    }

    if (projectPaths.isEmpty) {
      return [];
    }

    // --- 3. Parse GSD data for all projects (with cache) ---
    final gsdResults = await Future.wait(
      projectPaths.map((path) => _parseGsdWithCache(path)),
    );

    // --- 4. Read git data for all projects ---
    final gitResults = await readAllGitData(projectPaths, gitBinary: gitBinary);

    // --- 4b. Read memory data for all projects ---
    final memoryResults = await Future.wait(
      projectPaths.map((path) => readMemoryData(path)),
    );

    // --- 5. Assemble ProjectModel for each project ---
    final models = <ProjectModel>[];

    for (int i = 0; i < projectPaths.length; i++) {
      final path = projectPaths[i];
      final folderId = p.basename(path);
      final gsdResult = gsdResults[i];
      final gitData = gitResults[i];
      final memoryData = memoryResults[i];

      // Resolve project type: DB override > content heuristic
      final settings = await _db.getProjectSettings(folderId);
      final projectType = ProjectType.fromString(settings?.projectType) ??
          await _inferType(path);

      // Nullify empty GSD/git data
      final gsd = (gsdResult.gsd.isEmpty) ? null : gsdResult.gsd;
      final git = (gitData.isEmpty) ? null : gitData;

      // Compute stale
      final isStale = await _computeStale(path, git?.lastCommitDate);

      // Extract used agents from .planning/ VERIFICATION.md files
      final usedAgents = gsd != null ? await _extractUsedAgents(path) : null;

      // Scan for .md files
      final mdFiles = await _scanMdFiles(path);

      models.add(ProjectModel(
        folderId: folderId,
        displayName: gsdResult.displayName ?? folderId,
        path: path,
        projectType: projectType,
        description: gsdResult.description,
        gsd: gsd,
        git: git,
        memory: memoryData.hasMemory ? memoryData : null,
        hasParseError: gsdResult.hasParseError,
        isStale: isStale,
        usedAgents: usedAgents,
        mdFiles: mdFiles,
      ));
    }

    // --- 6. Sort by displayName ---
    models.sort((a, b) => a.displayName.compareTo(b.displayName));

    return models;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Delegates to shared [inferProjectType] from project_importer_service.
  Future<ProjectType> _inferType(String projectPath) =>
      inferProjectType(projectPath);

  /// Lists all direct child directories of [scanDir], filtering out hidden
  /// directories and those matching [ignorePatterns].
  ///
  /// Throws [ScanDirectoryNotFoundError] when [scanDir] does not exist.
  Future<List<String>> _listProjectPaths(
    String scanDir,
    List<String> ignorePatterns,
  ) async {
    final dir = Directory(scanDir);
    if (!await dir.exists()) {
      throw ScanDirectoryNotFoundError(
        path: scanDir,
        message: 'Scan directory does not exist: $scanDir',
      );
    }

    final paths = <String>[];

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is! Directory) continue;

      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (_matchesAnyIgnorePattern(name, ignorePatterns)) continue;

      // Check if this directory is itself a project (has .planning/ or .git/)
      final isProject = await _isProjectDir(entity.path);
      if (isProject) {
        paths.add(entity.path);
      } else {
        // Not a project — scan its children one level deeper
        await for (final child
            in entity.list(recursive: false, followLinks: false)) {
          if (child is! Directory) continue;
          final childName = p.basename(child.path);
          if (childName.startsWith('.')) continue;
          if (_matchesAnyIgnorePattern(childName, ignorePatterns)) continue;
          paths.add(child.path);
        }
      }
    }

    return paths;
  }

  /// Returns true if [path] looks like a project directory
  /// (has .planning/ or .git/ subdirectory).
  Future<bool> _isProjectDir(String path) async {
    final planning = Directory(p.join(path, '.planning'));
    final git = Directory(p.join(path, '.git'));
    return await planning.exists() || await git.exists();
  }

  /// Returns true if [name] matches any of the [patterns].
  ///
  /// Pattern formats:
  /// - Exact match: `node_modules` matches `node_modules`
  /// - Suffix wildcard: `build*` matches any name starting with `build`
  bool _matchesAnyIgnorePattern(String name, List<String> patterns) {
    for (final pattern in patterns) {
      if (pattern.endsWith('*')) {
        // Prefix match
        final prefix = pattern.substring(0, pattern.length - 1);
        if (name.startsWith(prefix)) return true;
      } else {
        // Exact match
        if (name == pattern) return true;
      }
    }
    return false;
  }

  /// Parses GSD data using the cache to avoid re-parsing unchanged files.
  Future<GsdParseResult> _parseGsdWithCache(String projectPath) async {
    final mtime = await _cache.stateMtime(projectPath);
    final cached = _cache.get(projectPath, mtime);
    if (cached != null) return cached;

    final result = await parseGsdData(projectPath);
    if (mtime != null) {
      _cache.put(projectPath, mtime, result);
    }
    return result;
  }

  /// Computes whether a project is stale (>30 days since last activity).
  ///
  /// - Git project: stale if [lastCommitDate] is older than 30 days
  /// - Non-git GSD project: stale if STATE.md mtime is older than 30 days
  /// - No signal: not stale (benefit of the doubt)
  Future<bool> _computeStale(String projectPath, DateTime? lastCommitDate) async {
    const threshold = Duration(days: 30);
    final now = DateTime.now();

    if (lastCommitDate != null) {
      return now.difference(lastCommitDate) > threshold;
    }

    // Non-git: check STATE.md mtime
    final statePath = p.join(projectPath, '.planning', 'STATE.md');
    try {
      final stat = await FileStat.stat(statePath);
      if (stat.type != FileSystemEntityType.notFound) {
        return now.difference(stat.modified) > threshold;
      }
    } catch (_) {
      // Ignore errors — no signal means not stale
    }

    return false;
  }

  /// Extracts agent names used in a project by scanning `.planning/` for
  /// VERIFICATION.md files containing `_Verifier: Claude (agent-name)_`
  /// or `Spawned by` references.
  Future<List<String>?> _extractUsedAgents(String projectPath) async {
    final planningDir = Directory(p.join(projectPath, '.planning', 'phases'));
    if (!await planningDir.exists()) return null;

    final agents = <String>{};
    final agentPattern = RegExp(r'Claude \(([a-z0-9-]+)\)');
    final spawnedPattern = RegExp(r'Spawned by.*?([a-z0-9]+-[a-z0-9-]+)');

    try {
      await for (final entity in planningDir.list(recursive: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.contains('VERIFICATION') && !name.contains('SUMMARY')) {
          continue;
        }

        try {
          final content = await entity.readAsString();
          for (final match in agentPattern.allMatches(content)) {
            agents.add(match.group(1)!);
          }
          for (final match in spawnedPattern.allMatches(content)) {
            agents.add(match.group(1)!);
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (agents.isEmpty) return null;
    final sorted = agents.toList()..sort();
    return sorted;
  }

  /// Role labels for known .md files in Claude Code / GSD workflows.
  static const _roleMap = <String, String>{
    'CLAUDE.md': 'Projekt-Instruktionen',
    'README.md': 'Dokumentation',
    'REQUIREMENTS.md': 'Anforderungen',
    'PROJECT.md': 'Projektvision',
    'STATE.md': 'Aktueller Stand',
    'ROADMAP.md': 'Phasen-Uebersicht',
  };

  /// Suffix-based roles for plan/phase files.
  static String? _suffixRole(String name) {
    if (name.endsWith('-PLAN.md')) return 'Ausfuehrungsplan';
    if (name.endsWith('-SUMMARY.md')) return 'Zusammenfassung';
    if (name.endsWith('-VERIFICATION.md')) return 'Verifikation';
    if (name.endsWith('-RESEARCH.md')) return 'Recherche';
    if (name.endsWith('-CONTEXT.md')) return 'Kontext';
    return null;
  }

  /// Scans a project for .md files at root and inside `.planning/` (max depth 3).
  ///
  /// Returns null if no .md files are found.
  Future<List<MdFileInfo>?> _scanMdFiles(String projectPath) async {
    final results = <MdFileInfo>[];

    // 1. Root-level .md files
    final rootDir = Directory(projectPath);
    try {
      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.endsWith('.md')) continue;
        results.add(MdFileInfo(
          name: name,
          relativePath: name,
          path: entity.path,
          role: _roleMap[name] ?? _suffixRole(name),
        ));
      }
    } catch (_) {}

    // 2. .planning/ recursive (max depth ~3)
    final planningDir = Directory(p.join(projectPath, '.planning'));
    if (await planningDir.exists()) {
      try {
        await for (final entity
            in planningDir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (!name.endsWith('.md')) continue;

          final relativePath =
              p.relative(entity.path, from: projectPath);
          // Enforce max depth (~3 levels inside .planning)
          final segments = p.split(relativePath);
          if (segments.length > 5) continue; // .planning/a/b/c/file.md = 5

          results.add(MdFileInfo(
            name: name,
            relativePath: relativePath,
            path: entity.path,
            role: _roleMap[name] ?? _suffixRole(name),
          ));
        }
      } catch (_) {}
    }

    if (results.isEmpty) return null;
    results.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return results;
  }

  /// Parses the JSON ignore list from the DB config string.
  List<String> _parseIgnoreList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            // Hidden dirs are handled separately; drop '.*' to avoid confusion
            // but leave other patterns intact
            .where((p) => p != '.*')
            .toList();
      }
    } catch (_) {
      // Malformed JSON — return empty list
    }
    return [];
  }
}
