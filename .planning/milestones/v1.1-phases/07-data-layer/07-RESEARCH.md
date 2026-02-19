# Phase 7: Data Layer — Research

**Researched:** 2026-02-19
**Domain:** Dart filesystem scanning, markdown parsing, git subprocess, SQLite app config (drift)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Single scan directory** — one configurable directory (default: `~/project_orchestration/`), not separate code/research dirs
- **Flat structure** — only direct children of the scan directory are projects. No recursive scanning. User will restructure existing `code/` and `project research/` subdirectories into a flat layout
- **Directories only** — loose files in the scan directory are ignored; every subdirectory is treated as a project
- **Auto-discovery** — scanner runs automatically on app start; new directories appear as projects without manual registration
- **Configurable ignore list** — patterns for directories to skip (e.g., `.*`, `node_modules`). Stored in app config
- **Local paths only** — no network/cloud mount support
- **App config location** — `~/Library/Application Support/ProOrc/` (macOS standard)
- **Configurable per project** — project type is NOT determined by parent directory; it's a setting stored in the App-DB and PROJECT.md
- **Erweiterbare Typen** — data model supports user-defined types beyond Code/Research. UI for managing types is a future phase
- **Default for new projects** — unclassified. No type assumed until user sets one
- **Dual storage with timestamp sync** — type stored in both App-DB and PROJECT.md. When values conflict, the most recently modified source wins (requires timestamp tracking)
- **PROJECT.md** — Claude decides which fields to parse based on v1.0 data model and UI needs
- **PROJECT.md name** — preferred over folder name for display. Folder name as fallback/ID
- **STATE.md** — compact overview (phase, status, progress) for cards; full details on demand
- **ROADMAP.md** — parse for phase list, milestone name, and overall phase progress per project
- **Non-GSD projects** — show name + git info + PROJECT.md data if available. No error, no warning
- **Unknown PROJECT.md fields** — ignored. Only defined fields are parsed
- **Stale indicator** — Claude decides best approach
- **Link validation** — Claude decides (extract only vs. optional background validation)
- **Cache with invalidation** — parse results cached, re-parse only when file mtime changes
- **`runInShell: true`** on all `Process.run` calls (GUI app PATH issue) PLUS configurable git binary path as fallback
- **Git data per project**: last commit message, hash, timestamp + GitHub remote URL. Nothing more
- **Parse errors** should show a warning icon on the project card (graceful degradation + visual indicator)
- **If scan directory doesn't exist or isn't readable**: clear error message + prompt to configure in settings

### Claude's Discretion

- DB technology choice (SQLite/drift, Hive/Isar, etc.)
- Which PROJECT.md fields to parse (based on v1.0 model and UI needs)
- Compact card layout field selection (balance info density vs. readability)
- Stale indicator approach (git-based, STATE.md-based, or combined)
- Link validation strategy (extract only vs. background check)
- Monorepo/nested project handling (pragmatic default)
- Git concurrency model (parallel with limit vs. sequential)
- Git timeout value

### Deferred Ideas (OUT OF SCOPE)

- UI for managing project types — user wants to create/edit types in the app. Separate UI phase
- First-run wizard — guided setup on first launch. UI phase (Phase 9 or 10)
- Network/cloud mount support — only local paths for now
- Branch info and activity stats from git — only basic git data (last commit + remote URL) for now
- Log file for scanner errors — UI-only error display for now; file logging may come later
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SCAN-01 | Dart-native scanning of the flat scan directory, listing direct-child subdirectories only | `dart:io` Directory.list(), FileSystemEntity.isDirectory(), FileStat for filtering |
| SCAN-02 | Project type detection — configurable per project via App-DB (drift); PROJECT.md as secondary source; default = unclassified | drift table `project_settings`, dual-source timestamp sync pattern |
| SCAN-03 | GSD parser reads STATE.md, ROADMAP.md, PROJECT.md — extracts status, phase, progress, next step | Regex parsing patterns from v1.0 TypeScript reference; identical data shapes confirmed |
| SCAN-04 | Notion URL extraction from `<!-- notion: URL -->` comment in PROJECT.md | Single regex `<!--\s*notion:\s*(https?://[^\s>]+)\s*-->` confirmed from v1.0 |
| SCAN-05 | Description from PROJECT.md `## What This Is` / `## Core Value` section, or CLAUDE.md fallback | Multi-pattern regex, 200-char truncation, strip bold markers — from v1.0 |
| GIT-01 | Last commit (message, hash, timestamp) via `Process.run('git', ['log', '--format=...', '-1'])` | `runInShell: true` required; format string approach avoids parsing edge cases |
| GIT-02 | Concurrent git calls with 5s timeout and Future.wait chunking (max ~5 parallel) | `Process.run` has no built-in timeout; use `Future.any([gitFuture, Future.delayed(5s)])` pattern |
| GIT-03 | GitHub URL from `git remote get-url origin` — SSH and HTTPS normalization | Regex patterns from v1.0: SSH `git@github.com:owner/repo.git` → `https://github.com/owner/repo` |
</phase_requirements>

---

## Summary

Phase 7 is a pure Dart service layer with no Flutter UI dependencies. The reference implementation (v1.0 TypeScript in `pro-orc/`) is a near-exact blueprint — all parsing logic, regex patterns, data shapes, and test strategies translate directly to Dart. The primary research work is confirming Dart equivalents for each v1.0 Node.js component.

The three core services are: (1) **ProjectScanner** — lists flat directory contents via `dart:io`, skips hidden dirs and ignore-listed names, reads mtime for cache invalidation; (2) **GsdParser** — reads STATE.md, ROADMAP.md, PROJECT.md with the same multi-pattern regex approach as v1.0; (3) **GitReader** — calls `git log` and `git remote get-url` via `Process.run` with `runInShell: true` plus a 5-second timeout wrapper.

App config (scan directory path, ignore list, git binary path) is stored in **drift** (SQLite) at `~/Library/Application Support/ProOrc/`. Drift is the recommended choice for typed, migrateable, reactive app configuration — far superior to SharedPreferences for structured data. Per-project overrides (type label, custom name) also live in drift.

**Primary recommendation:** Port v1.0 parsing logic directly to Dart — the regex patterns are identical. Add drift for config/per-project settings. Unit-test with real tmp directories (no mocking needed for filesystem; mock `Process.run` for git tests).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dart:io` | SDK built-in | Directory scanning, file reading, Process.run | No dependency needed; the standard for all dart IO |
| `drift` | ^2.31.0 | SQLite app config and per-project settings DB | Type-safe, code-gen, reactive streams, proper migrations — correct tool for structured config |
| `drift_flutter` | ^0.2.8 | drift integration for Flutter (macOS Desktop) | Simplifies connection setup; `driftDatabase()` handles macOS path automatically |
| `path_provider` | ^2.1.5 | `getApplicationSupportDirectory()` for DB path | Maps to `~/Library/Application Support/BundleID/` on macOS |
| `path` | ^1.9.0 | Path join/basename/normalize | Dart standard path manipulation; already likely in pubspec |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `test` | ^1.25.0 | Pure Dart unit tests | For service tests with no Flutter widgets — use `dart test` or `flutter test` |
| `mockito` | ^5.4.0 | Mock `Process.run` in git tests | When you need deterministic git output without shelling out in CI |
| `build_runner` | ^2.10.5 | Code gen for drift and mockito | Required at dev time; not shipped |
| `drift_dev` | ^2.31.0 | drift code generation | Required for `@DriftDatabase` annotation processing |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| drift | SharedPreferences | SharedPreferences only handles primitives — no tables, no relations, no typed queries. Wrong tool for structured config |
| drift | Hive/Isar | Hive is document-store (NoSQL); Isar is complex setup. Drift is simpler for relational config rows |
| drift | json_file config | A plain JSON file in App Support would work for simple config — simpler than drift, but no reactive streams and harder to migrate |
| `Process.run` | `git` Dart package (libgit2dart) | libgit2dart adds binary complexity; `Process.run` calls the system git directly — same approach as v1.0 and far simpler |
| `Future.wait` chunked | sequential `for` loop | Sequential is simpler and avoids all concurrency bugs; for ≤30 projects, the 5s timeout makes sequential acceptable too |

**On DB choice:** For Phase 7 (data layer only, no reactive UI yet), a simpler approach is acceptable. **Recommendation: use drift for app config from the start** since Phase 8 will add Riverpod providers that watch drift streams. Retrofitting later is unnecessary work.

**On link validation:** Extract only (no background HTTP validation). Notion URLs are trusted — they come from the user's own PROJECT.md. Validation adds network calls, complexity, and potential false positives. Extract and display; let the user click to verify.

**Installation:**
```bash
flutter pub add drift drift_flutter path_provider path
flutter pub add --dev drift_dev build_runner test mockito
```

---

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── data/
│   ├── models/
│   │   └── project_model.dart       # Dart data classes (ProjectModel, GsdData, GitData)
│   ├── services/
│   │   ├── project_scanner.dart     # Scans flat scan dir, builds ProjectModel list
│   │   ├── gsd_parser.dart          # Parses STATE.md, ROADMAP.md, PROJECT.md
│   │   └── git_reader.dart          # Process.run git calls with timeout
│   └── db/
│       ├── app_database.dart        # @DriftDatabase class + connection
│       ├── app_database.g.dart      # generated
│       └── tables/
│           ├── app_config_table.dart    # scan_dir, ignore_list, git_binary
│           └── project_settings_table.dart  # per-project type, name override
test/
├── data/
│   ├── gsd_parser_test.dart
│   ├── project_scanner_test.dart
│   └── git_reader_test.dart
```

### Pattern 1: Flat Scan with Ignore List

**What:** List direct children of scan directory, filter to directories only, skip names matching the ignore list.
**When to use:** Every app start, triggered by scanner service.

```dart
// Source: dart:io Directory API + v1.0 reference scanner.ts
import 'dart:io';
import 'package:path/path.dart' as p;

Future<List<String>> listProjectPaths({
  required String scanDir,
  required List<String> ignorePatterns,
}) async {
  final dir = Directory(scanDir);
  if (!await dir.exists()) {
    throw ScanDirectoryNotFoundError(scanDir);
  }

  final entries = await dir.list(recursive: false, followLinks: false).toList();
  final results = <String>[];

  for (final entity in entries) {
    if (entity is! Directory) continue;                     // files ignored
    final name = p.basename(entity.path);
    if (name.startsWith('.')) continue;                     // hidden dirs ignored
    if (_matchesAnyIgnorePattern(name, ignorePatterns)) continue;
    results.add(entity.path);
  }
  return results;
}

bool _matchesAnyIgnorePattern(String name, List<String> patterns) {
  // Simple glob: patterns like 'node_modules', '.*', 'build'
  // For v1: exact match or prefix '*' = "ends with". Keep it simple.
  for (final pattern in patterns) {
    if (pattern.startsWith('*')) {
      if (name.endsWith(pattern.substring(1))) return true;
    } else {
      if (name == pattern) return true;
    }
  }
  return false;
}
```

### Pattern 2: mtime-Based Cache Invalidation

**What:** Before re-parsing a file, compare its current `modified` DateTime to the cached value. Re-parse only on mismatch.
**When to use:** In GsdParser.parse() — wrap each `File.readAsString()` call.

```dart
// Source: dart:io FileStat API — https://api.flutter.dev/flutter/dart-io/FileStat-class.html
import 'dart:io';

class _FileCache {
  final Map<String, ({DateTime mtime, String content})> _cache = {};

  Future<String?> readIfChanged(String filePath) async {
    final stat = await FileStat.stat(filePath);
    if (stat.type == FileSystemEntityType.notFound) return null;

    final cached = _cache[filePath];
    if (cached != null && !stat.modified.isAfter(cached.mtime)) {
      return cached.content;  // cache hit
    }

    try {
      final content = await File(filePath).readAsString();
      _cache[filePath] = (mtime: stat.modified, content: content);
      return content;
    } catch (_) {
      return null;  // ENOENT, EACCES, mid-save — treated as missing
    }
  }
}
```

### Pattern 3: Git Reader with Timeout

**What:** Call git via `Process.run` with `runInShell: true`. Wrap with `Future.any` + `Future.delayed` for 5-second timeout.
**When to use:** Per project, concurrently with chunking (see Pattern 4).

```dart
// Source: dart:io Process API + v1.0 git-reader.ts reference
import 'dart:io';

class GitData {
  final String? lastCommitMessage;
  final String? lastCommitHash;    // 7-char short SHA
  final DateTime? lastCommitDate;
  final String? githubUrl;
  const GitData({this.lastCommitMessage, this.lastCommitHash, this.lastCommitDate, this.githubUrl});
  static const empty = GitData();
}

Future<GitData> readGitData(String projectPath, {String gitBinary = 'git'}) async {
  try {
    // git log: format=<hash>%n<date>%n<message> — three lines, unambiguous
    final logFuture = Process.run(
      gitBinary,
      ['log', '--format=%H%n%aI%n%s', '-1'],
      workingDirectory: projectPath,
      runInShell: true,        // REQUIRED: GUI app PATH doesn't include Homebrew git
    );

    final result = await Future.any([
      logFuture,
      Future.delayed(const Duration(seconds: 5)).then((_) => throw TimeoutException('git timeout')),
    ]);

    if (result.exitCode != 0) return GitData.empty;

    final lines = (result.stdout as String).trim().split('\n');
    if (lines.length < 3) return GitData.empty;

    final hash = lines[0].trim();
    final date = DateTime.tryParse(lines[1].trim());
    final message = lines.sublist(2).join('\n').trim();

    // git remote get-url origin
    final remoteResult = await Future.any([
      Process.run(gitBinary, ['remote', 'get-url', 'origin'],
          workingDirectory: projectPath, runInShell: true),
      Future.delayed(const Duration(seconds: 5)).then((_) => throw TimeoutException('git remote timeout')),
    ]);

    String? githubUrl;
    if (remoteResult.exitCode == 0) {
      githubUrl = _remoteToGithubUrl((remoteResult.stdout as String).trim());
    }

    return GitData(
      lastCommitMessage: message,
      lastCommitHash: hash.length >= 7 ? hash.substring(0, 7) : hash,
      lastCommitDate: date,
      githubUrl: githubUrl,
    );
  } catch (_) {
    return GitData.empty;  // not a git repo, timeout, or any error
  }
}

String? _remoteToGithubUrl(String remoteUrl) {
  // SSH: git@github.com:owner/repo.git
  final sshMatch = RegExp(r'git@github\.com:(.+?)(?:\.git)?$').firstMatch(remoteUrl);
  if (sshMatch != null) return 'https://github.com/${sshMatch.group(1)}';
  // HTTPS: https://github.com/owner/repo.git
  final httpsMatch = RegExp(r'https?://github\.com/(.+?)(?:\.git)?$').firstMatch(remoteUrl);
  if (httpsMatch != null) return 'https://github.com/${httpsMatch.group(1)}';
  return null;
}
```

### Pattern 4: Chunked Concurrent Git Calls

**What:** Run git reads in parallel with a concurrency cap to avoid spawning 30+ subprocesses simultaneously.
**When to use:** In ProjectScanner when enriching all discovered projects with git data.

```dart
// Source: Dart Future.wait API — standard chunking pattern
Future<List<GitData>> readAllGitData(List<String> projectPaths) async {
  const chunkSize = 5;  // max 5 concurrent git processes
  final results = <GitData>[];

  for (var i = 0; i < projectPaths.length; i += chunkSize) {
    final chunk = projectPaths.skip(i).take(chunkSize).toList();
    final chunkResults = await Future.wait(
      chunk.map((path) => readGitData(path).catchError((_) => GitData.empty)),
    );
    results.addAll(chunkResults);
  }

  return results;
}
```

### Pattern 5: GSD Parsing (State + Roadmap + Project)

**What:** Read three markdown files concurrently, apply regex patterns, combine results. Null-safe throughout.
**When to use:** Called by ProjectScanner per discovered project directory.

```dart
// Source: v1.0 parser.ts — direct Dart port. Regex patterns identical.
import 'dart:io';
import 'package:path/path.dart' as p;

class GsdParseResult {
  final String? gsdStatus;       // 'research'|'planning'|'building'|'paused'|'done'|'archived'
  final String? currentPhase;    // e.g. "3 of 5 (API Layer)"
  final String? nextStep;
  final int? phaseProgress;      // 0-100
  final String? notionUrl;
  final String? description;
  final int? phasesCompleted;
  final int? phasesTotal;
  final int? plansCompleted;
  final int? plansTotal;
  const GsdParseResult({...});
  static const empty = GsdParseResult();
}

Future<GsdParseResult> parseGsdData(String projectPath) async {
  final planningDir = p.join(projectPath, '.planning');

  // Read all three concurrently — each null-safe
  final [stateContent, roadmapContent, projectContent] = await Future.wait([
    _safeRead(p.join(planningDir, 'STATE.md')),
    _safeRead(p.join(planningDir, 'ROADMAP.md')),
    _safeRead(p.join(planningDir, 'PROJECT.md')),
  ]);

  if (stateContent == null && roadmapContent == null && projectContent == null) {
    return GsdParseResult.empty;  // no .planning/ — not a GSD project, no error
  }

  return GsdParseResult(
    ...parseState(stateContent),
    ...parseRoadmap(roadmapContent),
    ...parseProject(projectContent),
  );
}

Future<String?> _safeRead(String path) async {
  try { return await File(path).readAsString(); }
  catch (_) { return null; }
}
```

**Key regex patterns** (from v1.0 — identical in Dart):

```dart
// STATE.md — Phase (multiple field name variants)
final _phasePatterns = [
  RegExp(r'^\*\*Phase:\*\*\s*(.+)$', multiLine: true),
  RegExp(r'^\*\*Current Phase:\*\*\s*(.+)$', multiLine: true),
  RegExp(r'^Phase:\s*(.+)$', multiLine: true),
];

// STATE.md — Status (bold and plain)
final _statusPattern = RegExp(r'^\*\*Status:\*\*\s*(.+)$', multiLine: true);
final _statusPlainPattern = RegExp(r'^Status:\s*(.+)$', multiLine: true);

// STATE.md — Next Step
final _nextStepPatterns = [
  RegExp(r'^\*\*Next Action:\*\*\s*(.+)$', multiLine: true),
  RegExp(r'^\*\*Next Step:\*\*\s*(.+)$', multiLine: true),
  RegExp(r'^\*\*Nächster Schritt:\*\*\s*(.+)$', multiLine: true),
];

// ROADMAP.md — Plan checkboxes (case-insensitive)
final _planDonePattern = RegExp(r'^- \[[xX]\]\s+\d+-\d+-PLAN', multiLine: true);
final _planPendingPattern = RegExp(r'^- \[ \]\s+\d+-\d+-PLAN', multiLine: true);

// PROJECT.md — Notion URL
final _notionPattern = RegExp(r'<!--\s*notion:\s*(https?://[^\s>]+)\s*-->');

// PROJECT.md — Description (What This Is / Core Value heading)
final _descPattern = RegExp(
  r'^##\s+(?:Core Value|Kernwert|Was ist das|What This Is|What is this)\s*\n+(.+)',
  multiLine: true, caseSensitive: false,
);
```

### Pattern 6: Drift App Config Table

**What:** Store scan directory path, ignore list (JSON array), and git binary path in a drift SQLite table.
**When to use:** Read on app start; written by settings UI (future phase).

```dart
// Source: drift docs https://drift.simonbinder.eu/setup/
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// App-wide config — single row (id=1, always upsert)
class AppConfigTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scanDir => text().withDefault(Constant(''))();
  TextColumn get ignoreListJson => text().withDefault(Constant('[".*","node_modules","build"]'))();
  TextColumn get gitBinaryPath => text().withDefault(Constant('git'))();
}

// Per-project settings — keyed by folder name (canonical ID)
class ProjectSettingsTable extends Table {
  TextColumn get folderId => text()();          // folder name, e.g. "pro_orc"
  TextColumn get projectType => text().nullable()();  // 'code'|'research'|custom|null
  TextColumn get displayName => text().nullable()();  // override for PROJECT.md name
  DateTimeColumn get typeSetAt => dateTime().nullable()();  // for conflict resolution
  @override
  Set<Column> get primaryKey => {folderId};
}

@DriftDatabase(tables: [AppConfigTable, ProjectSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _connect());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _connect() {
    return driftDatabase(
      name: 'pro_orc',
      native: DriftNativeOptions(
        databaseDirectory: () async {
          final dir = await getApplicationSupportDirectory();
          return dir.path;  // ~/Library/Application Support/ProOrc/ on macOS
        },
      ),
    );
  }
}
```

### Pattern 7: Dual-Source Type Sync (PROJECT.md vs App-DB)

**What:** Project type stored in both App-DB and PROJECT.md. On conflict, the most recently modified source wins.
**When to use:** When loading project data — compare `project_settings.typeSetAt` vs PROJECT.md's file mtime.

```dart
// Conflict resolution logic
Future<String?> resolveProjectType({
  required String folderId,
  required String projectMdPath,
  required ProjectSetting? dbSetting,
  required String? projectMdType,   // parsed from PROJECT.md if present
}) async {
  if (dbSetting == null || dbSetting.projectType == null) return projectMdType;
  if (projectMdType == null) return dbSetting.projectType;

  // Both have values — compare timestamps
  final mdStat = await FileStat.stat(projectMdPath);
  final dbTime = dbSetting.typeSetAt;

  if (dbTime != null && mdStat.modified.isAfter(dbTime)) {
    return projectMdType;  // PROJECT.md was modified more recently
  }
  return dbSetting.projectType;  // DB wins
}
```

### Anti-Patterns to Avoid

- **`runInShell: false` for git**: GUI macOS apps launched outside Terminal do not inherit the user's shell PATH. Homebrew git at `/opt/homebrew/bin/git` will not be found. Always use `runInShell: true`.
- **No timeout on Process.run**: `dart:io` `Process.run` has no built-in timeout parameter. An unresponsive git server (e.g., fetching from a network mount) will hang forever. Always wrap with `Future.any` + `Future.delayed`.
- **Crashing on missing .planning/**: A project without `.planning/` is normal (non-GSD project). Treat as `GsdParseResult.empty`, never throw.
- **Throwing on non-git directory**: Many projects in the scan directory will not be git repos. Always wrap git calls in try/catch and return `GitData.empty`.
- **Using `Directory.listSync` on the scan root**: The synchronous version blocks the main isolate. Use the async `Directory.list()` with `await ... .toList()`.
- **Trusting `Process.exitCode`** for "not a git repo": exitCode 128 = not a git repo, but also other errors. Catch all exceptions; don't parse exit codes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Typed SQLite config | Custom JSON file parser | drift | Migrations, type safety, reactive streams for Phase 8 Riverpod integration |
| macOS app support dir path | Hardcode `~/Library/Application Support/` | `path_provider` + `getApplicationSupportDirectory()` | Correct for all macOS user accounts; handles sandboxed apps correctly |
| Path operations | String concatenation with `/` | `package:path` `p.join()`, `p.basename()` | Handles platform separators, trailing slashes, relative paths |
| Git output parsing line-by-line | Custom stream parser | `--format=` flag to git log | Control output shape at source; `%H%n%aI%n%s` gives hash, ISO date, subject on separate lines |

**Key insight:** The filesystem IS the database for project data. drift handles only app config + per-project overrides — not the project data itself, which lives in markdown files.

---

## Common Pitfalls

### Pitfall 1: GUI App PATH Missing Homebrew Git

**What goes wrong:** `Process.run('git', [...])` throws `ProcessException: No such file or directory` in the release `.app` build.
**Why it happens:** macOS GUI apps launched from Finder/Dock/login items inherit a minimal system PATH that does not include `/opt/homebrew/bin` where most developers have git installed.
**How to avoid:** Always pass `runInShell: true` to `Process.run`. This invokes `/bin/sh` which sources `/etc/paths` (includes `/usr/local/bin` and `/opt/homebrew/bin` via `/etc/paths.d/` on correctly configured systems). Additionally, support a configurable `gitBinaryPath` fallback (stored in app config) so users can set `/opt/homebrew/bin/git` explicitly if needed.
**Warning signs:** Works in `flutter run` (which inherits your terminal PATH) but fails in `flutter build macos` release app.

### Pitfall 2: Hanging git Process (No Timeout)

**What goes wrong:** App freezes on startup, scanning never completes.
**Why it happens:** A project directory might be on a network mount, have a git credential prompt (SSH key passphrase), or have a corrupted `.git`. `Process.run` waits indefinitely by default.
**How to avoid:** Wrap every `Process.run` call with `Future.any([gitFuture, Future.delayed(Duration(seconds: 5)).then((_) => throw TimeoutException(...))])`. Catch `TimeoutException` and return `GitData.empty`.
**Warning signs:** App hangs with spinner for >5 seconds during scan on startup.

### Pitfall 3: Scan Directory Not Flat Yet

**What goes wrong:** Scanner finds zero projects or wrong projects because the user hasn't restructured their directories.
**Why it happens:** CONTEXT.md notes user will restructure from `code/` + `project research/` to a flat layout, but this may not be done before Phase 7 tests run.
**How to avoid:** Write tests against a temp directory structure, not the real `~/project_orchestration`. The real directory integration test should be optional/guarded. Phase 7's success criteria reference the old structure — note this discrepancy. The tests need to reflect the new flat model.
**Warning signs:** Integration test discovers 0 projects or classifies all as wrong type.

**IMPORTANT NOTE:** The phase success criteria in ROADMAP.md still reference the old two-directory structure (`code/` and `project research/`). The actual implementation should target the new flat structure per CONTEXT.md decisions. The tests should be written for the flat layout.

### Pitfall 4: mtime Cache Invalidation Granularity

**What goes wrong:** Cache not invalidating after a file edit; stale data shown.
**Why it happens:** macOS HFS+ has 1-second mtime resolution; rapid saves within the same second appear as same mtime.
**How to avoid:** File watching (Phase 8) provides the real-time invalidation layer. For Phase 7's cache, mtime is sufficient — the watcher will trigger a re-scan for actual live updates. Don't over-engineer the cache; it's a scan optimization, not a live-update mechanism.
**Warning signs:** Editing STATE.md and immediately re-reading via scanner shows old data in unit tests using mock times.

### Pitfall 5: drift build_runner Code Generation

**What goes wrong:** `AppDatabase` class not found; `part 'app_database.g.dart'` not generated.
**Why it happens:** Forgot to run `dart run build_runner build` after defining tables. Or ran it before adding the `part` directive.
**How to avoid:** Run `dart run build_runner build` after every table schema change. Add a note in plan tasks. During development, use `dart run build_runner watch` for auto-generation.
**Warning signs:** Compiler error `Target of URI hasn't been generated: 'app_database.g.dart'`.

### Pitfall 6: PROJECT.md Type Field Parsing

**What goes wrong:** Project type never read from PROJECT.md correctly; always shows "unclassified".
**Why it happens:** No established convention in PROJECT.md for a `type` field — this is a new field introduced by the app. The user's existing PROJECT.md files don't have it.
**How to avoid:** For Phase 7, **do not attempt to parse project type from PROJECT.md**. The type field in PROJECT.md is written BY the app (future phase) — for now, App-DB is the only source. Default = unclassified for all projects.

---

## Code Examples

Verified patterns from official sources and v1.0 reference:

### dart:io Directory Listing

```dart
// Source: dart:io API (HIGH confidence)
final dir = Directory(scanPath);
final entities = await dir.list(recursive: false, followLinks: false).toList();
for (final entity in entities) {
  if (entity is Directory) {
    final name = p.basename(entity.path);
    // filter hidden, check ignore list
  }
}
```

### FileStat mtime Check

```dart
// Source: https://api.flutter.dev/flutter/dart-io/FileStat-class.html (HIGH confidence)
final stat = await FileStat.stat(filePath);
if (stat.type == FileSystemEntityType.notFound) return null;
final modified = stat.modified;  // DateTime
```

### drift In-Memory DB for Tests

```dart
// Source: drift README + Context7 (HIGH confidence)
// In test files — use in-memory database, no real files needed
AppDatabase createTestDatabase() {
  return AppDatabase(DatabaseConnection(NativeDatabase.memory()));
}
```

### Unit Test with Temp Directory

```dart
// Source: dart:io + v1.0 test pattern (HIGH confidence)
// Pattern from pro-orc/lib/__tests__/parser.test.ts — direct Dart equivalent
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> createTempProject(Map<String, String> files) async {
  final tmp = await Directory.systemTemp.createTemp('gsd_test_');
  final planningDir = Directory(p.join(tmp.path, '.planning'));
  await planningDir.create(recursive: true);
  for (final entry in files.entries) {
    await File(p.join(planningDir.path, entry.key)).writeAsString(entry.value);
  }
  return tmp;
}

test('extracts phase from **Phase:** format', () async {
  final tmp = await createTempProject({
    'STATE.md': '**Phase:** 3 of 5 (API Layer)\n',
  });
  addTearDown(() => tmp.delete(recursive: true));

  final result = await parseGsdData(tmp.path);
  expect(result.currentPhase, equals('3 of 5 (API Layer)'));
});
```

### GSD Status Derivation

```dart
// Source: v1.0 parser.ts deriveStatus() — direct port (HIGH confidence)
String? deriveStatus(String statusRaw) {
  final s = statusRaw.toLowerCase();
  if (s.isEmpty) return null;
  if (s.contains('complete') || s.contains('komplett')) return 'done';
  if (s.contains('archived') || s.contains('archiviert')) return 'archived';
  if (s.contains('paused') || s.contains('pausiert')) return 'paused';
  if (s.contains('research') || s.contains('recherche')) return 'research';
  if (s.contains('planning') || s.contains('planung')) return 'planning';
  if (s.contains('progress') || s.contains('fortschritt')) return 'building';
  if (RegExp(r'phase\s+\d', caseSensitive: false).hasMatch(s)) return 'building';
  return null;
}
```

### ROADMAP.md Progress Calculation

```dart
// Source: v1.0 parser.ts parseRoadmap() — direct port (HIGH confidence)
// Plans: "- [x] 07-01-PLAN.md" or "- [ ] 07-01-PLAN.md"
final planDonePattern = RegExp(r'^- \[[xX]\]\s+\d+-\d+-PLAN', multiLine: true);
final planPendingPattern = RegExp(r'^- \[ \]\s+\d+-\d+-PLAN', multiLine: true);

final done = planDonePattern.allMatches(content).length;
final pending = planPendingPattern.allMatches(content).length;
final total = done + pending;
final progress = total > 0 ? (done / total * 100).round() : null;
```

---

## Data Model Recommendation (Claude's Discretion)

Based on v1.0 types.ts and UI needs, the `ProjectModel` data class for Phase 7:

```dart
// Models for Phase 7 — pure Dart data classes, no Flutter dependency
class ProjectModel {
  final String folderId;         // folder name, canonical ID ("pro_orc")
  final String displayName;      // PROJECT.md name or folder name fallback
  final String path;             // absolute path
  final String? projectType;     // null = unclassified; 'code'|'research'|custom
  final String? description;     // from PROJECT.md or CLAUDE.md
  final GsdData? gsd;            // null if no .planning/
  final GitData? git;            // null if not a git repo
  final bool hasParseError;      // true = show warning icon on card
}

class GsdData {
  final String? status;          // 'research'|'planning'|'building'|'paused'|'done'|'archived'
  final String? currentPhase;    // "3 of 5 (API Layer)"
  final String? nextStep;
  final int? phaseProgress;      // 0-100
  final String? notionUrl;
  final int? phasesCompleted;
  final int? phasesTotal;
  final int? plansCompleted;
  final int? plansTotal;
}

class GitData {
  final String? lastCommitMessage;
  final String? lastCommitHash;  // 7-char short SHA
  final DateTime? lastCommitDate;
  final String? githubUrl;       // https://github.com/owner/repo
}
```

**Card layout fields (compact):** `displayName`, `projectType`, `gsd.status`, `gsd.currentPhase`, `gsd.phaseProgress`, `gsd.nextStep`, `git.lastCommitDate`, `hasParseError`.

**Stale indicator recommendation:** Use `git.lastCommitDate` for code projects (reliable, no extra reads). For research/non-git projects, use `STATE.md` file mtime (from `FileStat.stat`). A project is "stale" if its most recent activity signal is >30 days old. This covers both types without extra complexity.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sqflite` for Flutter SQLite | `drift` with `drift_flutter` | drift_flutter released ~2024 | Simpler setup, code-gen, reactive, works on all platforms |
| Hardcoded `~/project_orchestration/code/` and `research/` | Single configurable flat scan dir | Phase 7 CONTEXT.md decision | Scanner must read scan dir from app config, not hardcode |
| `Process.run('git', ...)` without timeout | Wrap with `Future.any` + `Future.delayed(5s)` | Ongoing pattern — always needed | Prevents infinite hangs in GUI apps |

**Deprecated/outdated:**
- `sqflite`: Works but requires more boilerplate than drift; no code generation; not recommended for new projects.
- Hardcoded two-directory scan from v1.0: Replaced by configurable flat single directory per CONTEXT.md.

---

## Open Questions

1. **PROJECT.md `## Name` field**
   - What we know: The v1.0 reference does not parse a `## Name` or `name:` field from PROJECT.md. The folder name IS the display name in v1.0.
   - What's unclear: CONTEXT.md says "PROJECT.md name preferred over folder name." Which heading/field should the parser look for?
   - Recommendation: Parse the H1 heading (`# Project Name`) from PROJECT.md as the display name. Fallback to folder name. This is the most natural markdown convention.

2. **Ignore list storage format**
   - What we know: Stored in app config (drift). Default patterns: `['.*', 'node_modules', 'build']`.
   - What's unclear: Should ignore patterns support full glob syntax or just prefix/suffix matching?
   - Recommendation: For v1: exact match or `*`-prefix suffix match only. Real glob matching (via `glob` package) is overkill for this use case.

3. **`dart run build_runner` in CI / test environment**
   - What we know: drift requires generated `.g.dart` files to compile. These must be committed to git or generated on each build.
   - What's unclear: Will CI and other devs need to run build_runner before `flutter test`?
   - Recommendation: Commit the generated `app_database.g.dart` to git (standard practice for Dart projects). Include a plan task to run `dart run build_runner build` as part of setup.

4. **Scan directory restructuring timing**
   - What we know: User plans to flatten `code/` and `project research/` into a flat directory before this phase runs.
   - What's unclear: Tests against real filesystem will find zero projects if restructuring isn't done.
   - Recommendation: Integration tests use temp directories. Real-filesystem smoke test is optional/skipped if flat structure not yet present.

---

## Sources

### Primary (HIGH confidence)
- `pro-orc/lib/parser.ts`, `scanner.ts`, `git-reader.ts`, `types.ts` — v1.0 TypeScript reference implementation, direct Dart port basis
- `pro-orc/lib/__tests__/parser.test.ts`, `scanner.test.ts` — v1.0 test suite, confirms test patterns and regex correctness
- [drift setup docs](https://drift.simonbinder.eu/setup/) — pubspec, table definition, code generation steps
- [drift platform support](https://drift.simonbinder.eu/platforms/) — macOS desktop confirmed, NativeDatabase, no extra setup
- [dart:io FileStat class](https://api.flutter.dev/flutter/dart-io/FileStat-class.html) — mtime property confirmed
- [dart:io Process.run](https://api.flutter.dev/flutter/dart-io/Process/run.html) — `runInShell`, `workingDirectory` parameters confirmed

### Secondary (MEDIUM confidence)
- [WebSearch: drift macOS] — drift 2.31.0, drift_flutter 0.2.8, path_provider 2.1.5 versions confirmed current
- [WebSearch: Process.run runInShell macOS] — confirms `/bin/sh` used; sandbox must be disabled (already done in Phase 6)
- [WebSearch: file package dart] — `MemoryFileSystem` available for filesystem mocking if needed (not required given tmp dir approach)

### Tertiary (LOW confidence)
- [WebSearch: Future.wait chunking] — chunked pattern verified as standard Dart community approach, but no single authoritative source; pattern is logically sound

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — drift, dart:io, path_provider all confirmed via official docs and Context7
- Architecture: HIGH — v1.0 reference implementation is a near-exact blueprint; regex patterns validated against real GSD files in this repo
- Pitfalls: HIGH — `runInShell: true` requirement confirmed from STATE.md + official Process.run docs; timeout pattern is standard Dart
- Data model: HIGH — derived from v1.0 types.ts with CONTEXT.md adjustments

**Research date:** 2026-02-19
**Valid until:** 2026-03-21 (30 days — drift and dart:io are stable APIs)
