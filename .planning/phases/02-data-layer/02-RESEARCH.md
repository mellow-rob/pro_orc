# Phase 2: Data Layer - Research

**Researched:** 2026-02-17
**Domain:** Node.js filesystem scanning, Markdown parsing, simple-git async operations
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SCAN-01 | App auto-scans ~/project_orchestration/code/ for projects | `fs.promises.readdir` with `withFileTypes:true`; filter dirs not starting with `.`; PATHS.code from lib/paths.ts |
| SCAN-02 | App auto-scans ~/project_orchestration/project research/ for projects | Same pattern; path has space — always use PATHS.research from lib/paths.ts, never string literals |
| SCAN-03 | App automatically detects project type (code vs research) | Type is determined by WHICH root dir it came from, not by .git presence (some code projects have no git) |
| SCAN-04 | App parses .planning/STATE.md to extract current phase and next step | Regex-based extraction; STATE.md format varies across projects (German/English, `**Phase:**` vs `**Current Phase:**`); use optional chaining, fallback to undefined |
| SCAN-05 | App parses .planning/ROADMAP.md to extract phase structure and progress | Count `- [x]` vs `- [ ]` checkbox lines for phaseProgress; phase count from `## Phase N:` headings |
| SCAN-06 | App parses .planning/PROJECT.md to extract project name and Notion URL | Project name = first `# Heading`; Notion URL = `<!-- notion: URL -->` comment convention (NEW — no projects use it yet) |
| SCAN-07 | App handles missing .planning/ directory gracefully (no crash, shows "no GSD data") | Wrap all .planning/ reads in try/catch; on ENOENT → return partial BaseProject with gsdStatus undefined |
| SCAN-08 | App handles malformed or mid-save files gracefully (no crash, uses last good state) | Defensive parsing: each regex match checks `?? undefined`; parser returns partial data rather than throwing |
| GIT-01 | App shows last commit timestamp per project (async, non-blocking) | `git.log({ maxCount: 1 })` → `result.latest?.date` — ISO 8601 string |
| GIT-02 | App shows last commit message per project | `git.log({ maxCount: 1 })` → `result.latest?.message` |
| GIT-03 | Git calls run concurrently via Promise.allSettled | `Promise.allSettled(projects.map(p => getGitData(p)))` — never rejects, fulfilled/rejected per entry |
| GIT-04 | Git calls have explicit 5s timeout | `simpleGit({ baseDir, timeout: { block: 5000, stdOut: false, stdErr: false } })` — absolute timeout (no reset on data) |
| GIT-05 | Non-git directories are handled gracefully (no error, no git metrics shown) | Catch block around `git.log()` catches "not a git repository" error; return `undefined` git fields |
</phase_requirements>

---

## Summary

Phase 2 builds three pure-Node.js modules — a Scanner, a Parser, and a Git Reader — that together produce fully typed `Project[]` arrays matching the `CodeProject` and `ResearchProject` interfaces already defined in `lib/types.ts`. All three modules run only on the server (Next.js Route Handlers or standalone scripts) and have no UI dependencies. Testing in isolation means running them as small scripts against real directories before any API route or component calls them.

The core technologies are already installed and configured: `simple-git ^3.31.1` for git operations and Node.js built-in `fs/promises` for filesystem access. No new dependencies are required. The entire data layer is pure async TypeScript with `Promise.allSettled` for concurrency and try/catch everywhere for resilience.

The trickiest domain problem is STATE.md parsing: the format evolved organically and varies across projects (German vs. English field names, different separators, different section structures). The correct approach is liberal regex with optional matches — extract what you can, return `undefined` for anything you can't find. Never throw; never crash.

**Primary recommendation:** Build the three modules in this order: Scanner (simplest, establishes the project list) → Parser (regex-based, exercised against real projects immediately) → Git Reader (async, concurrency, timeout). Test each in isolation with a small `node -e` script before wiring to any route.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `fs/promises` (Node built-in) | Node 20+ | Read directory entries and file contents | Zero dependency, Promise-native API |
| `simple-git` | 3.31.1 (installed) | Run `git log` per project directory | Already installed, strong TypeScript types, built-in timeout and abort support |
| `os` (Node built-in) | Node 20+ | `os.homedir()` for path resolution | Already used in lib/paths.ts |
| `path` (Node built-in) | Node 20+ | Path joining and manipulation | Already used in lib/paths.ts |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `server-only` | installed with Next.js | Prevent accidental client import | Add to every scanner/parser/git-reader file header |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `fs/promises.readdir` | `glob` or `fast-glob` | readdir is sufficient for flat one-level directory listing; glob adds dependency overhead not needed here |
| `simple-git` | `child_process.exec('git log ...')` | simple-git provides typed responses, timeout plugin, abort support; exec requires manual parsing |
| regex-based STATE.md parsing | `unified`/`remark` markdown AST | AST parsers are robust but heavyweight; the data needed (bold key-value pairs) is reliably captured by 3-4 regexes |

**Installation:** No new packages required — everything is already in package.json.

---

## Architecture Patterns

### Recommended Project Structure

```
pro-orc/lib/
├── types.ts          # Already built (Phase 1)
├── paths.ts          # Already built (Phase 1)
├── utils.ts          # Already built (Phase 1)
├── scanner.ts        # NEW: reads code/ and research/ dirs → Project[]
├── parser.ts         # NEW: reads .planning/ files → GSD fields
└── git-reader.ts     # NEW: runs git log per project → git fields
```

All three new files live in `lib/` alongside the Phase 1 deliverables. They are server-only modules (no `'use client'` possible; import `server-only` at the top).

### Pattern 1: Scanner — Directory Listing with Type Discrimination

**What:** Read both root directories, filter to non-hidden subdirectories, assign type from which root dir the project was found in.

**When to use:** Called once per scan cycle; results are the input to the parser and git reader.

**Example:**
```typescript
// lib/scanner.ts
import 'server-only'
import { promises as fs } from 'fs'
import path from 'path'
import { PATHS, projectIdFromPath, planningDir } from '@/lib/paths'
import type { Project } from '@/lib/types'
import { parseGsdData } from '@/lib/parser'
import { getGitData } from '@/lib/git-reader'

async function scanDir(rootPath: string, type: 'code' | 'research'): Promise<Project[]> {
  const entries = await fs.readdir(rootPath, { withFileTypes: true })
  const dirs = entries.filter(e => e.isDirectory() && !e.name.startsWith('.'))

  return Promise.all(
    dirs.map(async (entry) => {
      const projectPath = path.join(rootPath, entry.name)
      const id = projectIdFromPath(projectPath)
      const name = entry.name  // display name before slugification
      const gsdData = await parseGsdData(projectPath)

      if (type === 'code') {
        const gitData = await getGitData(projectPath)
        return { id, name, path: projectPath, type: 'code', ...gsdData, ...gitData }
      }
      return { id, name, path: projectPath, type: 'research', ...gsdData }
    })
  )
}

export async function scanProjects(): Promise<Project[]> {
  const [codeProjects, researchProjects] = await Promise.all([
    scanDir(PATHS.code, 'code').catch(() => []),
    scanDir(PATHS.research, 'research').catch(() => []),
  ])
  return [...codeProjects, ...researchProjects]
}
```

### Pattern 2: Parser — Defensive Regex on Markdown Files

**What:** Read up to three .planning/ files (STATE.md, ROADMAP.md, PROJECT.md), parse with lenient regex, return partial data if any file is missing or malformed.

**When to use:** Called per project after the scanner identifies directories.

**Example:**
```typescript
// lib/parser.ts
import 'server-only'
import { promises as fs } from 'fs'
import { planningDir } from '@/lib/paths'
import type { GsdStatus } from '@/lib/types'

async function readFile(filePath: string): Promise<string | null> {
  try {
    return await fs.readFile(filePath, 'utf-8')
  } catch {
    return null  // ENOENT, EACCES, or mid-save corruption — all treated as missing
  }
}

export interface GsdParseResult {
  gsdStatus?: GsdStatus
  currentPhase?: string
  nextStep?: string
  phaseProgress?: number
  notionUrl?: string
}

export async function parseGsdData(projectPath: string): Promise<GsdParseResult> {
  const dir = planningDir(projectPath)

  // Read all three files concurrently — each independently null-safe
  const [stateContent, roadmapContent, projectContent] = await Promise.all([
    readFile(`${dir}/STATE.md`),
    readFile(`${dir}/ROADMAP.md`),
    readFile(`${dir}/PROJECT.md`),
  ])

  if (!stateContent && !roadmapContent && !projectContent) {
    return {}  // No .planning/ data — not an error, just "no GSD data"
  }

  return {
    ...parseState(stateContent),
    ...parseRoadmap(roadmapContent),
    ...parseProject(projectContent),
  }
}
```

### Pattern 3: STATE.md Parsing — Multiple Regex Candidates

**What:** STATE.md has two major format variants (and edge cases). Use multiple regex patterns with fallback.

**Critical insight:** Never assume field names. Try both German and English variants. Return `undefined` on no match — never throw.

```typescript
// Inside parser.ts
function parseState(content: string | null): Pick<GsdParseResult, 'gsdStatus' | 'currentPhase' | 'nextStep'> {
  if (!content) return {}

  // Current Phase — multiple field name variants seen in real projects
  const phasePatterns = [
    /^\*\*Phase:\*\*\s*(.+)$/m,           // "**Phase:** 3 of 4 (User Interface)"
    /^\*\*Current Phase:\*\*\s*(.+)$/m,   // "**Current Phase:** 3 of 3 -- COMPLETE"
    /^\*\*Aktuelle Phase:\*\*\s*(.+)$/m,  // German variant (hypothetical)
  ]
  let currentPhase: string | undefined
  for (const pattern of phasePatterns) {
    const match = content.match(pattern)
    if (match) { currentPhase = match[1].trim(); break }
  }

  // Status — derive GsdStatus from STATUS field
  const statusMatch = content.match(/^\*\*Status:\*\*\s*(.+)$/m)
  const statusRaw = statusMatch?.[1]?.trim().toLowerCase() ?? ''
  const gsdStatus: GsdStatus | undefined = deriveStatus(statusRaw)

  // Next step — multiple variants
  const nextStepPatterns = [
    /^\*\*Next Action:\*\*\s*(.+)$/m,
    /^\*\*Next Step:\*\*\s*(.+)$/m,
    /^\*\*Nächster Schritt:\*\*\s*(.+)$/m,
  ]
  let nextStep: string | undefined
  for (const pattern of nextStepPatterns) {
    const match = content.match(pattern)
    if (match) { nextStep = match[1].trim(); break }
  }

  return { gsdStatus, currentPhase, nextStep }
}
```

### Pattern 4: ROADMAP.md Phase Progress — Checkbox Counting

**What:** Count completed (`- [x]`) vs total (`- [x]` + `- [ ]`) plan checkboxes in ROADMAP.md.

**Why:** This is the most reliable progress signal — it's updated every time a plan completes.

```typescript
function parseRoadmap(content: string | null): Pick<GsdParseResult, 'phaseProgress'> {
  if (!content) return {}

  const completed = (content.match(/^- \[x\]/gim) ?? []).length
  const pending = (content.match(/^- \[ \]/gim) ?? []).length
  const total = completed + pending

  if (total === 0) return {}  // No plan checkboxes found — don't return 0%, return undefined

  return { phaseProgress: Math.round((completed / total) * 100) }
}
```

### Pattern 5: PROJECT.md — H1 Name + HTML Comment for Notion URL

**What:** Extract the project display name from the first `# Heading` and the Notion URL from an HTML comment.

**The convention (NEW):** `<!-- notion: https://notion.so/... -->` — no projects use this yet; parser must handle its absence gracefully.

```typescript
function parseProject(content: string | null): Pick<GsdParseResult, 'notionUrl'> {
  if (!content) return {}

  // HTML comment convention — will be absent in most projects initially
  const notionMatch = content.match(/<!--\s*notion:\s*(https?:\/\/[^\s>]+)\s*-->/)
  return { notionUrl: notionMatch?.[1] }
}

// Note: project "name" comes from the directory entry.name in the scanner,
// NOT from PROJECT.md — simpler and more reliable
```

### Pattern 6: Git Reader — Per-Project Instance with Timeout

**What:** Create a separate `simpleGit` instance per project directory with a hard timeout. Catch all errors silently.

**Critical insight:** The timeout uses `stdOut: false, stdErr: false` to make it ABSOLUTE (5s kills the process regardless of output). Without this, git operations on network-mounted or slow dirs spin forever.

```typescript
// lib/git-reader.ts
import 'server-only'
import { simpleGit } from 'simple-git'
import type { CodeProject } from '@/lib/types'

type GitFields = Pick<CodeProject, 'lastCommitMessage' | 'lastCommitTimestamp' | 'lastCommitSha' | 'branch' | 'isDirty'>

export async function getGitData(projectPath: string): Promise<GitFields> {
  const git = simpleGit({
    baseDir: projectPath,
    timeout: {
      block: 5000,   // Kill after 5 seconds
      stdOut: false, // Do NOT reset timer when stdout receives data — absolute timeout
      stdErr: false, // Same for stderr
    },
  })

  try {
    const log = await git.log({ maxCount: 1 })
    const latest = log.latest  // null if repo has no commits

    return {
      lastCommitMessage: latest?.message ?? undefined,
      lastCommitTimestamp: latest?.date ?? undefined,
      lastCommitSha: latest?.hash?.slice(0, 7) ?? undefined,
    }
  } catch {
    // "fatal: not a git repository" — expected for non-git dirs
    // GitPluginError with plugin === 'timeout' — expected for slow dirs
    return {}  // Return no git fields — not an error condition
  }
}
```

### Pattern 7: Concurrent Git Calls — Promise.allSettled

**What:** Run all git readers concurrently across the project list, never letting one failure block others.

**Why `allSettled` not `all`:** `Promise.all` rejects on first failure. With git, individual project failures (non-git dir, timeout) are normal — `allSettled` collects all results.

```typescript
// In scanner.ts — or a caller that assembles projects
export async function enrichWithGitData(projects: CodeProject[]): Promise<CodeProject[]> {
  const results = await Promise.allSettled(
    projects.map(p => getGitData(p.path))
  )

  return projects.map((project, i) => {
    const result = results[i]
    if (result.status === 'fulfilled') {
      return { ...project, ...result.value }
    }
    return project  // rejected — git data simply absent
  })
}
```

### Anti-Patterns to Avoid

- **Reading `.planning/` synchronously:** Always `await fs.readFile(...)` — never `fs.readFileSync()`. Next.js Route Handlers run on the event loop; sync file I/O blocks ALL requests.
- **Sharing one `simpleGit` instance across projects:** Each `simpleGit()` call creates an instance bound to a `baseDir`. Create one per project, per call — they are lightweight.
- **Throwing from parser functions:** Parser functions must never throw. Wrap every regex in optional chaining. Return `{}` on any failure.
- **Using directory name as display name from `projectIdFromPath`:** `projectIdFromPath` slugifies the name (lowercases, replaces spaces). Keep the raw `entry.name` as the display `name`; only use `projectIdFromPath` for the `id` field.
- **Filtering projects by .git presence to determine type:** Type is determined by WHICH scan root (code/ vs research/). Some code projects have no git (agentic_team, leveldevil, loadOFF).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Git command execution | `child_process.exec('git log ...')` | `simple-git` with `timeout` config | simple-git handles process lifecycle, timeout/kill, error parsing, TypeScript types |
| Directory walking | Recursive `readdir` traversal | `fs.readdir` with `depth: 1` (flat scan) | Projects are ONE level deep in code/ and research/ — no recursion needed |
| File existence checking | `fs.access` before `fs.readFile` | Try-catch on `fs.readFile` directly | TOCTOU race condition; simpler code; one fewer syscall |
| Promise timeout | `Promise.race` + `setTimeout` | `simpleGit({ timeout: { block: 5000 } })` | Built-in plugin handles SIGKILL correctly; manual races leave processes running |

**Key insight:** The data layer is 95% plumbing. Every problem here has a solved solution. The only custom logic is the regex patterns for STATE.md/ROADMAP.md/PROJECT.md, which is inherently domain-specific.

---

## Common Pitfalls

### Pitfall 1: Hidden Directories in Scan Roots

**What goes wrong:** `code/` contains `.git` (the root orchestration repo) and `.venv` — these are not projects. Returning them breaks the type system (no name, no id, no valid path context).

**Why it happens:** `fs.readdir` returns all entries including hidden directories.

**How to avoid:** Filter `entry.isDirectory() && !entry.name.startsWith('.')` before processing.

**Warning signs:** Projects array includes entries named `.git` or `.venv`.

### Pitfall 2: STATE.md Format Variations Break Parsers

**What goes wrong:** A regex written for `**Phase:** X` misses `**Current Phase:** X` or the German `**Aktuelle Position:**` table format (as seen in noa_planing STATE.md which uses `| **Phase** | value |` table rows).

**Why it happens:** STATE.md is a human-maintained file. The GSD tooling evolved; older projects used different conventions. Language varies (German vs English).

**How to avoid:** Use an array of regex patterns tried in order. Return `undefined` if none match — not an error. Test against ALL real projects during development.

**Warning signs:** Most projects show undefined for currentPhase even when STATE.md has phase data.

### Pitfall 3: Git Timeout Not Actually Absolute

**What goes wrong:** `simpleGit({ timeout: { block: 5000 } })` defaults to `stdOut: true, stdErr: true`, which RESETS the timer every time git writes output. A slow git pack operation that writes every 200ms never times out.

**Why it happens:** The default timeout behavior is optimistic (assumes data flow = progress).

**How to avoid:** Set `stdOut: false, stdErr: false` explicitly for an absolute 5-second hard limit.

**Warning signs:** A project's git call takes 30+ seconds during scanner run.

### Pitfall 4: phaseProgress Returns 0% on Projects with No Checkboxes

**What goes wrong:** ROADMAP.md for completed milestones (like landlord_checker_gsd) shows no `- [x]` checkboxes — they list completed milestones, not plan checkboxes. Returning 0/0 = 0% is wrong.

**Why it happens:** Completed milestones archive their ROADMAP entries into plain text, not checkbox format.

**How to avoid:** Check `if (total === 0) return {}` — return no phaseProgress rather than 0. The UI handles `undefined` as "no progress data."

**Warning signs:** Completed projects showing 0% progress bar.

### Pitfall 5: Display Name vs ID Confusion

**What goes wrong:** `projectIdFromPath("Landlord Checker")` → `"landlord-checker"`. If you display the id as the name, users see `landlord-checker` instead of `Landlord Checker`.

**Why it happens:** `projectIdFromPath` is designed for stable programmatic IDs, not display names.

**How to avoid:** In the scanner, store `entry.name` as the `name` field (raw directory name). The `id` field gets the slugified version. These are separate fields on `BaseProject`.

**Warning signs:** Project cards show slugified lowercase names.

### Pitfall 6: Notion URL Convention Has No Existing Examples

**What goes wrong:** Building a complex parser for `<!-- notion: URL -->` only to find it never appears in real files, then discovering projects use a completely different convention.

**Why it happens:** The `<!-- notion: URL -->` convention is PLANNED but not yet implemented in any project's PROJECT.md.

**How to avoid:** The regex must be written, but it will return `undefined` for all current projects. This is correct and expected. Don't validate the parser by checking existing files — test by writing a temporary PROJECT.md with the comment.

**Warning signs:** notionUrl always undefined even after adding the convention to PROJECT.md.

---

## Code Examples

Verified patterns from the installed `simple-git@3.31.1` source:

### DefaultLogFields Interface (from installed typings)
```typescript
// Source: pro-orc/node_modules/simple-git/dist/src/lib/tasks/log.d.ts
export interface DefaultLogFields {
  hash: string;    // full commit SHA
  date: string;    // ISO 8601 date string (author date)
  message: string; // commit subject line
  refs: string;    // branch/tag refs
  body: string;    // commit body
  author_name: string;
  author_email: string;
}

// LogResult (from response.d.ts)
export interface LogResult<T = DefaultLogFields> {
  all: ReadonlyArray<T & ListLogLine>;
  total: number;
  latest: (T & ListLogLine) | null;  // null if repo has no commits
}
```

### Timeout Configuration (from installed types/index.d.ts)
```typescript
// Source: pro-orc/node_modules/simple-git/dist/src/lib/types/index.d.ts
// timeout is a direct constructor option — no separate plugin import needed
const git = simpleGit({
  baseDir: '/path/to/project',
  timeout: {
    block: 5000,   // ms before SIGKILL
    stdOut: false, // don't reset timer on stdout (absolute timeout)
    stdErr: false, // don't reset timer on stderr (absolute timeout)
  }
})
```

### AbortController (also available in v3.31.1)
```typescript
// Source: pro-orc/node_modules/simple-git/dist/src/lib/plugins/abort-plugin.d.ts
// Available but NOT needed for this phase — timeout handles the 5s requirement
const controller = new AbortController()
const git = simpleGit({ baseDir, abort: controller.signal })
// controller.abort() cancels pending operations
// Catch GitPluginError where err.plugin === 'abort'
```

### fs.promises.readdir with withFileTypes
```typescript
// Source: Node.js v20 official docs (nodejs.org/api/fs.html)
import { promises as fs } from 'fs'

const entries = await fs.readdir('/path/to/dir', { withFileTypes: true })
// entries: Dirent[]
// entry.isDirectory() — true if directory
// entry.isFile() — true if file
// entry.name — filename string (not full path)
```

### Complete git reader with error handling
```typescript
// Verified pattern — handles both non-git dirs and timeout
import { simpleGit, GitPluginError } from 'simple-git'

async function getGitData(projectPath: string) {
  const git = simpleGit({
    baseDir: projectPath,
    timeout: { block: 5000, stdOut: false, stdErr: false },
  })
  try {
    const log = await git.log({ maxCount: 1 })
    if (!log.latest) return {}  // repo exists but has no commits
    return {
      lastCommitMessage: log.latest.message,
      lastCommitTimestamp: log.latest.date,
      lastCommitSha: log.latest.hash.slice(0, 7),
    }
  } catch (err) {
    // "fatal: not a git repository" → err message contains this string
    // GitPluginError with err.plugin === 'timeout' → 5s exceeded
    // Both are expected, non-fatal — return empty git data
    return {}
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `simple-git` callback API | `async/await` via `.log()` returning Promise | v2+ | Clean, no callback hell |
| Separate timeout via `Promise.race` | Built-in `timeout: { block: N }` constructor option | simple-git v3 | Process is actually killed (SIGKILL), not just abandoned |
| `fs.readFile` with callbacks | `fs.promises.readFile` / `import { promises as fs }` | Node 10+ | Standard in 2025 — callbacks are legacy |
| `chokidar` v4 ESM-only | chokidar v3 with CJS compatibility | chokidar v4 release | Decision already made; v3 is the correct choice for Next.js |

**Deprecated/outdated:**
- `git.raw(['log', '--pretty=...'])`: Don't parse raw git output manually — use `git.log()` which parses for you.
- `simple-git/promise` import: In v3+, `simpleGit()` already returns Promise-based API. The `simple-git/promise` re-export is for backward compat only.
- Synchronous `fs.readdirSync` / `fs.readFileSync`: Never in Next.js Route Handlers — blocks the event loop.

---

## Open Questions

1. **Project name source: directory name vs PROJECT.md H1**
   - What we know: Entry `entry.name` gives the raw directory name (e.g., `landlord_checker_gsd`). PROJECT.md H1 gives a human-readable name (e.g., `Landlord Checker`).
   - What's unclear: The planner must decide which to use as `BaseProject.name`. Directory name is always available; PROJECT.md name requires reading another file and may differ from expectations.
   - Recommendation: Use `entry.name` as the display name (it's what the user sees in Finder). Strip only trailing `_gsd` suffix if desired. Reading PROJECT.md for the name adds a file read with uncertain benefit. **Flag for planner to decide.**

2. **GsdStatus derivation from STATE.md**
   - What we know: The `GsdStatus` type has known values: `research | planning | building | paused | done | archived`. The STATUS field in STATE.md uses free-form text like "Phase 3 in progress", "Milestone complete", "Phase complete".
   - What's unclear: The exact mapping rules. Does "Phase 3 in progress" → `building`? Does "Milestone complete" → `done`?
   - Recommendation: Map conservatively: "complete" → `done`, "archived" → `archived`, "paused" → `paused`, anything with "progress" or "in progress" → `building`. Default to `building` if any phase is mentioned. **Flag for planner to define mapping table.**

3. **branch and isDirty fields on CodeProject**
   - What we know: `CodeProject` has `branch?: string` and `isDirty?: boolean` fields. `simple-git` can get these via `git.status()`.
   - What's unclear: Whether this phase should populate them. `git.status()` is a second git call per project and doubles the git I/O.
   - Recommendation: Defer `branch` and `isDirty` to Phase 3 when cards are built and it's clear whether the UI needs them. Phase 2 only populates `lastCommitMessage`, `lastCommitTimestamp`, `lastCommitSha`. **Flag for planner.**

4. **Scanner entry for the pro-orc app itself**
   - What we know: `pro-orc/` lives in `~/project_orchestration/` root, NOT in `code/` or `project research/`. The scanner only reads `code/` and `research/`.
   - What's unclear: Nothing — this is confirmed. The app scanning itself is not a requirement.
   - Recommendation: No action needed; document clearly so no one adds the app's own dir to scan roots.

---

## Sources

### Primary (HIGH confidence)
- `pro-orc/node_modules/simple-git/dist/src/lib/tasks/log.d.ts` — DefaultLogFields interface verified from installed package
- `pro-orc/node_modules/simple-git/dist/src/lib/types/index.d.ts` — timeout and abort plugin options verified from installed package
- `pro-orc/node_modules/simple-git/dist/typings/response.d.ts` — LogResult interface with `latest: T | null`
- `pro-orc/node_modules/chokidar/types/index.d.ts` — FSWatcher API verified from installed package (v3.6.0)
- `pro-orc/lib/types.ts` — Phase 1 types (CodeProject, ResearchProject, BaseProject, GsdStatus) — already built
- `pro-orc/lib/paths.ts` — PATHS.code, PATHS.research, planningDir(), projectIdFromPath() — already built
- Node.js 20 fs/promises — official Node.js API (stable)
- `github.com/steveukx/git-js/blob/main/docs/PLUGIN-TIMEOUT.md` — timeout plugin documentation
- `github.com/steveukx/git-js/blob/main/docs/PLUGIN-ABORT-CONTROLLER.md` — abort plugin documentation

### Secondary (MEDIUM confidence)
- Real-world inspection of STATE.md files across 7 code projects — format variation patterns documented from actual files
- Real-world inspection of ROADMAP.md files — checkbox counting pattern verified against actual files
- WebFetch of simple-git README (github.com) — constructor and log() API confirmed

### Tertiary (LOW confidence)
- GsdStatus derivation mapping (Open Question 2) — inferred from real STATUS field values, mapping rules not formally defined

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified against installed package versions
- Architecture: HIGH — patterns derived from real project file inspection, not hypothetical
- STATE.md regex patterns: MEDIUM — tested mentally against 7 real files; actual regex needs empirical testing during implementation
- Pitfalls: HIGH — all from direct inspection of real project data (hidden dirs, format variations, checkpoint counting edge cases)

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (stable domain — Node.js fs API and simple-git 3.x are stable)
