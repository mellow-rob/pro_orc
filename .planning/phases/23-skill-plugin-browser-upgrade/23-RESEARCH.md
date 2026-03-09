# Phase 23: Skill/Plugin Browser Upgrade - Research

**Researched:** 2026-03-09
**Domain:** Flutter/Dart filesystem scanning, Claude Code plugin/skill metadata, read-only UI upgrade
**Confidence:** HIGH

## Summary

Phase 23 upgrades the existing Claude Tools tab from a global-only view to a per-project-aware browser showing which skills and plugins are active for each project. The scope is strictly read-only -- no settings.json writes, no enable/disable toggles.

The existing codebase already has a fully functional `ClaudeToolsScanner` service that reads `~/.claude/skills/`, `~/.claude/plugins/installed_plugins.json`, and `~/.claude/settings.json`. The existing `ClaudeToolsTab` renders cards in three sections (Skills, Plugins, MCP-Server) with detail panels. This phase extends the scanner to read per-project config, enriches the data models with metadata fields (author, installedAt, lastUpdated), and adds quick actions to open files in the default editor.

**Primary recommendation:** Extend existing `ClaudeToolsScanner` with per-project scanning (read `.claude/skills/` and `.mcp.json` per project path), enrich `PluginData` with author/dates from `plugin.json` and `installed_plugins.json`, add "open in editor" quick actions via `Process.run('open', [path])`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SPB-01 | User sieht pro Projekt welche Skills und Plugins aktiv/installiert sind | Per-project scanning of `.claude/skills/` dirs and `.mcp.json` files; cross-reference with global `enabledPlugins` in settings.json |
| SPB-02 | User kann per Quick Action ein Skill/Plugin im Editor oeffnen oder Docs anzeigen | `Process.run('open', [path])` for local files, `launchUrl()` for homepage/marketplace URLs -- patterns already established in existing cards |
| SPB-03 | Browser zeigt Metadaten (Autor, installiert am, zuletzt aktualisiert) pro Plugin | `plugin.json` has `author.name`; `installed_plugins.json` has `installedAt` and `lastUpdated` fields per plugin entry |
</phase_requirements>

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 3.x | State management | Project standard, all providers use this |
| url_launcher | existing | Open URLs in browser | Already used in plugin/skill cards |
| lucide_icons_flutter | existing | Icon set | Already used across all cards |
| path | existing | Path manipulation | Already imported in scanner/services |

### Supporting (No New Dependencies)
This phase requires zero new dependencies. All functionality is achievable with `dart:io`, `dart:convert`, and existing packages.

## Architecture Patterns

### Current Architecture (What Exists)

```
ClaudeToolsScanner (data/services/)
  ├── scanAll() → ClaudeToolsData
  │   ├── _scanSkills()    → List<SkillData>
  │   ├── _scanPlugins()   → List<PluginData>
  │   ├── _scanMcpServers() → List<McpServerData>
  │   └── _scanAgents()    → List<AgentData>
  └── _parseFrontmatter()  (YAML frontmatter parser)

ClaudeToolsData → claudeToolsProvider → ClaudeToolsTab
  ├── SkillCard  (amber accent, 240px)
  ├── PluginCard (emerald accent, 240px)
  └── McpServerCard (violet accent, 240px)
```

### Recommended Changes

**1. Enrich PluginData model with metadata fields:**
```dart
class PluginData {
  // ... existing fields ...
  final String? author;        // NEW: from plugin.json → author.name
  final DateTime? installedAt; // NEW: from installed_plugins.json
  final DateTime? lastUpdated; // NEW: from installed_plugins.json
}
```

**2. Add per-project skill/plugin detection to ProjectModel or a new per-project scanner:**

The key question: where does per-project data live?

**Per-project Claude configuration locations (verified on local filesystem):**
- `<project>/.claude/skills/` -- per-project skills (can be symlinks to `~/.agents/skills/`)
- `<project>/.mcp.json` -- per-project MCP server config
- `<project>/.claude/settings.local.json` -- per-project permissions/settings (read-only, no writing)

There is NO per-project plugin install mechanism -- plugins are global only (installed to `~/.claude/plugins/cache/`). The `enabledPlugins` map in `~/.claude/settings.json` is also global. So for SPB-01, "per project" means:
- **Skills:** Check `<project>/.claude/skills/` for project-specific skills
- **MCP Servers:** Check `<project>/.mcp.json` for project-specific MCP servers
- **Plugins:** Remain global-only (all projects share the same installed plugins)

**3. Approach for "per project which skills and plugins are active":**

Option A (Recommended): Add a project selector/filter to the Claude Tools tab. When a project is selected, show which of the global tools are also configured at the project level. This keeps the tab as the central tools view.

Option B: Add a tools section to the project detail panel. This duplicates UI and scatters the tools view.

**Recommendation: Option A** -- Add a project dropdown/selector at the top of the Claude Tools tab. Default view shows global tools (current behavior). Selecting a project overlays project-specific skills and MCP servers.

**4. Quick actions pattern (SPB-02):**

Already established in existing cards:
- `Process.run('open', [path], runInShell: true)` -- opens file/folder in default app
- `launchUrl(Uri.parse(url))` -- opens URL in browser
- For "open in editor": `Process.run('open', ['-a', 'Visual Studio Code', path])` or just `Process.run('open', [path])` which opens `.md` files in default editor

### Recommended Project Structure Changes

```
pro_orc/lib/
  data/
    models/
      claude_tool_model.dart    # MODIFY: Add author, installedAt, lastUpdated to PluginData
    services/
      claude_tools_scanner.dart # MODIFY: Read plugin.json author + dates, add per-project scan
  features/
    claude_tools/
      claude_tools_tab.dart     # MODIFY: Add project selector, per-project filtering
      plugin_card.dart          # MODIFY: Show metadata (author, dates) on card
      skill_card.dart           # MODIFY: Add "open in editor" quick action
      mcp_server_card.dart      # MODIFY: Add "open in editor" quick action
    shared/
      claude_tool_detail_panel.dart  # MODIFY: Show metadata in detail panels
  providers/
    claude_tools_provider.dart  # MODIFY: Accept optional project path parameter
```

### Anti-Patterns to Avoid
- **Writing to settings.json:** Explicitly out of scope. No toggle UI, no enable/disable.
- **Re-scanning per project on every render:** Cache per-project tools data, only rescan on watcher events.
- **Hardcoding project paths:** Use `Platform.environment['HOME']` consistently (Wave 0 will fix existing hardcoded paths).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date formatting | Custom date parser | `DateTime.parse()` on ISO 8601 strings | `installedAt` and `lastUpdated` are already ISO 8601 |
| File opening | Custom editor detection | `Process.run('open', [path])` | macOS `open` command handles file associations natively |
| URL launching | Custom browser opener | `url_launcher` package | Already a dependency, handles edge cases |
| Frontmatter parsing | New YAML parser | Existing `_parseFrontmatter()` in scanner | Already works, handles quotes and colons |

## Common Pitfalls

### Pitfall 1: Assuming Plugins Have Per-Project Scope
**What goes wrong:** Building a per-project plugin enable/disable UI that doesn't exist in Claude Code's architecture.
**Why it happens:** The requirement says "pro Projekt welche Plugins aktiv sind" but plugins are globally installed/enabled.
**How to avoid:** Show global plugins as "Global" scope. Only skills and MCP servers have project-level scope. The "per project" view shows which global tools are available plus any project-specific additions.
**Warning signs:** Attempting to read per-project plugin config files that don't exist.

### Pitfall 2: Symlinked Skill Directories
**What goes wrong:** Following symlinks incorrectly or counting the same skill twice.
**Why it happens:** Per-project `.claude/skills/` often contains symlinks to `~/.agents/skills/` (verified on local filesystem).
**How to avoid:** The existing scanner already uses `followLinks: true` in `_scanSkills()` and deduplicates by `id` using a `seen` set. Extend this pattern to per-project scanning.
**Warning signs:** Duplicate skills appearing in the list.

### Pitfall 3: Race Condition with File Watcher
**What goes wrong:** Scanning files that are being written by Claude Code simultaneously.
**Why it happens:** Claude Code writes to `installed_plugins.json` and `settings.json` during plugin operations.
**How to avoid:** The read-only scope protects against write races. For read races, the existing `try/catch` pattern in the scanner gracefully handles partially-written files.

### Pitfall 4: Date Parsing Edge Cases
**What goes wrong:** `DateTime.parse()` fails on unexpected date formats.
**Why it happens:** Different Claude Code versions might format dates differently.
**How to avoid:** Wrap `DateTime.tryParse()` and fall back to null for display-only metadata.
**Warning signs:** Exceptions during plugin scanning.

### Pitfall 5: Missing Plugin Cache Directory
**What goes wrong:** `plugin.json` not found in the install cache path.
**Why it happens:** Plugin was uninstalled or cache was cleaned but `installed_plugins.json` still references it.
**How to avoid:** Graceful null handling (already the pattern in `_scanPlugins()`).

## Code Examples

### Reading Plugin Author from plugin.json (verified on local filesystem)

```dart
// Source: Local filesystem inspection of ~/.claude/plugins/cache/
// plugin.json structure:
// {
//   "name": "context7",
//   "description": "...",
//   "author": { "name": "Upstash" }
// }

String? author;
try {
  final pjPath = '$installPath/.claude-plugin/plugin.json';
  final pjRaw = await File(pjPath).readAsString();
  final pj = jsonDecode(pjRaw) as Map<String, dynamic>;
  author = (pj['author'] as Map<String, dynamic>?)?['name'] as String?;
} catch (_) {}
```

### Parsing installedAt/lastUpdated from installed_plugins.json

```dart
// Source: Local filesystem inspection of ~/.claude/plugins/installed_plugins.json
// Each plugin entry has:
// {
//   "scope": "user",
//   "installPath": "...",
//   "version": "...",
//   "installedAt": "2026-02-12T10:51:06.999Z",
//   "lastUpdated": "2026-03-04T07:30:34.117Z",
//   "gitCommitSha": "..."
// }

final installedAt = DateTime.tryParse(first['installedAt'] as String? ?? '');
final lastUpdated = DateTime.tryParse(first['lastUpdated'] as String? ?? '');
```

### Per-Project Skills Scanning

```dart
// Source: Local filesystem observation -- per-project skills at <project>/.claude/skills/
Future<List<SkillData>> scanProjectSkills(String projectPath) async {
  final projectSkillsDir = Directory('$projectPath/.claude/skills');
  if (!await projectSkillsDir.exists()) return [];

  final result = <SkillData>[];
  await for (final entity in projectSkillsDir.list(
    recursive: false,
    followLinks: true,
  )) {
    if (entity is! Directory) continue;
    final id = entity.path.split('/').last;
    if (id.startsWith('.')) continue;
    final skillData = await _readSkillDir(entity.path, id);
    result.add(skillData);
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}
```

### Per-Project MCP Servers Scanning

```dart
// Source: Claude Code convention -- per-project MCP config at <project>/.mcp.json
Future<List<McpServerData>> scanProjectMcpServers(String projectPath) async {
  final mcpFile = File('$projectPath/.mcp.json');
  if (!await mcpFile.exists()) return [];

  try {
    final raw = await mcpFile.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final servers = (json['mcpServers'] as Map<String, dynamic>?) ?? {};

    return servers.entries.map((e) {
      final config = e.value as Map<String, dynamic>;
      return _parseMcpEntry(e.key, config, source: 'Projekt');
    }).toList();
  } catch (_) {
    return [];
  }
}
```

### Date Display (German locale, manual formatting)

```dart
// Pattern established in project: manual date formatting via padLeft (no intl dependency)
String formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year;
  return '$d.$m.$y';
}
```

## State of the Art

| Old Approach (v1.1 Phase 11) | Current Approach (Phase 23) | Impact |
|-------------------------------|----------------------------|--------|
| Global-only tools view | Per-project + global view | Users see project-specific context |
| No plugin metadata | Author + dates from plugin.json | SPB-03 satisfied |
| "Open in Finder" only for skills | "Open in Editor" for all tool types | SPB-02 enhanced |
| No description in scanner for all plugins | Description already read from plugin.json | Already implemented, just not all metadata |

## Open Questions

1. **Project selector UI in Claude Tools tab**
   - What we know: Need to show per-project tool status. Global tools view exists.
   - What's unclear: Dropdown vs. tabs vs. filter chips for project selection. Whether to show "all projects" aggregated or one-at-a-time.
   - Recommendation: Simple dropdown at the top of the tab. "Alle Projekte (Global)" as default, then individual project names. Planner can decide exact UI.

2. **How to surface "per-project" status for globally installed plugins**
   - What we know: Plugins are globally installed. There's no per-project plugin config.
   - What's unclear: Should we show "this plugin is used in this project" based on some heuristic (e.g., MCP servers from plugins appearing in `.mcp.json`)?
   - Recommendation: Show all plugins as "Global" scope with metadata. Don't try to infer per-project usage -- it would be unreliable and misleading. Per-project view only adds project-local skills and MCP servers.

3. **Watcher scope for per-project tool changes**
   - What we know: `claudeToolsWatcherProvider` watches `~/.claude/`. `watcherProvider` watches project scan directories.
   - What's unclear: Whether changes to `<project>/.claude/skills/` or `<project>/.mcp.json` would trigger the existing watcher.
   - Recommendation: The existing `watcherProvider` already watches project directories. Per-project tool changes would trigger `projectsProvider` invalidation. The planner should ensure per-project tool data is refreshed via the project watcher, not the claude tools watcher.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter Test (built-in) |
| Config file | pro_orc/pubspec.yaml (test dependencies) |
| Quick run command | `cd pro_orc && flutter test test/data/` |
| Full suite command | `cd pro_orc && flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SPB-01 | Per-project skill/plugin detection | unit | `cd pro_orc && flutter test test/data/services/claude_tools_scanner_test.dart -x` | No -- Wave 0 |
| SPB-02 | Quick action opens editor/docs | manual-only | Manual: click action, verify editor opens | N/A |
| SPB-03 | Plugin metadata (author, dates) | unit | `cd pro_orc && flutter test test/data/services/claude_tools_scanner_test.dart -x` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `cd pro_orc && flutter test test/data/`
- **Per wave merge:** `cd pro_orc && flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/data/services/claude_tools_scanner_test.dart` -- covers SPB-01, SPB-03 (scanner metadata + per-project scanning)
- [ ] Test helper: `createTempClaudeDir()` with mock plugin.json, installed_plugins.json, per-project skills
- Framework install: Not needed -- Flutter test already configured

## Sources

### Primary (HIGH confidence)
- **Local filesystem inspection** of `~/.claude/plugins/installed_plugins.json` -- verified plugin entry structure with `installedAt`, `lastUpdated`, `gitCommitSha`, `scope`, `installPath`, `version` fields
- **Local filesystem inspection** of `~/.claude/plugins/cache/*/.../.claude-plugin/plugin.json` -- verified `author.name`, `description`, `name` fields across 10+ plugins
- **Local filesystem inspection** of `~/.claude/settings.json` -- verified `enabledPlugins` map structure (global scope only)
- **Local filesystem inspection** of `<project>/.claude/skills/` -- verified per-project skills with symlinks to `~/.agents/skills/`
- **Local filesystem inspection** of `<project>/.claude/settings.local.json` -- verified per-project permissions structure
- **Existing codebase** -- `claude_tools_scanner.dart`, `claude_tool_model.dart`, `claude_tools_tab.dart`, `plugin_card.dart`, `skill_card.dart`, `mcp_server_card.dart`, `claude_tool_detail_panel.dart`

### Secondary (MEDIUM confidence)
- **Claude Code plugin architecture** -- No per-project plugin install mechanism found. Plugins are always global scope with `"scope": "user"` in installed_plugins.json.

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new dependencies, all existing libraries verified in codebase
- Architecture: HIGH - extending existing patterns, all file structures verified on local filesystem
- Pitfalls: HIGH - based on direct inspection of real data files and existing code patterns

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (stable -- Flutter/Claude Code plugin format unlikely to change within 30 days)
