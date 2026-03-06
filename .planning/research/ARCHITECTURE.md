# Architecture Patterns

**Domain:** v2.0 Feature Integration for native macOS Flutter Dashboard
**Researched:** 2026-03-06

## Recommended Architecture

The existing 3-layer architecture (Presentation -> Riverpod Providers -> Pure Dart Services) remains unchanged. All v2.0 features integrate as new components within existing layers, with no structural changes needed.

```
ShellScreen (IndexedStack with 5 tabs -- NO new tabs)
  |
  +-- CodeTab / ResearchTab (existing)
  |     +-- CodeProjectCard / ResearchProjectCard
  |           +-- Quick Actions row  <-- MODIFY: add Claude-Button as primary
  |
  +-- ClaudeToolsTab (existing)      <-- EXTEND: per-project filter, toggle actions
  |
  +-- AgentsTab (existing)
  |
  +-- SettingsTab (existing)         <-- EXTEND: new Claude Settings section
  |
  +-- OnboardingWizard (NEW)         <-- modal dialog over ShellScreen, not a tab
```

### New vs Modified Components

| Layer | Component | Action | Rationale |
|-------|-----------|--------|-----------|
| **Service** | `claude_settings_service.dart` | CREATE | Read/write ~/.claude/settings.json + settings.local.json |
| **Service** | `claude_detector_service.dart` | CREATE | Detect Claude CLI installation, version, config state |
| **Model** | `claude_settings_model.dart` | CREATE | Typed model for settings.json structure, preserves raw JSON |
| **Provider** | `claude_settings_provider.dart` | CREATE | FutureProvider wrapping ClaudeSettingsService, invalidated by existing claudeToolsWatcher |
| **Provider** | `onboarding_provider.dart` | CREATE | StateNotifierProvider tracking onboarding completion (persisted in Drift) |
| **Widget** | `claude_settings_section.dart` | CREATE | Settings tab section for Claude config |
| **Widget** | `onboarding_wizard.dart` | CREATE | Multi-step GlassDialog wizard |
| **Widget** | `quick_actions.dart` | MODIFY | Add Claude-Button as first action |
| **Widget** | `quick_actions_service.dart` | MODIFY | Add `openClaude(projectPath)` method |
| **Widget** | `settings_tab.dart` | MODIFY | Insert ClaudeSettingsSection between existing sections |
| **Widget** | `claude_tools_tab.dart` | MODIFY | Add per-project filter dropdown, quick actions on tool cards |
| **Widget** | `skill_card.dart` / `plugin_card.dart` | MODIFY | Add enable/disable toggle, open action |
| **Widget** | `shell_screen.dart` | MODIFY | Replace _checkFirstLaunch with onboarding check |
| **DB** | `app_config_table.dart` | MODIFY | Add `onboarding_completed` column (Drift migration v3) |

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `ClaudeSettingsService` | Read/write/validate ~/.claude/settings.json and settings.local.json. Preserves unknown JSON fields on write-back. | Filesystem only (dart:io) |
| `ClaudeDetectorService` | Check `claude` CLI exists via `which`, get version, check config health | Process.run, filesystem |
| `claudeSettingsProvider` | Expose settings as reactive state, invalidate on FS changes | ClaudeSettingsService, claudeToolsWatcherProvider (existing) |
| `onboardingProvider` | Track first-run state, step completion | AppDatabase (Drift) |
| `OnboardingWizard` | Multi-step setup flow with Claude detection | ClaudeDetectorService, claudeSettingsProvider |
| `ClaudeSettingsSection` | GUI for editing Claude config within Settings tab | claudeSettingsProvider |

## Data Flow Changes per Feature

### 1. Claude-Button (Minimal Change -- 2 files, ~20 LOC)

```
CodeProjectCard / ResearchProjectCard
  -> buildProjectQuickActions()  -- Claude action inserted at index 0
    -> QuickActionsService.openClaude(projectPath)
      -> osascript: tell Terminal to do script "cd X && claude"
      -> open -a Terminal
```

The Claude-Button replaces Terminal as the primary (leftmost) action. Terminal moves to second position. No new providers needed -- just a new method on QuickActionsService and a reorder in `buildProjectQuickActions()`.

**New method on QuickActionsService:**
```dart
/// Opens Terminal.app, cd's into the project directory, and starts
/// an interactive Claude Code session.
Future<void> openClaude(String projectPath) async {
  final script = _terminalScript('cd "$projectPath" && claude');
  await Process.run('osascript', ['-e', script], runInShell: true);
  await Process.run('open', ['-a', 'Terminal'], runInShell: true);
}
```

**Modified `buildProjectQuickActions()`:**
```dart
List<QuickAction> buildProjectQuickActions(ProjectModel project, QuickActionsService qa) {
  return [
    // Claude-Button is PRIMARY (first position, prominent icon)
    QuickAction(
      icon: LucideIcons.sparkles100,
      tooltip: 'Claude',
      onPressed: () => qa.openClaude(project.path),
    ),
    QuickAction(
      icon: LucideIcons.terminal100,
      tooltip: 'Terminal',
      onPressed: () => qa.openInTerminal(project.path),
    ),
    // ... rest unchanged (Finder, GitHub, Notion, Memory)
  ];
}
```

This follows the proven osascript pattern from `openRemSleep()` (v1.2) and `openClaudeWithPrompt()` which already exist in the service.

### 2. Settings GUI (4 new files, 2 modified, ~400 LOC estimated)

```
SettingsTab
  -> ClaudeSettingsSection (new widget, inserted between Git-Pfad and Autostart sections)
    -> ref.watch(claudeSettingsProvider)
      -> ClaudeSettingsService.readSettings()
        -> File('~/.claude/settings.json').readAsString()
        -> jsonDecode -> ClaudeSettingsModel

User edits (toggle plugin, change effort level):
  -> ClaudeSettingsService.writeSettings(updatedModel)
    -> jsonEncode -> File('~/.claude/settings.json').writeAsString()
    -> ref.invalidate(claudeSettingsProvider)
    -> claudeToolsWatcher fires on FS change -> claudeToolsProvider also refreshes
```

**ClaudeSettingsModel structure (mirrors settings.json):**
```dart
class ClaudeSettingsModel {
  final Map<String, bool> enabledPlugins;
  final Map<String, dynamic> mcpServers;
  final Map<String, dynamic>? hooks;
  final Map<String, dynamic>? statusLine;
  final String? effortLevel;  // "low", "medium", "high"
  final Map<String, dynamic>? permissions;  // from settings.local.json
  // Raw JSON preserved for unknown fields -- NEVER lose user data
  final Map<String, dynamic> rawJson;
  final Map<String, dynamic>? rawLocalJson;

  // Factory: parse known fields from raw JSON
  factory ClaudeSettingsModel.fromJson(
    Map<String, dynamic> raw, [Map<String, dynamic>? rawLocal]
  );

  // Merge known fields back into raw JSON for write-back
  Map<String, dynamic> toMergedJson();
}
```

**Critical design decision:** The service MUST preserve ALL fields in settings.json, not just the ones we model. Read full JSON, modify known fields, write back complete JSON. Claude adds new settings fields frequently (hooks, statusLine, effortLevel all appeared in recent months). Strict parsing that ignores unknown fields would cause data loss.

**Provider (follows exact existing pattern):**
```dart
final claudeSettingsProvider = FutureProvider<ClaudeSettingsModel>((ref) async {
  // Reuse existing watcher -- ~/.claude/ changes trigger refresh
  ref.listen(claudeToolsWatcherProvider, (_, next) {
    if (next.hasValue) ref.invalidateSelf();
  });
  return ClaudeSettingsService().readSettings();
});
```

**Settings GUI sections to expose:**
1. **Effort Level** -- dropdown (low/medium/high), maps to `effortLevel` key
2. **Enabled Plugins** -- toggle list, maps to `enabledPlugins` map
3. **MCP Servers** -- read-only list with enable indicator (write = advanced, defer)
4. **Hooks** -- read-only display (too complex to edit in GUI)
5. **Permissions** -- from settings.local.json, read-only display

### 3. Skill/Plugin Browser Upgrade (3-4 files modified, ~200 LOC estimated)

```
ClaudeToolsTab (existing)
  -> Add project filter dropdown at top
    -> Populated from ref.watch(projectsProvider)
    -> "Alle Projekte" default, then per-project filtering
  -> SkillCard / PluginCard (existing)
    -> Add enable/disable toggle
      -> Writes to settings.json via claudeSettingsProvider + ClaudeSettingsService
    -> Add "Oeffnen" action
      -> Skills: open dir in Finder via QuickActionsService.openInFinder
      -> Plugins: open marketplace URL via QuickActionsService.openUrl
```

The enable/disable toggle on plugin cards writes to `enabledPlugins` in settings.json. This requires `ClaudeSettingsService` from Phase 2, making Phase 2 a hard dependency.

**Per-project filtering approach:**
- Dropdown shows project names from `projectsProvider`
- Selected project -> check that project's `.claude/settings.local.json` for project-specific tool config
- Show which tools are active globally vs per-project
- If no project selected, show global state (current behavior)

### 4. Onboarding (3 new files, 3 modified, ~500 LOC estimated)

```
ShellScreen.initState()
  -> _checkOnboarding() (replaces _checkFirstLaunch)
    -> db.getConfig().onboardingCompleted
    -> if not completed:
      -> showDialog(OnboardingWizard)
        -> Step 1: Willkommen + Claude CLI Detection
          -> ClaudeDetectorService.detectClaude()
            -> Process.run('which', ['claude'], runInShell: true)
            -> Process.run('claude', ['--version'], runInShell: true)
        -> Step 2: Scan-Ordner einrichten
          -> Reuse file_selector getDirectoryPath
          -> Add selected dirs to DB via existing db.setScanDirs
        -> Step 3: Erster Projekt-Import (optional)
          -> Reuse ImportProjectDialog or simplified version
        -> Step 4: Autostart (moved from current launch_dialog.dart)
          -> launch_at_startup enable/disable
      -> on complete: db.updateConfig(onboardingCompleted: true)
```

**Key insight:** The existing `_checkFirstLaunch()` in ShellScreen already implements this exact pattern: check SharedPreferences flag -> show dialog -> set flag. Onboarding replaces it entirely. The autostart question becomes Step 4 of the wizard instead of a standalone dialog.

**ClaudeDetectorService:**
```dart
class ClaudeDetectorService {
  /// Check if `claude` CLI is installed and accessible.
  Future<ClaudeInstallStatus> detect() async {
    try {
      final which = await Process.run('which', ['claude'], runInShell: true);
      if (which.exitCode != 0) return ClaudeInstallStatus.notFound;

      final version = await Process.run('claude', ['--version'], runInShell: true);
      final versionStr = version.stdout.toString().trim();

      final hasSettings = await File('$_claudeDir/settings.json').exists();

      return ClaudeInstallStatus(
        installed: true,
        path: which.stdout.toString().trim(),
        version: versionStr,
        hasConfig: hasSettings,
      );
    } catch (_) {
      return ClaudeInstallStatus.notFound;
    }
  }
}
```

**Drift migration v3 (single column addition):**
```dart
// In app_database.dart schemaVersion getter:
@override
int get schemaVersion => 3;

// In migration():
if (from < 3) {
  await m.addColumn(appConfig, appConfig.onboardingCompleted);
}
```

## Patterns to Follow

### Pattern 1: Service reads JSON, preserves unknown fields
**What:** Read full JSON map, extract known fields into typed model, keep raw map for write-back.
**When:** Any service that reads/writes user config files (settings.json).
**Why:** Claude adds new config fields regularly. Strict parsing loses data on write-back.
**Example:**
```dart
Future<void> writeSettings(ClaudeSettingsModel settings) async {
  // Merge known fields back into raw JSON -- preserves unknown fields
  final merged = {...settings.rawJson, ...settings.toMergedJson()};
  await File(_settingsPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(merged),
  );
}
```

### Pattern 2: Extend existing providers via composition
**What:** New providers that depend on existing watcher infrastructure.
**When:** Adding reactive state that should refresh when ~/.claude/ changes.
**Why:** claudeToolsWatcherProvider already monitors all of ~/.claude/. No new watchers needed.

### Pattern 3: Onboarding as modal dialog, not route
**What:** Show onboarding as a modal dialog over ShellScreen.
**When:** First-run experience.
**Why:** Matches existing launch_dialog.dart pattern. App stays functional underneath. No navigation stack complexity. `barrierDismissible: false` keeps focus (proven in v1.4).

### Pattern 4: Quick action insertion order = visual priority
**What:** First QuickAction in list renders leftmost on cards.
**When:** Adding Claude-Button.
**Why:** Users scan left-to-right. Primary action (Claude) goes first. This is the entire product vision: "dashboard as Claude launcher."

### Pattern 5: _buildSection for Settings subsections
**What:** Reuse the existing `SettingsTab._buildSection()` helper for the Claude settings section.
**When:** Adding ClaudeSettingsSection to SettingsTab.
**Why:** Visual consistency. The helper already handles icon, title, subtitle, GlassCard wrapping.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Separate config file for Pro Orc's Claude preferences
**What:** Creating a Pro Orc-owned config file to store Claude-related settings.
**Why bad:** Duplicates source of truth. ~/.claude/settings.json IS the config. Changes made in Pro Orc must be visible to Claude CLI and vice versa.
**Instead:** Read/write ~/.claude/settings.json directly. Pro Orc's own preferences stay in Drift DB.

### Anti-Pattern 2: Strict JSON schema validation on settings.json
**What:** Failing or ignoring unknown fields in settings.json.
**Why bad:** The actual settings.json contains `hooks`, `statusLine`, `effortLevel`, `enabledPlugins` -- fields that were added over time. A strict schema would break on new Claude releases.
**Instead:** Keep raw JSON map, overlay typed fields. Write merged result. Treat unknown fields as pass-through.

### Anti-Pattern 3: New FileSystemWatcher for settings changes
**What:** Creating a separate watcher for ~/.claude/settings.json.
**Why bad:** `claudeToolsWatcherProvider` already watches ~/.claude/ directory recursively. Adding another watcher creates redundant FS events and potential race conditions.
**Instead:** Reuse `claudeToolsWatcherProvider`. Settings changes already trigger it.

### Anti-Pattern 4: Navigation-based onboarding (push/replace routes)
**What:** Using Navigator.push for onboarding screens.
**Why bad:** Menubar-only app with complex window lifecycle. Dialog pattern is proven (launch_dialog, create_project_dialog, delete_project_dialog, import_project_dialog all use it).
**Instead:** Modal dialog with internal step state (`_currentStep` int, stepper-style content switching).

### Anti-Pattern 5: Claude version parsing with format assumptions
**What:** Parsing `claude --version` output with regex assuming stable format.
**Why bad:** CLI output format changes between versions. Version string format is not guaranteed.
**Instead:** Check exit code 0 = installed. Store raw version string for display. Don't parse into semver.

### Anti-Pattern 6: Writing settings.json on every keystroke
**What:** Real-time sync of text fields to settings.json.
**Why bad:** File writes trigger FS watcher events -> provider invalidation -> full UI rebuild. Creates thrashing.
**Instead:** Debounce writes. Use "Speichern" button for text fields (matches existing Git-Pfad pattern in SettingsTab). Toggles can write immediately (single field change).

## Integration Points -- Full Reuse Map

| Existing Code | Reuse For | How |
|---------------|-----------|-----|
| `QuickActionsService` | Claude-Button | Add `openClaude()` method (same osascript pattern as `openRemSleep`) |
| `buildProjectQuickActions()` | Claude-Button ordering | Insert Claude action at index 0 |
| `claudeToolsWatcherProvider` | Settings + tool browser reactivity | `ref.listen` for invalidation (identical to `claudeToolsProvider` pattern) |
| `ClaudeToolsScanner._scanPlugins()` | Settings GUI plugin display | Already reads `enabledPlugins` -- model shared |
| `ClaudeToolsScanner._scanMcpServers()` | Settings GUI MCP display | Already reads `mcpServers` -- model shared |
| `SettingsTab._buildSection()` | Claude settings section layout | Reuse exact same section builder (icon + title + subtitle + GlassCard) |
| `GlassDialog` | Onboarding wizard | Multi-step dialog with internal state |
| `_checkFirstLaunch()` in ShellScreen | Onboarding trigger | Replace with onboarding check (same SharedPreferences/DB flag pattern) |
| `projectsProvider` | Tool browser project filter | Dropdown source for per-project filtering |
| `AppDatabase` + Drift migrations | Onboarding state | Add `onboarding_completed` column (migration v3) |
| `file_selector.getDirectoryPath()` | Onboarding scan-dir setup | Already imported, used in Settings and Import |
| `QuickActionsService.openInFinder()` | Skill "open" action | Direct reuse |
| `QuickActionsService.openUrl()` | Plugin marketplace link | Direct reuse |

## Files to Create

| File | Layer | Purpose | Est. LOC |
|------|-------|---------|----------|
| `lib/data/services/claude_settings_service.dart` | Service | Read/write ~/.claude/settings.json with raw JSON preservation | ~120 |
| `lib/data/services/claude_detector_service.dart` | Service | Detect Claude CLI, version, config health | ~60 |
| `lib/data/models/claude_settings_model.dart` | Model | Typed model for settings.json | ~80 |
| `lib/providers/claude_settings_provider.dart` | Provider | FutureProvider wrapping settings service | ~15 |
| `lib/providers/onboarding_provider.dart` | Provider | StateNotifier for onboarding completion | ~25 |
| `lib/features/settings/claude_settings_section.dart` | Widget | Settings tab section for Claude config | ~250 |
| `lib/features/shared/onboarding_wizard.dart` | Widget | Multi-step first-run wizard | ~350 |

**Total new:** ~900 LOC across 7 files.

## Files to Modify

| File | Change | Scope |
|------|--------|-------|
| `quick_actions_service.dart` | Add `openClaude()` | ~5 lines |
| `quick_actions.dart` | Insert Claude action at index 0 | ~8 lines |
| `settings_tab.dart` | Insert ClaudeSettingsSection widget | ~5 lines |
| `claude_tools_tab.dart` | Add project filter dropdown, pass settings provider | ~40 lines |
| `skill_card.dart` | Add toggle + open actions | ~30 lines |
| `plugin_card.dart` | Add enable/disable toggle | ~30 lines |
| `mcp_server_card.dart` | Add enabled indicator | ~10 lines |
| `shell_screen.dart` | Replace _checkFirstLaunch with onboarding | ~15 lines |
| `app_config_table.dart` | Add onboarding_completed column | ~3 lines |
| `app_database.dart` | Migration v2->v3 | ~10 lines |

**Total modified:** ~156 LOC across 10 files.

## Suggested Build Order (Dependency-Driven)

### Phase 1: Claude-Button
**Dependencies:** None
**Files:** 2 modified
**Scope:** ~15 LOC
**Why first:** Smallest change, highest impact. Validates the core v2.0 vision ("dashboard as Claude launcher"). The `openClaude()` method follows the exact same osascript pattern as 3 existing methods in QuickActionsService. Can ship as a point release immediately.

### Phase 2: Claude Settings Service + GUI
**Dependencies:** None (reads existing files, uses existing watcher)
**Files:** 4 new, 2 modified
**Scope:** ~470 LOC
**Why second:** ClaudeSettingsService is needed by Phase 3 (Skill/Plugin toggle writes) and Phase 4 (Onboarding config health check). Building it early unblocks both downstream features. The service is fully testable with temp dirs (matches existing test pattern).

### Phase 3: Skill/Plugin Browser Upgrade
**Dependencies:** ClaudeSettingsService from Phase 2 (for enable/disable writes)
**Files:** 3-4 modified
**Scope:** ~110 LOC
**Why third:** Toggle writes use ClaudeSettingsService.writeSettings(). Per-project filter is independent but logically groups with Settings GUI. Both features make the Claude Tools tab a full management interface rather than read-only inventory.

### Phase 4: Onboarding
**Dependencies:** ClaudeDetectorService (new, no deps), Drift migration v3
**Files:** 3 new, 3 modified
**Scope:** ~460 LOC
**Why fourth:** Benefits from all other features being complete -- onboarding tour can reference real UI. Needs Drift migration v3 which should be the last schema change to avoid migration churn during development. Replaces existing _checkFirstLaunch cleanly.

### Phase 5: Open Source Polish
**Dependencies:** All features complete (screenshots need final UI)
**Files:** Documentation only, 0 code changes
**Scope:** README.md, CONTRIBUTING.md, LICENSE, screenshots
**Why last:** Screenshots, README, and guides must reflect the final product. No architecture impact.

```
Phase 1 (Claude-Button) ──┐
                           ├──> Phase 3 (Browser Upgrade)
Phase 2 (Settings GUI) ───┤
                           ├──> Phase 4 (Onboarding)
                           │
                           └──> Phase 5 (Open Source Polish)
```

## Scalability Considerations

| Concern | Current State | v2.0 Impact |
|---------|--------------|-------------|
| settings.json reads | ClaudeToolsScanner reads once per watcher cycle | ClaudeSettingsService adds second reader -- OK, same invalidation cycle, no extra FS watches |
| ~/.claude/ watcher events | Fires on any file change in ~/.claude/ | No additional watchers -- all new features reuse claudeToolsWatcherProvider |
| Drift DB schema | v2 (2 tables) | v3 (single column addition to app_config) |
| Tab count | 5 (Code, Research, Tools, Agents, Settings) | No new tabs -- all features extend existing tabs or use modal dialogs |
| Provider count | 6 (projects, watcher, db, hidden, claudeTools, claudeToolsWatcher) | +2 (claudeSettings, onboarding) -- minimal overhead |

## Sources

- Direct codebase analysis of all referenced files (HIGH confidence)
- Live ~/.claude/settings.json inspection showing actual field structure (HIGH confidence)
- Live ~/.claude/settings.local.json inspection (HIGH confidence)
- Existing QuickActionsService osascript patterns proven in v1.2-v1.5 (HIGH confidence)
- Existing ClaudeToolsScanner JSON parsing proven in production (HIGH confidence)
- Drift migration pattern proven in v1-v2 migration (HIGH confidence)
- `which claude` returns `/Users/rob/.local/bin/claude` (HIGH confidence -- verified on this machine)
