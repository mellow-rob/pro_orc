# Phase 5: Claude Tools - Research

**Researched:** 2026-02-17
**Domain:** `~/.claude/` filesystem scanning — Skills, Plugins, MCP servers
**Confidence:** HIGH (all findings from direct filesystem inspection of actual files)

---

## Summary

Phase 5 builds a dedicated Tools panel that auto-discovers all Claude capabilities installed in `~/.claude/`. The three data sources — skills, plugins, and MCP servers — each have distinct file structures that were directly inspected on this machine.

Skills live in `~/.claude/skills/` as directories (or symlinks to directories) each containing a `skill.md` with YAML frontmatter. Plugins are tracked in `~/.claude/plugins/installed_plugins.json` and their manifests live in a cache structure under `~/.claude/plugins/cache/`. MCP servers are NOT configured in `~/.claude.json` (that key exists but is empty `{}`); instead, MCP capability is indicated by the presence of a `.mcp.json` file within a plugin's cache directory. The enabled/disabled state of plugins lives in `~/.claude/settings.json` under `enabledPlugins`.

The implementation pattern should follow `scanner.ts` exactly: a new `lib/tools-scanner.ts` module with `server-only`, using Node.js `fs.promises`, returning typed arrays. A new `Tools` tab slots into the existing `ProjectTabs` tab bar. No new npm packages are required — `js-yaml` is already installed in the project.

**Primary recommendation:** Implement `lib/tools-scanner.ts` that reads three sources (skills dir + plugins installed_plugins.json + plugins cache for .mcp.json detection), add a `ClaudeTool` type to `lib/types.ts`, and add a third tab to `ProjectTabs`.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TOOL-01 | App auto-scans `~/.claude/` for installed skills (name, type, description) | Skills at `~/.claude/skills/` — each entry is a dir or symlink with `skill.md` containing YAML frontmatter fields `name` and `description`. Must resolve symlinks (fs.realpath). |
| TOOL-02 | App auto-scans for configured MCP servers (name, type, description) | No standalone MCP server config. MCP capability = plugin with `.mcp.json` in its cache dir. Read `installed_plugins.json` + check for `.mcp.json` per installed plugin. |
| TOOL-03 | App auto-scans for installed plugins (name, type, description) | `~/.claude/plugins/installed_plugins.json` lists all installed plugins. `.claude-plugin/plugin.json` inside each cache path has `name` and `description`. |
| TOOL-04 | Tools are displayed in a dedicated panel/section in the dashboard | Add third tab "Tools" to existing `ProjectTabs` component; render a list/grid of tool cards. |
</phase_requirements>

---

## Actual `~/.claude/` Directory Structure (Direct Inspection)

This section documents the real files found on this machine. The planner MUST work from these actual paths, not guesses.

```
~/.claude/
├── skills/                          # SKILL SOURCE
│   ├── vf-brand/                    # real directory with skill.md
│   ├── enhance-prompt -> ../../.agents/skills/enhance-prompt   # symlink to dir
│   ├── image-to-video -> ../../.agents/skills/image-to-video
│   ├── remotion -> ../../.agents/skills/remotion
│   ├── stitch-design -> ../../.agents/skills/stitch-design
│   └── stitch-loop -> ../../.agents/skills/stitch-loop
│
├── plugins/                         # PLUGIN + MCP SOURCE
│   ├── installed_plugins.json       # master registry of all installed plugins
│   ├── known_marketplaces.json      # marketplace registry (name -> repo)
│   ├── cache/
│   │   ├── claude-plugins-official/
│   │   │   ├── context7/2cd88e7947b7/
│   │   │   │   ├── .mcp.json        # PRESENT = MCP-backed plugin
│   │   │   │   └── .claude-plugin/plugin.json
│   │   │   ├── playwright/2cd88e7947b7/
│   │   │   │   ├── .mcp.json        # PRESENT = MCP-backed
│   │   │   │   └── .claude-plugin/plugin.json
│   │   │   ├── Notion/0.1.0/
│   │   │   │   ├── .mcp.json        # PRESENT = MCP-backed
│   │   │   │   └── .claude-plugin/plugin.json
│   │   │   ├── firebase/2cd88e7947b7/
│   │   │   │   ├── .mcp.json        # PRESENT = MCP-backed
│   │   │   │   └── .claude-plugin/plugin.json
│   │   │   └── vercel/1.0.0/
│   │   │       └── .claude-plugin/plugin.json   # NO .mcp.json = skill-only
│   │   ├── ui-ux-pro-max-skill/
│   │   │   └── ui-ux-pro-max/2.0.1/ # NO .mcp.json = skill-only
│   │   └── obsidian-skills/
│   │       └── obsidian/1.0.0/      # NO .mcp.json = skill-only
│   │           └── .claude-plugin/plugin.json
│   └── marketplaces/                # DO NOT READ - source metadata only
│
├── settings.json                    # enabledPlugins map (plugin key -> bool)
└── .claude.json  (at ~/.claude.json)  # mcpServers: {} — EMPTY on this machine
```

---

## Data Formats (Direct Inspection)

### Skills: `skill.md` YAML Frontmatter

Every skill directory contains `skill.md` (or `SKILL.md` — case varies). The frontmatter is YAML-delimited by `---`. Fields found:

```yaml
# vf-brand/skill.md — locally authored skill
name: vf-brand
description: Vodafone Brand Design System — Official 10-color palette...
autoInvoke: false
priority: high
triggers:
  - "vodafone"
  - "vf brand"

# enhance-prompt/skill.md — symlinked from ~/.agents/skills/
name: enhance-prompt
description: Transforms vague UI ideas into polished, Stitch-optimized prompts.
allowed-tools:
  - "Read"
  - "Write"
```

**Fields to extract:** `name`, `description` (both always present). `autoInvoke`, `priority`, `triggers` are optional extras.

**Implementation note:** Entries in `~/.claude/skills/` can be symlinks. Must call `fs.realpath()` before reading `skill.md`. Skill filenames vary: `skill.md` (lowercase) and `SKILL.md` (uppercase) both exist. Try both.

### Plugins: `installed_plugins.json`

```json
{
  "version": 2,
  "plugins": {
    "context7@claude-plugins-official": [
      {
        "scope": "user",
        "installPath": "/Users/rob/.claude/plugins/cache/claude-plugins-official/context7/2cd88e7947b7",
        "version": "2cd88e7947b7",
        "installedAt": "2026-02-12T10:51:06.999Z"
      }
    ],
    "obsidian@obsidian-skills": [
      {
        "scope": "user",
        "installPath": "/Users/rob/.claude/plugins/cache/obsidian-skills/obsidian/1.0.0",
        "version": "1.0.0",
        "installedAt": "2026-02-17T08:27:49.460Z"
      }
    ]
  }
}
```

**Key pattern:** `plugins` is an object keyed as `{pluginName}@{marketplace}`. Each value is an array; take `[0]` (first/only scope entry). The `installPath` is the absolute path to the installed plugin cache.

### Plugin Manifests: `.claude-plugin/plugin.json`

```json
// context7 — MCP-backed plugin
{
  "name": "context7",
  "description": "Upstash Context7 MCP server for up-to-date documentation lookup..."
}

// vercel — skill-only plugin
{
  "name": "vercel",
  "version": "1.0.0",
  "description": "Deploy applications to Vercel with deployment monitoring...",
  "author": { "name": "Vercel" },
  "skills": "./skills/",
  "commands": "./commands/"
}

// Notion — MCP-backed plugin
{
  "name": "Notion",
  "version": "0.1.0",
  "description": "Notion Skills + Notion MCP server packaged as a Claude Code plugin."
}
```

**Minimum fields present:** `name` and `description` always present. `version` sometimes missing.

### MCP Detection: `.mcp.json` in Plugin Cache

The ONLY reliable indicator of a plugin being MCP-backed is the presence of `.mcp.json` at the root of the plugin's `installPath`:

```json
// context7/.mcp.json — stdio-based MCP
{ "context7": { "command": "npx", "args": ["-y", "@upstash/context7-mcp"] } }

// Notion/.mcp.json — HTTP-based MCP
{ "mcpServers": { "notion": { "type": "http", "url": "https://mcp.notion.com/mcp" } } }

// firebase/.mcp.json
{ "firebase": { "command": "npx", "args": ["-y", "firebase-tools@latest", "mcp"] } }
```

**Classification logic:** `isMcp = await fs.access(path.join(installPath, '.mcp.json')).then(() => true).catch(() => false)`

### Plugin Enabled State: `settings.json`

```json
{
  "enabledPlugins": {
    "context7@claude-plugins-official": true,
    "playwright@claude-plugins-official": true,
    "Notion@claude-plugins-official": true,
    "vercel@claude-plugins-official": true,
    "firebase@claude-plugins-official": true,
    "ui-ux-pro-max@ui-ux-pro-max-skill": true,
    "obsidian@obsidian-skills": true
  }
}
```

The key format matches the `installed_plugins.json` plugin key exactly.

### CRITICAL: MCP Servers in `~/.claude.json`

`~/.claude.json` has a `mcpServers` key that is **empty `{}` on this machine**. MCP servers configured via CLI (`claude mcp add`) would appear here, but none are configured. The scanner should still read this key and include results if non-empty — but on this machine all MCP capability comes through plugins.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `fs.promises` (Node built-in) | Node 20 | Read `~/.claude/` files | Already used in scanner.ts — zero new deps |
| `js-yaml` | Already installed | Parse YAML frontmatter from `skill.md` | Already in project node_modules |
| shadcn/ui Tabs | Already installed | Add "Tools" tab to existing tab bar | Matches existing ProjectTabs pattern |
| lucide-react | `^0.572.0` (installed) | Icon for Tools tab | Already used in projectTabs.tsx |

### No New Dependencies Required

The entire phase can be implemented with zero `npm install` calls. Everything needed is already in the project.

**Installation:** None needed.

---

## Architecture Patterns

### Recommended New Files

```
pro-orc/
├── lib/
│   └── tools-scanner.ts     # NEW: scanClaudeTools() — mirrors scanner.ts pattern
├── components/
│   └── toolsPanel.tsx       # NEW: renders the tools tab content
└── lib/types.ts             # EDIT: add ClaudeTool interface + ClaudeToolsData type
```

### Pattern 1: tools-scanner.ts follows scanner.ts exactly

**What:** `server-only` module with `Promise.all` concurrent reads, null-safe file reading, returns typed arrays.

**When to use:** Always — this is the established pattern in the codebase.

```typescript
// Source: direct pattern from pro-orc/lib/scanner.ts
import 'server-only'
import { promises as fs } from 'fs'
import path from 'path'
import os from 'os'

const CLAUDE_DIR = path.join(os.homedir(), '.claude')

export interface ClaudeTool {
  id: string           // slug from directory name or plugin key
  name: string         // display name from manifest/frontmatter
  type: 'skill' | 'mcp' | 'plugin'
  description?: string
  version?: string
  enabled?: boolean    // for plugins: from enabledPlugins in settings.json
  marketplace?: string // for plugins: e.g. "claude-plugins-official"
}

export interface ClaudeToolsData {
  skills: ClaudeTool[]
  mcpPlugins: ClaudeTool[]    // plugins with .mcp.json
  skillPlugins: ClaudeTool[]  // plugins without .mcp.json
  scannedAt: string
}
```

### Pattern 2: Skill scanning with symlink resolution

```typescript
// Source: direct observation of ~/.claude/skills/ structure
async function scanSkills(): Promise<ClaudeTool[]> {
  const skillsDir = path.join(CLAUDE_DIR, 'skills')

  let entries: fs.Dirent[]
  try {
    entries = await fs.readdir(skillsDir, { withFileTypes: true })
  } catch {
    return []  // skills dir absent — not an error
  }

  return Promise.all(
    entries
      .filter(e => e.isDirectory() || e.isSymbolicLink())
      .map(async (entry) => {
        const entryPath = path.join(skillsDir, entry.name)
        // Resolve symlinks to actual directory
        const realPath = await fs.realpath(entryPath).catch(() => entryPath)

        // Try both skill.md and SKILL.md (case varies in the wild)
        const skillMd = await readSkillMd(realPath)

        return {
          id: entry.name,
          name: skillMd?.name ?? entry.name,
          type: 'skill' as const,
          description: skillMd?.description,
        }
      })
  )
}

async function readSkillMd(dirPath: string): Promise<{ name?: string; description?: string } | null> {
  // Try lowercase first, then uppercase
  for (const filename of ['skill.md', 'SKILL.md']) {
    try {
      const content = await fs.readFile(path.join(dirPath, filename), 'utf-8')
      if (content.startsWith('---')) {
        // Parse YAML frontmatter — js-yaml already in project
        const yaml = await import('js-yaml')
        const endIdx = content.indexOf('---', 3)
        if (endIdx !== -1) {
          const fm = yaml.load(content.slice(3, endIdx)) as Record<string, unknown>
          return {
            name: fm.name as string | undefined,
            description: fm.description as string | undefined,
          }
        }
      }
    } catch {
      // Try next filename
    }
  }
  return null
}
```

### Pattern 3: Plugin scanning via installed_plugins.json

```typescript
// Source: direct inspection of ~/.claude/plugins/installed_plugins.json
async function scanPlugins(enabledPlugins: Record<string, boolean>): Promise<ClaudeTool[]> {
  const installedPath = path.join(CLAUDE_DIR, 'plugins', 'installed_plugins.json')

  let registry: InstalledPluginsJson
  try {
    const raw = await fs.readFile(installedPath, 'utf-8')
    registry = JSON.parse(raw)
  } catch {
    return []
  }

  return Promise.all(
    Object.entries(registry.plugins).map(async ([key, installs]) => {
      const install = installs[0]  // take first (user-scoped)
      const [pluginName, marketplace] = key.split('@')

      // Read .claude-plugin/plugin.json for display metadata
      const manifestPath = path.join(install.installPath, '.claude-plugin', 'plugin.json')
      let manifest: { name?: string; description?: string; version?: string } = {}
      try {
        manifest = JSON.parse(await fs.readFile(manifestPath, 'utf-8'))
      } catch { /* manifest absent — use key fallback */ }

      // Detect MCP: presence of .mcp.json in the install path
      const isMcp = await fs.access(path.join(install.installPath, '.mcp.json'))
        .then(() => true)
        .catch(() => false)

      return {
        id: key,
        name: manifest.name ?? pluginName,
        type: isMcp ? 'mcp' as const : 'plugin' as const,
        description: manifest.description,
        version: manifest.version ?? install.version,
        enabled: enabledPlugins[key] ?? false,
        marketplace,
      }
    })
  )
}
```

### Pattern 4: Reading settings.json for enabled state

```typescript
// Source: direct inspection of ~/.claude/settings.json
async function readSettings(): Promise<Record<string, boolean>> {
  const settingsPath = path.join(CLAUDE_DIR, 'settings.json')
  try {
    const raw = await fs.readFile(settingsPath, 'utf-8')
    const settings = JSON.parse(raw)
    return settings.enabledPlugins ?? {}
  } catch {
    return {}
  }
}
```

### Pattern 5: Tab integration — add third tab to ProjectTabs

The existing `ProjectTabs` component in `components/projectTabs.tsx` uses shadcn `Tabs`. Adding a Tools tab follows the existing pattern:

```typescript
// Source: pro-orc/components/projectTabs.tsx pattern
<TabsTrigger
  value="tools"
  className={cn(
    triggerBase,
    'data-[state=active]:border-border data-[state=active]:bg-card/60',
    'data-[state=active]:text-primary data-[state=active]:shadow-[0_0_12px_oklch(0.715_0.143_212.34/0.1)]',
  )}
>
  <Wrench className="size-4" />
  Tools
  <span className="rounded-full bg-primary/10 px-2 py-0.5 font-mono text-xs text-primary/80">
    {totalToolCount}
  </span>
</TabsTrigger>
```

The `ClaudeToolsData` must be scanned in `app/page.tsx` (async Server Component) and passed as props to `ProjectTabs`, which passes it to `ToolsPanel`.

### Anti-Patterns to Avoid

- **Reading `~/.claude.json` mcpServers as the MCP source:** It is empty `{}` on this machine. MCP comes from plugin `.mcp.json` files.
- **Assuming skill.md is always lowercase:** Both `skill.md` and `SKILL.md` exist in the wild. Try both.
- **Not resolving symlinks:** `~/.claude/skills/` entries can be symlinks. Calling `fs.readdir` gives the symlink name; must `fs.realpath()` before reading `skill.md`.
- **Using gray-matter for frontmatter:** Not installed. Use `js-yaml` (already installed) with a simple `---` block split.
- **Scanning marketplaces directory:** `~/.claude/plugins/marketplaces/` is the source repository mirror — it has extra content (CLI tools, templates). Use `installed_plugins.json` + the `installPath` cache for the authoritative installed list.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML frontmatter parsing | Custom regex parser | `js-yaml` (already in project) | Handles edge cases; already installed |
| File existence check | `fs.stat()` and check | `fs.access().then(()=>true).catch(()=>false)` | Simpler; matches scanner.ts pattern |
| Symlink resolution | Manual string manipulation | `fs.realpath()` | Handles chained symlinks, cross-platform |

**Key insight:** The data parsing here is structurally simpler than `parser.ts` — all data is in JSON or simple YAML, not free-form markdown with multiple regex patterns.

---

## Common Pitfalls

### Pitfall 1: Empty mcpServers in ~/.claude.json is not a bug
**What goes wrong:** Developer reads `~/.claude.json`, finds `mcpServers: {}`, concludes "no MCP configured" and skips MCP detection.
**Why it happens:** Natural assumption that CLI-configured MCP servers are the source of truth.
**How to avoid:** MCP servers on this machine are entirely delivered through plugins. Detect MCP by checking for `.mcp.json` in each plugin's `installPath`. Still read `~/.claude.json` mcpServers for completeness (CLI-added servers do use it).
**Warning signs:** MCP tab shows 0 items when context7, playwright, firebase, Notion are installed.

### Pitfall 2: Symlinks in skills directory not resolved
**What goes wrong:** `fs.readdir(skillsDir, {withFileTypes: true})` returns a symlink entry; `fs.readFile(path.join(skillsDir, 'enhance-prompt', 'skill.md'))` fails because the symlink points outside the dir.
**Why it happens:** The `path.join` against the symlink path resolves correctly on most systems, but `fs.realpath` is the safe approach.
**How to avoid:** Call `fs.realpath(entryPath)` before reading subdirectory contents.
**Warning signs:** Some skills (the symlinked ones) show with `name = folder-name`, no description.

### Pitfall 3: skill.md filename case sensitivity
**What goes wrong:** Code reads only `skill.md` — misses `SKILL.md` used by symlinked agent skills.
**Why it happens:** vf-brand uses `skill.md`; ~/.agents/skills/enhance-prompt uses `SKILL.md` (uppercase).
**How to avoid:** Try `['skill.md', 'SKILL.md']` in a loop.
**Warning signs:** Symlinked skills show empty descriptions.

### Pitfall 4: installed_plugins.json value is an array
**What goes wrong:** Code does `registry.plugins[key].installPath` — TypeError because value is an array.
**Why it happens:** The JSON structure has each plugin value as `[{ scope, installPath, version, ... }]`.
**How to avoid:** Always access `registry.plugins[key][0].installPath`.
**Warning signs:** Runtime error "Cannot read properties of Array".

### Pitfall 5: Plugin cache path may not match version in .mcp.json key
**What goes wrong:** Trying to derive MCP info from `.mcp.json` structure (it has a top-level key = plugin name, or a `mcpServers` key for HTTP servers).
**Why it happens:** Two formats exist: `{"context7": {...}}` and `{"mcpServers": {"notion": {...}}}`.
**How to avoid:** For the UI, only need to *detect* MCP presence (boolean `isMcp`), not parse the `.mcp.json` content.

---

## Code Examples

### Complete tools-scanner.ts scaffold

```typescript
// Source: direct observation of ~/.claude/ filesystem structure
// pro-orc/lib/tools-scanner.ts
import 'server-only'
import { promises as fs } from 'fs'
import path from 'path'
import os from 'os'

const CLAUDE_DIR = path.join(os.homedir(), '.claude')

export interface ClaudeTool {
  id: string
  name: string
  type: 'skill' | 'mcp' | 'plugin'
  description?: string
  version?: string
  enabled?: boolean
  marketplace?: string
}

export interface ClaudeToolsData {
  skills: ClaudeTool[]
  mcpPlugins: ClaudeTool[]
  skillPlugins: ClaudeTool[]
  scannedAt: string
}

export async function scanClaudeTools(): Promise<ClaudeToolsData> {
  const [skills, allPlugins] = await Promise.all([
    scanSkills(),
    scanAllPlugins(),
  ])

  return {
    skills,
    mcpPlugins: allPlugins.filter(p => p.type === 'mcp'),
    skillPlugins: allPlugins.filter(p => p.type === 'plugin'),
    scannedAt: new Date().toISOString(),
  }
}
```

### page.tsx integration

```typescript
// Source: pro-orc/app/page.tsx pattern
// Add alongside scanProjects():
const [projects, tools] = await Promise.all([
  scanProjects(),
  scanClaudeTools(),
])

// Pass to ProjectTabs:
<ProjectTabs
  codeProjects={codeProjects}
  researchProjects={researchProjects}
  tools={tools}
/>
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MCP servers in `~/.claude.json` mcpServers | MCP via plugin `.mcp.json` | Recent (plugins system) | Scanner must check plugin cache, not just claude.json |
| Skills as standalone files | Skills as directories with `skill.md` | Current | Directory scan + frontmatter parse required |

**Deprecated/outdated:**
- Standalone `mcpServers` CLI configuration via `claude mcp add`: Not present on this machine; plugin system is the primary MCP delivery mechanism.

---

## Open Questions

1. **Are there standalone MCP server configurations on other machines?**
   - What we know: `~/.claude.json` `mcpServers` is `{}` on this machine. Claude Code CLI does support `claude mcp add` which writes to this key.
   - What's unclear: Whether to build the scanner to also read `mcpServers` from `~/.claude.json` for completeness.
   - Recommendation: YES — include it. Read both plugin `.mcp.json` (primary source here) AND `~/.claude.json` mcpServers (for any CLI-added servers). Merge into the `mcpPlugins` list with `marketplace: undefined`.

2. **What if `installed_plugins.json` has an empty `plugins` object?**
   - What we know: On fresh Claude installs, plugins may not be configured.
   - What's unclear: Whether the file itself exists or not.
   - Recommendation: Wrap in try/catch returning `[]` on any error — same null-safety pattern as `scanner.ts`.

3. **Should enabled/disabled state affect what's shown in the panel?**
   - What we know: `settings.json` `enabledPlugins` has boolean values per plugin key.
   - What's unclear: Whether to show disabled plugins at all, or show with a visual indicator.
   - Recommendation: Show all installed (enabled or not) with a visual enabled/disabled badge. Provides visibility into what's installed vs. active.

---

## Sources

### Primary (HIGH confidence — direct filesystem inspection)

- `~/.claude/skills/` — directly listed, two skill.md files read
- `~/.claude/plugins/installed_plugins.json` — read in full (7 installed plugins)
- `~/.claude/plugins/cache/claude-plugins-official/*/\.claude-plugin/plugin.json` — 5 plugin manifests read
- `~/.claude/plugins/cache/claude-plugins-official/*/.mcp.json` — 4 MCP files read
- `~/.claude/settings.json` — read in full (enabledPlugins confirmed)
- `~/.claude.json` — read in full (mcpServers confirmed empty `{}`)
- `pro-orc/lib/scanner.ts` — read for implementation pattern
- `pro-orc/lib/parser.ts` — read for frontmatter parsing approach
- `pro-orc/lib/types.ts` — read for type definition patterns
- `pro-orc/lib/paths.ts` — confirmed `PATHS.claude` already defined
- `pro-orc/package.json` — confirmed js-yaml installed, no gray-matter

### Secondary (MEDIUM confidence)

- None required — all data from direct inspection

---

## Metadata

**Confidence breakdown:**
- File structures and paths: HIGH — directly read from disk
- Plugin manifest formats: HIGH — 5+ plugin.json files read
- MCP detection via .mcp.json: HIGH — 4 .mcp.json files confirmed
- Implementation patterns: HIGH — directly mirrors existing scanner.ts
- js-yaml availability: HIGH — confirmed in node_modules

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable — filesystem structure unlikely to change; check if new plugins are installed)
