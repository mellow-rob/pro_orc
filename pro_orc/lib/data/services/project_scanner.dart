import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import '../models/project_model.dart';
import 'gsd_parser.dart';
import 'git_reader.dart';

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
    // --- 1. Resolve scan directory ---
    String scanDir;
    String gitBinary = 'git';
    List<String> ignorePatterns = [];

    if (scanDirOverride != null) {
      scanDir = scanDirOverride;
    } else {
      final config = await _db.getConfig();
      scanDir = config.scanDir;
      gitBinary = config.gitBinaryPath;
      ignorePatterns = _parseIgnoreList(config.ignoreListJson);
    }

    if (scanDir.isEmpty) {
      throw ScanDirectoryNotFoundError(
        path: scanDir,
        message: 'Scan directory is not configured',
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

    // --- 2. List project directories ---
    final projectPaths = await _listProjectPaths(scanDir, ignorePatterns);

    if (projectPaths.isEmpty) {
      return [];
    }

    // --- 3. Parse GSD data for all projects (with cache) ---
    final gsdResults = await Future.wait(
      projectPaths.map((path) => _parseGsdWithCache(path)),
    );

    // --- 4. Read git data for all projects ---
    final gitResults = await readAllGitData(projectPaths, gitBinary: gitBinary);

    // --- 5. Assemble ProjectModel for each project ---
    final models = <ProjectModel>[];

    for (int i = 0; i < projectPaths.length; i++) {
      final path = projectPaths[i];
      final folderId = p.basename(path);
      final gsdResult = gsdResults[i];
      final gitData = gitResults[i];

      // Resolve project type from DB
      final settings = await _db.getProjectSettings(folderId);
      final projectType = settings?.projectType;

      // Nullify empty GSD/git data
      final gsd = (gsdResult.gsd.isEmpty) ? null : gsdResult.gsd;
      final git = (gitData.isEmpty) ? null : gitData;

      // Compute stale
      final isStale = await _computeStale(path, git?.lastCommitDate);

      models.add(ProjectModel(
        folderId: folderId,
        displayName: gsdResult.displayName ?? folderId,
        path: path,
        projectType: projectType,
        description: gsdResult.description,
        gsd: gsd,
        git: git,
        hasParseError: gsdResult.hasParseError,
        isStale: isStale,
      ));
    }

    // --- 6. Sort by displayName ---
    models.sort((a, b) => a.displayName.compareTo(b.displayName));

    return models;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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
      // Directories only
      if (entity is! Directory) continue;

      final name = p.basename(entity.path);

      // Skip hidden directories
      if (name.startsWith('.')) continue;

      // Skip directories matching ignore patterns
      if (_matchesAnyIgnorePattern(name, ignorePatterns)) continue;

      paths.add(entity.path);
    }

    return paths;
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
