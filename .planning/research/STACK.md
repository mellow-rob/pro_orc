# Technology Stack

**Project:** Pro Orc v2.0 Open Source Public Release
**Researched:** 2026-03-06
**Scope:** Stack additions for Claude-Button, Settings GUI, Skill/Plugin Browser, Onboarding, Open Source Polish

---

## Existing Stack (DO NOT CHANGE)

Already validated and shipping. Listed for reference only.

| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.41.1 | macOS native app framework |
| Dart | ^3.11.0 | Language |
| flutter_riverpod | ^3.2.1 | State management |
| drift / drift_flutter | ^2.31.0 / ^0.2.8 | SQLite config DB |
| file_selector | ^1.1.0 | Native file/folder picker |
| watcher | ^1.2.1 | Filesystem watching |
| url_launcher | ^6.3.2 | External link opening |
| lucide_icons_flutter | ^3.1.9 | Icon set |

---

## New Stack Additions

### Zero new Flutter/Dart dependencies needed

v2.0 requires **no new packages**. All features build on existing dependencies plus `dart:io` and `dart:convert` (both already used throughout the codebase).

**Rationale:** The new features are fundamentally filesystem read/write operations and process launching -- capabilities already proven in production via `ClaudeToolsScanner`, `QuickActionsService`, and `GsdParser`.

---

## Claude Code Configuration Files -- Complete Schema

### File Hierarchy (Scope Precedence)

Settings merge with this precedence (highest wins):

| Scope | File | Checked In? | Purpose |
|-------|------|-------------|---------|
| Global | `~/.claude/settings.json` | N/A | User-wide defaults (model, plugins, hooks, effort) |
| Global-local | `~/.claude/settings.local.json` | N/A | User-wide secrets/permissions |
| Project | `<project>/.claude/settings.json` | Yes | Shared project config |
| Project-local | `<project>/.claude/settings.local.json` | No (.gitignored) | Personal project overrides (permissions) |

**Confidence:** HIGH -- verified against actual files on disk and official docs.

### settings.json Full Key Schema

Source: [code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings)

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  // Core
  "model": "string",                    // Override default model
  "availableModels": ["string"],         // Restrict model selection via /model
  "effortLevel": "low|medium|high",      // Effort level
  "language": "string",                  // Response language (e.g. "japanese")
  "outputStyle": "string",              // Output style preset

  // Permissions
  "permissions": {
    "allow": ["Tool(specifier)"],        // Auto-approved tools
    "ask": ["Tool(specifier)"],          // Require confirmation
    "deny": ["Tool(specifier)"],         // Blocked tools
    "additionalDirectories": ["path"],   // Extra accessible dirs
    "defaultMode": "acceptEdits"         // Default permission mode
  },

  // Hooks
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "..." }] }],
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "..." }] }]
  },
  "statusLine": { "type": "command", "command": "..." },
  "disableAllHooks": false,

  // Plugins
  "enabledPlugins": {
    "plugin-name@marketplace-id": true   // Boolean toggle per plugin
  },
  "extraKnownMarketplaces": {
    "marketplace-id": {
      "source": { "source": "github", "repo": "owner/repo" }
    }
  },

  // MCP Servers (direct config, not from plugins)
  "mcpServers": {
    "server-name": {
      "command": "string",
      "args": ["string"],
      "type": "stdio|http|sse",
      "url": "string",
      "env": {}
    }
  },
  "enableAllProjectMcpServers": false,

  // Sandbox
  "sandbox": {
    "enabled": false,
    "autoAllowBashIfSandboxed": true,
    "filesystem": { "allowWrite": [], "denyWrite": [], "denyRead": [] },
    "network": { "allowedDomains": [] }
  },

  // Attribution
  "attribution": {
    "commit": "string",                  // Git commit co-author line
    "pr": "string"                       // PR description attribution
  },

  // Misc
  "cleanupPeriodDays": 30,
  "includeGitInstructions": true,
  "autoUpdatesChannel": "stable|latest",
  "respectGitignore": true,
  "showTurnDuration": true,
  "alwaysThinkingEnabled": false,
  "env": {}
}
```

**Confidence:** HIGH -- verified against official docs at code.claude.com and actual `~/.claude/settings.json` on disk.

---

## Plugin System Files (Complete Map)

| File | Purpose | Editable by GUI? |
|------|---------|-----------------|
| `~/.claude/settings.json` → `enabledPlugins` | Toggle plugins on/off | YES |
| `~/.claude/plugins/installed_plugins.json` | All installed plugins with metadata | READ ONLY |
| `~/.claude/plugins/known_marketplaces.json` | Registry of marketplace sources | READ ONLY |
| `~/.claude/plugins/blocklist.json` | Server-side blocked plugins | READ ONLY |
| `~/.claude/plugins/cache/<mkt>/<plugin>/<ver>/` | Cached plugin files | READ ONLY |
| `~/.claude/plugins/marketplaces/<mkt>/plugins/<name>/` | Marketplace plugin index | READ ONLY |
| `~/.claude/plugins/marketplaces/<mkt>/external_plugins/<name>/` | MCP-based plugins | READ ONLY |

### installed_plugins.json Schema

```json
{
  "version": 2,
  "plugins": {
    "plugin-name@marketplace-id": [
      {
        "scope": "user",
        "installPath": "/absolute/path/to/cache/dir",
        "version": "1.0.0",
        "installedAt": "2026-02-12T10:51:06.999Z",
        "lastUpdated": "2026-03-04T07:30:34.117Z",
        "gitCommitSha": "2cd88e7947b7382e045666abee790c7f55f669f3"
      }
    ]
  }
}
```

### known_marketplaces.json Schema

```json
{
  "marketplace-id": {
    "source": {
      "source": "github",
      "repo": "owner/repo-name"
    },
    "installLocation": "/absolute/path",
    "lastUpdated": "2026-03-06T09:55:08.513Z"
  }
}
```

### Plugin Metadata (.claude-plugin/plugin.json)

Located at `<installPath>/.claude-plugin/plugin.json`:

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Human-readable description",
  "author": {
    "name": "Author Name",
    "email": "optional@email.com"
  }
}
```

### Plugin Types

Two categories exist in marketplaces:

| Category | Location | Contains | Example |
|----------|----------|----------|---------|
| Regular plugins | `plugins/<name>/` | `.claude-plugin/plugin.json` + `agents/*.md` + `LICENSE` | code-simplifier, ralph-loop |
| External plugins | `external_plugins/<name>/` | `.claude-plugin/plugin.json` + `.mcp.json` | context7, playwright, firebase |

External plugins provide MCP servers. Regular plugins provide agent definitions (skills).

**Confidence:** HIGH -- all schemas verified against actual files in `~/.claude/plugins/`.

---

## Skills/Agents/Commands Files

| File Pattern | Purpose |
|-------------|---------|
| `~/.claude/agents/<name>.md` | Agent definitions (22 files on disk) |
| `~/.claude/commands/<name>.md` | Global slash commands |
| `~/.claude/commands/<dir>/<name>.md` | Grouped slash commands (e.g., `gsd/` has 34 files) |
| `<project>/.claude/commands/<name>.md` | Project-scoped slash commands |

### Agent/Skill Frontmatter Format

Verified from 22 agent files on disk:

```yaml
---
name: human-readable-name
description: What this agent does
model: opus|sonnet|haiku
color: cyan|green|orange
tools: Read, Write, Bash
---

[Full agent prompt in markdown]
```

The existing `ClaudeToolsScanner._scanAgents()` already parses this format correctly.

**Confidence:** HIGH -- verified against actual agent files.

---

## Per-Project Plugin/Tool Status

Plugins are **global only**. The `enabledPlugins` map in `~/.claude/settings.json` applies to all projects. There is no per-project plugin override.

However, **per-project tool visibility** can be inferred from:
- `<project>/.claude/settings.local.json` → `permissions.allow` entries
- Pattern: `mcp__plugin_<name>_<server>__<tool>` indicates plugin used in that project
- Pattern: `Skill(gsd:plan-phase)` indicates skill invoked in that project

This enables showing "used in project X" badges without any new data sources.

**Confidence:** HIGH -- verified across multiple project settings.local.json files.

---

## Feature Implementation Details (Stack Perspective)

### 1. Claude Button

**No new dependencies.** Extend existing `QuickActionsService`:

```dart
/// Opens Terminal.app and launches `claude` in the project directory.
Future<void> openClaude(String projectPath) async {
  final script = _terminalScript('cd "$projectPath" && claude');
  await Process.run('osascript', ['-e', script], runInShell: true);
  await Process.run('open', ['-a', 'Terminal'], runInShell: true);
}
```

Identical pattern to `openInTerminal()`, `openClaudeWithPrompt()`, `openRemSleep()` already shipping.

**Confidence:** HIGH -- same pattern, already proven.

### 2. Settings GUI -- Read/Write Strategy

**No new dependencies.** Use `dart:convert` (already imported in `claude_tools_scanner.dart`):

```dart
// Read
final raw = await File('$home/.claude/settings.json').readAsString();
final settings = jsonDecode(raw) as Map<String, dynamic>;

// Modify
settings['model'] = 'claude-sonnet-4-6';

// Write back with pretty printing (preserves readability)
final encoder = JsonEncoder.withIndent('  ');
await File('$home/.claude/settings.json').writeAsString(encoder.convert(settings));
```

**Critical:** Write to `settings.json` only. NEVER write to `settings.local.json` -- it accumulates user permissions during normal Claude Code usage and the GUI should not modify it.

#### Recommended GUI Scope for v2.0

| Key | GUI Control Type | Target Audience |
|-----|-----------------|-----------------|
| `model` | Dropdown | All users |
| `effortLevel` | Segmented control (low/med/high) | All users |
| `enabledPlugins` | Toggle switches per plugin | All users |
| `autoUpdatesChannel` | Toggle (stable/latest) | Power users |
| `alwaysThinkingEnabled` | Toggle | Power users |
| `language` | Text field | Optional |
| `hooks` | Read-only display | Informational |
| `mcpServers` | Read-only list | Informational (already in Claude Tools tab) |
| `permissions.allow` | Read-only list | Informational |

**Do NOT expose:** `sandbox`, `attribution`, `env`, `permissions.deny`, `forceLoginMethod`, `forceLoginOrgUUID`. These are advanced/enterprise settings.

**Confidence:** MEDIUM -- scope recommendation based on target audience (technical non-developers). May adjust based on user testing.

### 3. Skill/Plugin Browser Enhancement

**No new dependencies.** Existing `ClaudeToolsScanner` already reads all required data. Enhancements:

| New Data Point | Source File | Parser Change |
|---------------|-------------|---------------|
| Install date | `installed_plugins.json` → `installedAt` | Add field to `PluginData` model |
| Last updated | `installed_plugins.json` → `lastUpdated` | Add field to `PluginData` model |
| Plugin type (agent vs MCP) | Presence of `.mcp.json` in install path | Add enum to `PluginData` model |
| Author | `.claude-plugin/plugin.json` → `author.name` | Add field to `PluginData` model |

### 4. Claude CLI Detection (Onboarding)

**No new dependencies.** Use `dart:io`:

```dart
// Detection order (most reliable first):
// 1. which claude -- covers all install methods
final whichResult = await Process.run('which', ['claude'], runInShell: true);
final installed = whichResult.exitCode == 0;

// 2. Version check
if (installed) {
  final vResult = await Process.run('claude', ['--version'], runInShell: true);
  // Output: "2.1.70 (Claude Code)"
  final version = vResult.stdout.toString().trim().split(' ').first;
}

// 3. Config directory exists (has been used)
final configured = Directory('$home/.claude').existsSync();

// 4. Settings exist (has been configured)
final hasSettings = File('$home/.claude/settings.json').existsSync();
```

**Installation paths observed:**
- Standard: `~/.local/bin/claude` symlink -> `~/.local/share/claude/versions/<ver>` (Mach-O arm64)
- npm: Global npm install puts `claude` in npm bin dir
- Both found by `which claude` via `runInShell: true`

**Confidence:** HIGH -- verified on actual installation.

### 5. Open Source Polish

**No new dependencies.** Static files only:

| Artifact | Method |
|----------|--------|
| README.md | Manual creation with screenshots |
| LICENSE | MIT template (static file) |
| CONTRIBUTING.md | Manual creation |
| Screenshots | macOS Screenshot + Preview app |
| Homebrew formula | Update existing `mellow-rob/tap/pro-orc` |
| GitHub release | `gh release create` (already in workflow) |

---

## Alternatives Considered and Rejected

| Category | Decision | Alternative | Why Not |
|----------|----------|-------------|---------|
| JSON editing | `dart:convert` (built-in) | `json_editor` widget | Over-engineering for ~10 form fields |
| Settings form | Custom Flutter widgets with GlassCard | `flutter_form_builder` | Adds dependency for minimal form; GlassDialog pattern handles this |
| YAML parsing | `_parseFrontmatter()` (existing) | `yaml` package | Existing regex parser covers all agent frontmatter |
| CLI detection | `Process.run` + `File.existsSync` | `which_cmd` package | Two lines of code vs. a dependency |
| JSON validation | Skip | `json_schema` package | Claude CLI validates on read; GUI validation adds complexity for no gain |
| Markdown rendering | Not needed for v2.0 | `flutter_markdown_plus` | Settings GUI uses form fields, not markdown; plugin descriptions are plain text |
| Terminal emulator | osascript + Terminal.app | embedded terminal widget | Terminal.app is user's actual environment; embedding a terminal would be a separate product |

---

## What NOT to Add

| Package | Why Skip |
|---------|----------|
| Any JSON editor widget | Settings are simple key-value; custom form fields in GlassCard are better UX |
| Any terminal emulator | Pro Orc is a launcher, not a terminal replacement |
| Any markdown renderer | Not needed for settings or plugin browser views |
| Any HTTP client | No network features in v2.0 scope; all data is local filesystem |
| Any schema validator | Claude CLI handles validation; GUI just needs read/write |
| flutter_form_builder | Overkill for ~10 fields; would fight with existing GlassDialog styling |

---

## Installation

```bash
# No new packages to install for v2.0
# All features use existing dependencies + dart:io + dart:convert
```

---

## Sources

- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings) -- HIGH confidence, official docs
- [Claude Code MCP Documentation](https://code.claude.com/docs/en/mcp) -- HIGH confidence, official docs
- Actual `~/.claude/settings.json` on disk (keys: hooks, statusLine, enabledPlugins, effortLevel) -- HIGH confidence
- Actual `~/.claude/settings.local.json` on disk (keys: permissions.allow) -- HIGH confidence
- Actual `~/.claude/plugins/installed_plugins.json` (14 plugins, version 2 schema) -- HIGH confidence
- Actual `~/.claude/plugins/known_marketplaces.json` (5 marketplaces) -- HIGH confidence
- Actual `~/.claude/plugins/blocklist.json` (2 blocked plugins) -- HIGH confidence
- Actual `~/.claude/plugins/cache/` and `~/.claude/plugins/marketplaces/` directory structure -- HIGH confidence
- Actual `~/.claude/agents/` (22 agent .md files with frontmatter) -- HIGH confidence
- Actual `~/.claude/commands/` (4 global commands + gsd/ with 34 commands) -- HIGH confidence
- Claude CLI binary: `~/.local/bin/claude` -> `~/.local/share/claude/versions/2.1.70` (Mach-O arm64) -- HIGH confidence
- Existing `ClaudeToolsScanner` in `pro_orc/lib/data/services/claude_tools_scanner.dart` -- HIGH confidence
- Existing `QuickActionsService` in `pro_orc/lib/data/services/quick_actions_service.dart` -- HIGH confidence
- Multiple project `.claude/settings.local.json` files for per-project patterns -- HIGH confidence

---
*Stack research for: Pro Orc v2.0 Open Source Public Release*
*Researched: 2026-03-06*
