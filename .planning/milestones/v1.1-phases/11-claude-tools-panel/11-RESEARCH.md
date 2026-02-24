# Phase 11: Claude Tools Panel - Research

**Researched:** 2026-02-23
**Domain:** File-system discovery + Flutter/Riverpod UI panel
**Confidence:** HIGH — all data sources directly inspected on disk

## Summary

Phase 11 adds the Claude Tools tab, which auto-discovers Skills, Plugins, and MCP servers from `~/.claude/` and displays them in three vertical sections with mini GlassCard cards. The implementation follows the exact same layer pattern as Phases 6–10: a pure Dart service reads from disk, a Riverpod FutureProvider provides data, and a ConsumerStatefulWidget renders it.

The file formats are fully known from direct inspection of `~/.claude/` on this machine. Skill metadata lives in YAML frontmatter inside `~/.claude/skills/*/SKILL.md` (case-insensitive fallback to `skill.md`). Plugin metadata is split between `~/.claude/plugins/installed_plugins.json` (versions, install paths) and `~/.claude/settings.json` (which plugins are enabled, via `enabledPlugins` map). Plugin descriptions come from `<installPath>/.claude-plugin/plugin.json`. MCP server data comes exclusively from `~/.claude/settings.json` → `mcpServers` (which is currently an empty object on this machine — the note about "only global" is confirmed correct). The tab needs a dedicated watcher on `~/.claude/` to trigger re-scans reactively.

The n3urala1 color system currently has only two accent families (cyan, fuchsia). Phase 11 requires three different accent colors for the three tool types. The planner must either extend `AppColors` with new token families (amber/emerald recommended from OKLCH) or use hardcoded `Color` constants for tool-type accents within the tab only. Both are valid; the research recommends adding tokens to keep the system consistent.

**Primary recommendation:** Model the `ClaudeToolsScanner` exactly like `ProjectScanner` — pure Dart, `dart:io` only, returns a typed result model. Add a dedicated `claudeToolsWatcherProvider` (keepAlive, watches `~/.claude/`). Add `claudeToolsProvider` (FutureProvider invalidated by the watcher). Extend `AppColors` with amber tokens for Skills, emerald for Plugins, keeping cyan for MCP.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Card-Layout & Gruppierung
- Drei Sektionen untereinander (nicht Tabs): Skills, Plugins, MCP-Server — vertikal scrollbar
- Kleinere Mini-Cards (GlassCard-Stil aber kompakter als Projekt-Cards) — mehr Tools pro Zeile
- Eigene Akzentfarbe pro Typ (Skills, Plugins, MCP jeweils unterschiedlich — aus n3urala1-System)
- Sektions-Überschriften: Icon + Text + Anzahl (z.B. "🔧 Skills (7)")
- Sektionen immer offen, kein Accordion
- Alphabetische Sortierung innerhalb jeder Sektion
- Suchfeld oben im Tab — filtert alle drei Sektionen live, nur nach Name

#### Erkennung & Metadaten
- **Skills**: Name + Beschreibung + Homepage-URL aus `~/.claude/skills/*/SKILL.md` YAML-Frontmatter
- **Plugins**: Name + Marketplace + Version + Enabled-Status aus `installed_plugins.json` + `settings.json` enabledPlugins; Beschreibung aus Cache-Dateien lesen wenn verfügbar
- **MCP-Server**: Name + Command/URL aus `~/.claude/settings.json` mcpServers — nur globale, keine projekt-spezifischen
- Skills ohne SKILL.md oder Frontmatter: Claude's Discretion (Fallback-Logik)

#### Interaktion & Aktionen
- **Skill-Cards**: Finder öffnen (Skill-Verzeichnis) + Homepage im Browser öffnen
- **Plugin-Cards**: Marketplace-Link öffnen (URL aus Marketplace-Info ableiten)
- **MCP-Server-Cards**: Config-Datei (settings.json) im Editor öffnen
- Kein Detail-Panel bei Card-Klick — alles Wichtige direkt auf der Card sichtbar
- Suchfeld filtert nur nach Name (nicht Beschreibung)

#### Leer- & Sonderfälle
- Komplett leerer Tab: Hilfetext mit Anleitung (was Skills, Plugins, MCP-Server sind + wie installieren)
- Pro Sektion eigener Empty State (z.B. "Keine Skills installiert") — leere Sektionen bleiben sichtbar
- Live-Aktualisierung via File-Watcher auf `~/.claude/` — konsistent mit Code/Research-Tabs
- Fehler (z.B. nicht lesbare Dateien): dezenter Hinweis am Ende der betroffenen Sektion

### Claude's Discretion
- Reihenfolge der drei Sektionen (Skills/Plugins/MCP)
- Fallback für Skills ohne SKILL.md (Ordnername vs. überspringen)
- Exakte Farben pro Typ aus dem n3urala1-System
- Mini-Card Dimensionen und Grid-Konfiguration
- Empty-State Text und Anleitungsinhalt
- Marketplace-URL Ableitung aus Plugin-Metadaten

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-01 | Auto-Discovery von Skills aus `~/.claude/` | SkillScanner reads `~/.claude/skills/*/SKILL.md` YAML frontmatter — format fully verified on disk |
| TOOL-02 | Auto-Discovery von MCP Servers aus `~/.claude/` | `~/.claude/settings.json` → `mcpServers` object; confirmed present (currently empty, ready for data) |
| TOOL-03 | Auto-Discovery von Plugins aus `~/.claude/` | `installed_plugins.json` + `settings.json.enabledPlugins` + per-plugin `plugin.json` for description |
| TOOL-04 | Anzeige mit Name, Typ, Beschreibung pro Tool | ClaudeToolModel with typed fields; three card variants use accent color to signal type |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dart:io` | SDK | File reading, Directory.list(), Platform.environment | Already used everywhere in services |
| `flutter_riverpod` | 3.2.1 | FutureProvider + StreamProvider for reactive data | Project standard, already present |
| `watcher` | 1.2.1 | DirectoryWatcher for `~/.claude/` live updates | Already in pubspec, used by WatcherService |
| `url_launcher` | 6.3.2 | Open homepage/marketplace links in browser | Already present, used by QuickActionsService |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dart:convert` | SDK | `jsonDecode` for installed_plugins.json, settings.json | JSON parsing — no extra dep needed |
| Custom YAML frontmatter parser | (hand-rolled) | Extract `name:`, `description:`, `homepage:` from `---` blocks | Frontmatter is simple key: value — no yaml package needed, avoids new dep |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled frontmatter parser | `yaml` pub package | `yaml` package adds a dep for 3 simple fields; hand-rolling is safer and mirrors GsdParser regex approach |
| Separate watcher for `~/.claude/` | Reuse existing watcherProvider | watcherProvider watches scan dirs (from DB), not `~/.claude/`; a new watcher is required |

**Installation:** No new packages needed — all required libraries are already in `pubspec.yaml`.

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── data/
│   ├── models/
│   │   └── claude_tool_model.dart     # SkillData, PluginData, McpServerData + ClaudeToolsData
│   └── services/
│       └── claude_tools_scanner.dart  # Pure Dart, no Flutter imports
├── features/
│   └── claude_tools/
│       ├── claude_tools_tab.dart      # ConsumerStatefulWidget (replaces stub)
│       ├── skill_card.dart            # Mini GlassCard for Skills
│       ├── plugin_card.dart           # Mini GlassCard for Plugins
│       └── mcp_server_card.dart       # Mini GlassCard for MCP servers
├── providers/
│   ├── claude_tools_watcher_provider.dart   # StreamProvider<WatchEvent> for ~/.claude/
│   └── claude_tools_provider.dart           # FutureProvider<ClaudeToolsData>
└── theme/
    └── n3_colors.dart                 # ADD amber + emerald token families
```

### Pattern 1: Data Model Design
**What:** Typed model hierarchy, no "Dto" suffix, `.empty` factory for error path
**When to use:** All data from disk — same conventions as `ProjectModel`, `GsdData`, `GitData`

```dart
// Pure Dart, no Flutter imports
class SkillData {
  final String id;           // folder name (canonical)
  final String name;         // from frontmatter or folder name fallback
  final String? description; // from frontmatter
  final String? homepage;    // from frontmatter
  final String path;         // absolute path to skill dir

  const SkillData({required this.id, required this.name, this.description, this.homepage, required this.path});
}

class PluginData {
  final String key;          // "context7@claude-plugins-official"
  final String name;         // left side of '@'
  final String marketplace;  // right side of '@'
  final String? version;     // from installed_plugins.json
  final bool enabled;        // from settings.json enabledPlugins
  final String? description; // from installPath/.claude-plugin/plugin.json
  final String? marketplaceUrl; // derived from known_marketplaces.json

  const PluginData({...});
}

class McpServerData {
  final String name;         // key from mcpServers object
  final String command;      // "command" field or "url" for HTTP servers
  final McpServerType type;  // stdio | http | sse

  const McpServerData({...});
}

enum McpServerType { stdio, http, sse }

class ClaudeToolsData {
  final List<SkillData> skills;
  final List<PluginData> plugins;
  final List<McpServerData> mcpServers;
  final bool hasError;

  const ClaudeToolsData({required this.skills, required this.plugins, required this.mcpServers, this.hasError = false});
  static const empty = ClaudeToolsData(skills: [], plugins: [], mcpServers: []);
}
```

### Pattern 2: Scanner Service (Pure Dart)
**What:** ClaudeToolsScanner with three private scan methods, mirrors ProjectScanner shape
**When to use:** Always — business logic in services, not providers

```dart
// Source: Mirrors pro_orc/lib/data/services/project_scanner.dart pattern
import 'dart:io';
import 'dart:convert';

class ClaudeToolsScanner {
  final String claudeDir;

  ClaudeToolsScanner() : claudeDir = '${Platform.environment['HOME'] ?? '/Users/rob'}/.claude';

  Future<ClaudeToolsData> scanAll() async {
    try {
      final skills = await _scanSkills();
      final plugins = await _scanPlugins();
      final mcpServers = await _scanMcpServers();
      return ClaudeToolsData(skills: skills, plugins: plugins, mcpServers: mcpServers);
    } catch (e) {
      return const ClaudeToolsData.empty.copyWith(hasError: true);
    }
  }

  Future<List<SkillData>> _scanSkills() async { ... }
  Future<List<PluginData>> _scanPlugins() async { ... }
  Future<List<McpServerData>> _scanMcpServers() async { ... }
}
```

### Pattern 3: Watcher Provider (keepAlive)
**What:** Dedicated StreamProvider watching `~/.claude/` — same pattern as watcherProvider but different directory
**When to use:** Claude tools data needs reactive refresh on any `~/.claude/` change

```dart
// Source: Mirrors pro_orc/lib/providers/watcher_provider.dart
final claudeToolsWatcherProvider = StreamProvider<WatchEvent>((ref) async* {
  ref.keepAlive();
  final home = Platform.environment['HOME'] ?? '/Users/rob';
  final service = WatcherService('$home/.claude');
  ref.onDispose(service.dispose);
  yield* service.events;
});
```

### Pattern 4: FutureProvider with ref.listen invalidation
**What:** FutureProvider that re-runs scanAll() on any watcher event
**When to use:** Stateless reactive pattern — identical to projectsProvider

```dart
// Source: Mirrors pro_orc/lib/providers/projects_provider.dart
final claudeToolsProvider = FutureProvider<ClaudeToolsData>((ref) async {
  ref.listen(claudeToolsWatcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });
  return ClaudeToolsScanner().scanAll();
});
```

### Pattern 5: Color Tokens for Three Tool Types
**What:** The n3urala1 system has cyan (Code tab) and fuchsia (Research tab). Claude Tools needs three distinct accent families.

**Recommendation:** Add amber (Skills), emerald (Plugins), violet (MCP) to `AppColors`. OKLCH values:
- Amber: `oklch(0.78 0.17 85)` → `Color(0xFFF5B800)` — Skills (warm, "knowledge")
- Emerald: `oklch(0.72 0.19 155)` → `Color(0xFF00C97A)` — Plugins (green, "installed/active")
- Violet: `oklch(0.68 0.24 290)` → `Color(0xFF9D68F0)` — MCP servers (purple, "infrastructure")

**Minimal alternative** (no AppColors change): Use hardcoded `Color` constants inside the claude_tools feature only. Less principled but avoids touching the shared theme file.

**Recommendation: Add tokens to AppColors** — one `Hi/mid/Lo` set per new family suffices for cards.

### Pattern 6: YAML Frontmatter Parsing
**What:** Hand-rolled parser, same style as GsdParser regex approach
**When to use:** Reading `name:`, `description:`, `homepage:` from skill SKILL.md files

Key observations from surveying all 7 skills on disk:
- Frontmatter is always delimited by `---` on its own line
- Values can be quoted (description with colons) or unquoted
- `description` may span a single quoted line with internal colons (handle with RegExp)
- Files may be `SKILL.md` OR `skill.md` — check both, SKILL.md first
- Some skills have NO `homepage:` field (most don't) — field is optional

```dart
// Simple frontmatter extractor (no yaml package needed)
Map<String, String> _parseFrontmatter(String content) {
  final result = <String, String>{};
  final lines = content.split('\n');
  bool inFrontmatter = false;
  int dashCount = 0;
  for (final line in lines) {
    if (line.trim() == '---') {
      dashCount++;
      inFrontmatter = dashCount == 1;
      if (dashCount == 2) break;
      continue;
    }
    if (!inFrontmatter) continue;
    final colonIdx = line.indexOf(':');
    if (colonIdx < 0) continue;
    final key = line.substring(0, colonIdx).trim();
    var value = line.substring(colonIdx + 1).trim();
    // Strip surrounding quotes
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}
```

### Pattern 7: Plugin Marketplace URL Derivation
**What:** Derive a GitHub URL for each plugin from `known_marketplaces.json`
**Format:** Plugin key = `"pluginName@marketplaceId"` → lookup `marketplaceId` in `known_marketplaces.json` → get `source.repo` → URL = `https://github.com/{repo}`

```
"context7@claude-plugins-official"
  → marketplace "claude-plugins-official"
  → repo "anthropics/claude-plugins-official"
  → URL "https://github.com/anthropics/claude-plugins-official"
```

This is always a GitHub repo link, not a plugin-specific page. Acceptable as-is — opens the marketplace source which lists the plugin.

### Pattern 8: MCP Server Data from settings.json
**What:** `mcpServers` in `~/.claude/settings.json` contains a map of name → config
**Format observed:** Currently empty `{}` on this machine. Structure (from plugin `.mcp.json` files which share same schema):
- `stdio` type: `{ "command": "npx", "args": [...] }` — display command
- `http` type: `{ "type": "http", "url": "https://..." }` — display URL
- `sse` type: similar to http

Note: Plugin-contributed MCP servers (those in installed plugin `.mcp.json` files) are separate from the global `mcpServers` in settings.json. The user decision says "nur globale" — meaning only `settings.json` mcpServers, not plugin-injected ones.

### Pattern 9: Tab Layout Structure
**What:** Vertically scrollable column with three sections; search bar at top

```
ClaudeToolsTab
├── SearchBar (TextField, filters all sections by name)
├── SingleChildScrollView
│   └── Column
│       ├── _SectionHeader("Skills", count, icon)
│       ├── _ToolGrid(skills, card: SkillCard)     ← wrap layout or fixed grid
│       ├── _SectionEmptyState() if no skills
│       ├── _SectionHeader("Plugins", count, icon)
│       ├── _ToolGrid(plugins, card: PluginCard)
│       ├── _SectionEmptyState() if no plugins
│       ├── _SectionHeader("MCP-Server", count, icon)
│       ├── _ToolGrid(mcpServers, card: McpServerCard)
│       └── _SectionEmptyState() if no mcp servers
└── _FullEmptyState() if ALL three sections empty
```

**Recommended section order:** Skills → Plugins → MCP servers (most common → least common for users)

### Pattern 10: Mini-Card Dimensions
**What:** Smaller than CodeProjectCard/ResearchProjectCard. More items per row.
**Recommendation:**
- Card width: ~220–260px (vs ~340px for project cards)
- Card padding: 12px (vs 16–20px for project cards)
- Grid: `Wrap` with spacing, or `GridView.builder` with crossAxisCount auto-computed via LayoutBuilder
- Content: Name (bold, accent color), type badge or icon, description (2-line max, overflow ellipsis), action buttons row

**Preferred: Wrap widget** — simpler than GridView for variable-count items, already understood pattern.

### Anti-Patterns to Avoid
- **Importing Flutter in the scanner service** — `ClaudeToolsScanner` must be pure Dart (testable in isolates)
- **Watching entire `~/.claude/` recursively** — `DirectoryWatcher` already handles subdirs; watch the root `~/.claude/` dir
- **Blocking UI thread on file I/O** — all scanner methods must be `async` with `await`
- **Crashing on missing files** — every `File.readAsString()` must be wrapped in try/catch, return null/empty on error
- **Assuming `mcpServers` is non-empty** — it's currently `{}` on this machine, scanner must handle empty gracefully
- **Case-sensitive SKILL.md lookup** — check both `SKILL.md` and `skill.md`; some skills only have `skill.md`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Custom JSON parser | `dart:convert` jsonDecode | Already in SDK, handles all edge cases |
| URL opening | Process.run('open') | `url_launcher` launchUrl | Already in project, handles macOS/Linux/Windows differences |
| File watching | inotify wrapper | `watcher` package + WatcherService | Already in project, has debounce + error suppression |
| YAML parsing | Full YAML spec | Hand-rolled frontmatter only | Frontmatter only uses key: value — full YAML adds 3 spec-compliance edge cases not needed here |

**Key insight:** The hard parts (file watching with debounce, URL launching, JSON parsing) are already solved. This phase is primarily about reading JSON + simple text parsing, then wiring up the existing widget + provider patterns.

## Common Pitfalls

### Pitfall 1: skill.md vs SKILL.md Case Sensitivity
**What goes wrong:** Scanner only looks for `SKILL.md`, misses skills that have `skill.md` (lowercase)
**Why it happens:** Directory listing returns exact case; `File.existsSync()` on case-sensitive FS fails
**How to avoid:** Check `SKILL.md` first, fall back to `skill.md`; on macOS (case-insensitive FS) this won't fail but good practice for correctness
**Warning signs:** `vf-brand` and similar skills appear missing in UI

### Pitfall 2: Plugin Description Fallback Chain
**What goes wrong:** Description is `null` for some plugins if only checking one source
**Why it happens:** Description lives in `installPath/.claude-plugin/plugin.json` — file may not exist for externally-installed plugins
**How to avoid:** Try `installPath/.claude-plugin/plugin.json` → fall back to `null` (show no description). Never crash.
**Warning signs:** Cards showing empty description when plugin.json exists

### Pitfall 3: installed_plugins.json Array-of-Versions Structure
**What goes wrong:** Each plugin key maps to a **list** of install entries (not a single object)
**Why it happens:** Same plugin could theoretically be installed multiple times (different scopes/versions)
**How to avoid:** Always take `entries[0]` — the most recent install; verify list is non-empty before accessing
**Warning signs:** RangeError on plugin scan

### Pitfall 4: mcpServers Currently Empty
**What goes wrong:** Assuming `mcpServers` always has content, showing broken UI
**Why it happens:** `~/.claude/settings.json` has `mcpServers: {}` on this machine
**How to avoid:** Treat empty `mcpServers` as normal, show section empty state
**Warning signs:** Test environment has no MCP data — test explicitly with empty map

### Pitfall 5: AppColors Has Only Two Accent Families
**What goes wrong:** Three tool types need three distinct accent colors, but AppColors only has cyan + fuchsia
**Why it happens:** Tab was designed with two tabs (Code/Research) in mind
**How to avoid:** Either extend AppColors (preferred) with new token families before building cards, or use hardcoded Colors and note the tech debt
**Warning signs:** Two of the three card types look identical in color

### Pitfall 6: Watcher on `~/.claude/` Has Subdirectory Depth
**What goes wrong:** DirectoryWatcher may emit events for deeply nested cache dirs (plugin cache updates trigger constant rescans)
**Why it happens:** `~/.claude/plugins/cache/` is modified on every plugin update; watcher sees all events
**How to avoid:** Apply a path filter in the scanner's stream — only react to changes in `skills/`, `plugins/installed_plugins.json`, `plugins/known_marketplaces.json`, `settings.json`. Or accept some false-positive rescans (cheap operation).
**Warning signs:** Tab continuously reloading when other Claude Code sessions run

### Pitfall 7: Frontmatter Description with Colons
**What goes wrong:** `description: "key: value"` splits incorrectly at first colon
**Why it happens:** Simple `split(':')` breaks quoted values containing colons
**How to avoid:** Split only at first colon: `line.indexOf(':')` + `line.substring(colonIdx + 1)`, then strip quotes
**Warning signs:** image-to-video description truncated at "model selection"

## Code Examples

### Reading installed_plugins.json
```dart
// Source: Direct inspection of ~/.claude/plugins/installed_plugins.json
Future<List<PluginData>> _scanPlugins() async {
  final installedPath = '$claudeDir/plugins/installed_plugins.json';
  final settingsPath = '$claudeDir/settings.json';
  final marketplacesPath = '$claudeDir/plugins/known_marketplaces.json';

  try {
    final installedRaw = await File(installedPath).readAsString();
    final settingsRaw = await File(settingsPath).readAsString();

    final installed = jsonDecode(installedRaw) as Map<String, dynamic>;
    final settings = jsonDecode(settingsRaw) as Map<String, dynamic>;
    final enabledPlugins = (settings['enabledPlugins'] as Map<String, dynamic>?) ?? {};
    final pluginsMap = (installed['plugins'] as Map<String, dynamic>?) ?? {};

    // Load marketplace URLs (optional — graceful if missing)
    Map<String, dynamic> marketplaces = {};
    try {
      final mRaw = await File(marketplacesPath).readAsString();
      marketplaces = jsonDecode(mRaw) as Map<String, dynamic>;
    } catch (_) {}

    final result = <PluginData>[];
    for (final entry in pluginsMap.entries) {
      final key = entry.key;                          // "context7@claude-plugins-official"
      final installs = entry.value as List<dynamic>;
      if (installs.isEmpty) continue;
      final first = installs[0] as Map<String, dynamic>;

      final parts = key.split('@');
      final name = parts[0];
      final marketplaceId = parts.length > 1 ? parts[1] : '';

      final installPath = first['installPath'] as String? ?? '';
      final version = first['version'] as String?;
      final enabled = (enabledPlugins[key] as bool?) ?? false;

      // Description from plugin.json in cache
      String? description;
      try {
        final pjPath = '$installPath/.claude-plugin/plugin.json';
        final pjRaw = await File(pjPath).readAsString();
        final pj = jsonDecode(pjRaw) as Map<String, dynamic>;
        description = pj['description'] as String?;
      } catch (_) {}

      // Marketplace URL from known_marketplaces.json
      String? marketplaceUrl;
      final mktInfo = marketplaces[marketplaceId] as Map<String, dynamic>?;
      final repo = (mktInfo?['source'] as Map<String, dynamic>?)?['repo'] as String?;
      if (repo != null) marketplaceUrl = 'https://github.com/$repo';

      result.add(PluginData(
        key: key, name: name, marketplace: marketplaceId,
        version: version, enabled: enabled,
        description: description, marketplaceUrl: marketplaceUrl,
      ));
    }
    return result..sort((a, b) => a.name.compareTo(b.name));
  } catch (_) {
    return [];
  }
}
```

### Reading MCP servers from settings.json
```dart
// Source: Direct inspection of ~/.claude/settings.json
Future<List<McpServerData>> _scanMcpServers() async {
  try {
    final raw = await File('$claudeDir/settings.json').readAsString();
    final settings = jsonDecode(raw) as Map<String, dynamic>;
    final mcpServers = (settings['mcpServers'] as Map<String, dynamic>?) ?? {};

    return mcpServers.entries.map((entry) {
      final name = entry.key;
      final config = entry.value as Map<String, dynamic>;
      final typeStr = config['type'] as String?;
      McpServerType type;
      String command;
      if (typeStr == 'http') {
        type = McpServerType.http;
        command = config['url'] as String? ?? '';
      } else if (typeStr == 'sse') {
        type = McpServerType.sse;
        command = config['url'] as String? ?? '';
      } else {
        type = McpServerType.stdio;
        final cmd = config['command'] as String? ?? '';
        final args = (config['args'] as List<dynamic>?)?.join(' ') ?? '';
        command = args.isNotEmpty ? '$cmd $args' : cmd;
      }
      return McpServerData(name: name, command: command, type: type);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  } catch (_) {
    return [];
  }
}
```

### Opening settings.json in default editor
```dart
// Source: Mirrors QuickActionsService.openInFinder pattern
Future<void> openConfigInEditor(String claudeDir) async {
  final path = '$claudeDir/settings.json';
  // 'open' on macOS opens with default app for .json (typically VS Code if registered)
  await Process.run('open', [path], runInShell: true);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No Claude Tools tab (stub only) | Full discovery panel | Phase 11 | Replaces `claude_tools_tab.dart` stub entirely |
| No accent color for tools | Three new accent families in AppColors | Phase 11 | Requires AppColors extension + theme update |

**Deprecated/outdated:**
- The stub `ClaudeToolsTab` in `claude_tools_tab.dart`: Replace entirely, don't wrap.

## Open Questions

1. **Recommended section order (Skills → Plugins → MCP)**
   - What we know: User left this as Claude's Discretion
   - What's unclear: No explicit preference
   - Recommendation: Skills first (users have fewest), then Plugins (most actively installed), then MCP (infrastructure, rarely zero but harder to grok). Order: **Skills → Plugins → MCP-Server**

2. **Fallback for Skills without SKILL.md**
   - What we know: User left this as Claude's Discretion; `enhance-prompt` has both SKILL.md and skill.md (they're identical); `vf-brand` has only `skill.md` (lowercase)
   - What's unclear: Are there skills with no SKILL.md at all?
   - Recommendation: If no SKILL.md or skill.md found → **use folder name as display name, show no description** (don't skip the skill). This is the most forgiving fallback.

3. **Amber/Emerald/Violet vs. alternative color assignments**
   - What we know: Three accent families needed; AppColors has cyan + fuchsia
   - What's unclear: User hasn't chosen specific hues
   - Recommendation: **Amber for Skills** (warm/knowledge), **Emerald for Plugins** (green/active), **Violet for MCP** (purple/infrastructure). These are visually distinct from existing cyan/fuchsia.

4. **Whether to filter watcher events by path**
   - What we know: `~/.claude/plugins/cache/` gets written on plugin updates, causing frequent events
   - What's unclear: How often does this happen in practice?
   - Recommendation: Accept false-positive rescans for now (scan is cheap JSON read). Add path filtering only if performance issues arise.

5. **Test strategy for ClaudeToolsScanner**
   - What we know: Existing tests use real temp dirs (`createTempProject()`) with no mocking
   - Recommendation: Follow same pattern — create temp `~/.claude/`-shaped directories in tests, write fixture JSON/SKILL.md files, assert scanner output. No mocking needed.

## Sources

### Primary (HIGH confidence)
- Direct file system inspection: `~/.claude/settings.json` — confirmed `mcpServers`, `enabledPlugins` structure
- Direct file system inspection: `~/.claude/plugins/installed_plugins.json` — confirmed `version:2, plugins: {key: [entries]}` structure
- Direct file system inspection: `~/.claude/plugins/known_marketplaces.json` — confirmed `{id: {source: {repo}}}` structure
- Direct file system inspection: `~/.claude/skills/*/SKILL.md` — confirmed YAML frontmatter with `name`, `description`, `homepage`, casing variants
- Direct file system inspection: `~/.claude/plugins/cache/*/.*-plugin/plugin.json` — confirmed `name`, `description`, `author` fields
- Codebase inspection: `pro_orc/lib/` — confirmed patterns, existing dependencies, AppColors token names

### Secondary (MEDIUM confidence)
- MCP server type schema inferred from plugin `.mcp.json` files (stdio/http/sse variants) — matches known MCP spec

### Tertiary (LOW confidence)
- None — all claims verified directly from codebase or filesystem

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all deps already in project, no new packages needed
- File format knowledge: HIGH — inspected actual files on this machine
- Architecture patterns: HIGH — directly mirrors existing code
- Color tokens: MEDIUM — OKLCH values are approximate, need final tuning in implementation
- Pitfalls: HIGH — identified from real data (empty mcpServers, case variants, array structure)

**Research date:** 2026-02-23
**Valid until:** 2026-03-30 (stable — file formats are stable, Dart SDK patterns don't change rapidly)
