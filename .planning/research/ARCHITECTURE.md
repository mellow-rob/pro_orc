# Architecture Patterns

**Domain:** Local Next.js developer dashboard with filesystem monitoring, SSE streaming, git integration, and markdown parsing
**Project:** Pro Orc
**Researched:** 2026-02-17
**Confidence:** HIGH (based on verified Next.js 15.2 official docs + established patterns)

---

## Recommended Architecture

Pro Orc is a single-process, single-user local tool. The architecture is deliberately simple: **one singleton watcher that pushes events to subscribed SSE connections, with filesystem as the only data source**. There is no database, no auth layer, no external API. Complexity lives in the watcher-to-SSE bridge and in parsing .planning/ files correctly.

```
┌─────────────────────────────────────────────────────────────┐
│  NEXT.JS PROCESS (localhost:3000)                            │
│                                                              │
│  instrumentation.ts                                          │
│  └─ register() [called once on server start]                 │
│     └─ WatcherService.init()  ←── singleton guard           │
│        ├─ chokidar.watch([code/, project research/])         │
│        └─ EventBus (in-memory EventEmitter)                  │
│                                                              │
│  Route Handlers (app/api/)                                   │
│  ├─ GET /api/sse          → ReadableStream, subscribes to    │
│  │                          EventBus, streams SSE events     │
│  ├─ GET /api/projects     → initial snapshot (all projects)  │
│  ├─ GET /api/projects/[id]→ single project data             │
│  └─ GET /api/tools        → Claude tools inventory          │
│                                                              │
│  Lib Layer (lib/)                                            │
│  ├─ scanner.ts            → fs.readdir + path resolution     │
│  ├─ parser.ts             → STATE.md, ROADMAP.md, PROJECT.md │
│  ├─ git-reader.ts         → simple-git with timeout wrapper  │
│  └─ tools-reader.ts       → ~/.claude/ inventory             │
│                                                              │
│  React UI (app/, components/)                                │
│  ├─ Server Components     → initial render (projects page)   │
│  ├─ Client Components     → SSE listener, card updates       │
│  └─ shadcn/ui + Tailwind  → layout, cards, badges           │
└─────────────────────────────────────────────────────────────┘

  Browser (EventSource API)
  └─ useSSE hook  → EventSource('/api/sse')
     └─ on message → update React state → re-render cards
```

---

## Component Boundaries

| Component | File Location | Responsibility | Communicates With |
|-----------|--------------|----------------|-------------------|
| WatcherService | `lib/watcher.ts` | Singleton chokidar instance, emits normalized change events | EventBus |
| EventBus | `lib/event-bus.ts` | In-memory EventEmitter, fan-out to N SSE subscribers | WatcherService (receives), SSE Route Handler (provides) |
| SSE Route Handler | `app/api/sse/route.ts` | Holds open HTTP connection, subscribes to EventBus, formats SSE protocol | EventBus, Browser |
| Scanner | `lib/scanner.ts` | Reads directory trees for code/ and project research/, classifies project types | Parser, Git Reader |
| Parser | `lib/parser.ts` | Parses .planning/STATE.md, ROADMAP.md, PROJECT.md — extracts status, phase, next step, Notion URL | Scanner output, Route Handlers |
| Git Reader | `lib/git-reader.ts` | simple-git async calls wrapped in Promise.allSettled + 5s timeout, returns last commit info | Scanner output, Route Handlers |
| Tools Reader | `lib/tools-reader.ts` | Reads ~/.claude/ for skills, MCP configs, plugins | Route Handlers |
| Projects Route | `app/api/projects/route.ts` | Snapshot of all projects (scanner + parser + git in parallel) | Scanner, Parser, Git Reader |
| Tools Route | `app/api/tools/route.ts` | Claude tools inventory | Tools Reader |
| Instrumentation | `instrumentation.ts` | Server startup hook — initializes WatcherService once | WatcherService |
| ProjectGrid (Server) | `app/page.tsx` | Initial server render of all project cards | Projects Route (fetch on server) |
| SSEListener (Client) | `components/sse-listener.tsx` | Manages EventSource lifecycle, updates project state | SSE Route, React state |
| ProjectCard (Client) | `components/project-card.tsx` | Renders single project, receives updates via SSEListener context | SSEListener |
| ToolsPanel (Server) | `app/tools/page.tsx` | Renders Claude tools inventory (static, no SSE needed) | Tools Route |

---

## Data Flow

### Initial Page Load

```
Browser request → app/page.tsx (Server Component)
  └─ fetch('/api/projects')
       └─ Scanner.scan([code/, project research/])
            ├─ per project: Parser.parse(.planning/)
            └─ per code project: GitReader.read(projectPath)
                                 [Promise.allSettled, 5s timeout]
  └─ return ProjectGrid with all project data rendered
  └─ hydrate SSEListener Client Component
```

### Live Update (File Change)

```
File changes on disk
  └─ chokidar emits 'change'/'add'/'unlink' event
       └─ WatcherService normalizes → determines affected project
            └─ EventBus.emit('project:updated', { projectId, path })
                 └─ SSE Route Handler (subscribed via EventBus)
                      └─ controller.enqueue(sseFormattedEvent)
                           └─ Browser EventSource fires onmessage
                                └─ useSSE hook dispatches to React state
                                     └─ ProjectCard re-renders
```

### SSE Event Format

```
data: {"type":"project:updated","projectId":"landlord-checker","changedFile":".planning/STATE.md"}\n\n
data: {"type":"project:added","projectId":"new-project","path":"/code/new-project"}\n\n
data: {"type":"project:removed","projectId":"old-project"}\n\n
data: {"type":"ping"}\n\n
```

The browser triggers a re-fetch of `/api/projects/[projectId]` on `project:updated` — it does NOT send full project data over SSE. SSE only signals "something changed, refresh this project." This keeps the SSE channel lightweight and avoids serialization complexity.

### Git Data Flow

```
GitReader.read(path)
  └─ Promise.allSettled([
       git.log({ maxCount: 1 }),      // last commit
       git.status(),                   // clean/dirty
       git.branch()                    // current branch
     ], { timeout: 5000 })
  └─ return { lastCommit, status, branch } | { error: 'timeout' | 'not-a-repo' }
```

Git failures are non-fatal. Projects without git show "no git" gracefully. Research projects skip git entirely.

### Markdown Parsing Data Flow

```
Parser.parse(projectPath)
  └─ fs.readFile('.planning/STATE.md')    → current phase, status, next step
  └─ fs.readFile('.planning/ROADMAP.md')  → total phases, completed phases
  └─ fs.readFile('.planning/PROJECT.md')  → project name, Notion URL comment
  └─ returns ProjectData { name, status, phase, nextStep, progress, notionUrl }
```

Notion URL extracted from HTML comment: `<!-- notion: https://notion.so/... -->` in PROJECT.md header.

---

## Patterns to Follow

### Pattern 1: Singleton Guard in WatcherService

**What:** Module-level variable guards against multiple watcher instances during Next.js dev mode HMR.
**When:** Always — chokidar opens OS file handles; leaking them causes "too many open files."

```typescript
// lib/watcher.ts
import 'server-only'
import chokidar from 'chokidar'
import { EventBus } from './event-bus'
import os from 'os'
import path from 'path'

let watcher: chokidar.FSWatcher | null = null

export function initWatcher(): void {
  if (watcher) return // singleton guard

  const watchPaths = [
    path.join(os.homedir(), 'project_orchestration', 'code'),
    path.join(os.homedir(), 'project_orchestration', 'project research'),
  ]

  watcher = chokidar.watch(watchPaths, {
    ignored: /(node_modules|\.git|\.next)/,
    persistent: true,
    depth: 4,           // enough to reach .planning/STATE.md
    ignoreInitial: true,
  })

  watcher.on('change', (filePath) => {
    const projectId = resolveProjectId(filePath)
    if (projectId) EventBus.emit('project:updated', { projectId, filePath })
  })

  watcher.on('addDir', (dirPath) => {
    // new project directory at depth 1
    if (isProjectRoot(dirPath)) {
      EventBus.emit('project:added', { dirPath })
    }
  })
}
```

### Pattern 2: SSE via ReadableStream with Cleanup

**What:** Route Handler returns a ReadableStream, subscribes to EventBus on start, unsubscribes on client disconnect.
**When:** The SSE endpoint — /api/sse/route.ts.

```typescript
// app/api/sse/route.ts
import { EventBus } from '@/lib/event-bus'
export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

export async function GET() {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    start(controller) {
      const handler = (event: ProjectEvent) => {
        const data = `data: ${JSON.stringify(event)}\n\n`
        controller.enqueue(encoder.encode(data))
      }

      EventBus.on('project:updated', handler)
      EventBus.on('project:added', handler)
      EventBus.on('project:removed', handler)

      // keepalive ping every 30s
      const ping = setInterval(() => {
        controller.enqueue(encoder.encode('data: {"type":"ping"}\n\n'))
      }, 30_000)

      // cleanup on client disconnect
      return () => {
        EventBus.off('project:updated', handler)
        EventBus.off('project:added', handler)
        EventBus.off('project:removed', handler)
        clearInterval(ping)
      }
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
}
```

### Pattern 3: instrumentation.ts for Watcher Bootstrap

**What:** `register()` is called exactly once by Next.js on server start — ideal for singleton initialization.
**When:** Always use this over app/layout.tsx or manual imports.

```typescript
// instrumentation.ts (root of project)
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { initWatcher } = await import('./lib/watcher')
    initWatcher()
  }
  // do NOT init in 'edge' runtime — chokidar is Node.js only
}
```

The `NEXT_RUNTIME === 'nodejs'` guard is mandatory. Next.js calls `register()` in both Node.js and Edge contexts. Chokidar requires Node.js.

### Pattern 4: Git Reader with Promise.allSettled + Timeout

**What:** Parallel git calls with a fixed timeout, non-fatal failures.
**When:** Every code project card on initial load and on `project:updated` events.

```typescript
// lib/git-reader.ts
import 'server-only'
import simpleGit from 'simple-git'

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('timeout')), ms)
    ),
  ])
}

export async function readGitInfo(projectPath: string) {
  const git = simpleGit(projectPath)

  const [logResult, statusResult, branchResult] = await Promise.allSettled([
    withTimeout(git.log({ maxCount: 1 }), 5000),
    withTimeout(git.status(), 5000),
    withTimeout(git.branch(), 5000),
  ])

  return {
    lastCommit: logResult.status === 'fulfilled'
      ? logResult.value.latest
      : null,
    isDirty: statusResult.status === 'fulfilled'
      ? !statusResult.value.isClean()
      : null,
    branch: branchResult.status === 'fulfilled'
      ? branchResult.value.current
      : null,
  }
}
```

### Pattern 5: Project Type Classification

**What:** Scanner determines whether a directory is a code project, research project, or irrelevant.
**When:** During initial scan and when `project:added` fires.

```typescript
// lib/scanner.ts
type ProjectType = 'code' | 'research' | 'unknown'

function classifyProject(dirPath: string): ProjectType {
  // Code projects: have .git or .planning/
  // Research projects: path is under "project research/", no .git expected
  // Both show different card layouts
}
```

Research projects use a different card layout — no git metrics, no phase progress (unless they have .planning/).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Per-Request Watcher Creation

**What:** Creating a chokidar watcher inside a route handler or on every SSE connection.
**Why bad:** Each watcher opens OS file handles. Under Next.js dev mode, hot module replacement causes handlers to re-run. This exhausts the OS inotify/kqueue limit and makes the process crash.
**Instead:** Single singleton via instrumentation.ts, initialized once.

### Anti-Pattern 2: Sending Full Project Data Over SSE

**What:** Serializing entire ProjectData objects into SSE events.
**Why bad:** Adds serialization/deserialization surface, SSE events become large, git data cannot be re-fetched over SSE (it's async), and it bypasses the existing API layer.
**Instead:** SSE signals change-type + projectId. Browser re-fetches `/api/projects/[id]` for fresh data.

### Anti-Pattern 3: Direct Filesystem Reads in React Components

**What:** Using `fs` in Server Components directly, bypassing the lib layer.
**Why bad:** Duplicates parsing logic, harder to test, no consistent error handling, no timeout enforcement.
**Instead:** All filesystem access goes through Scanner, Parser, GitReader. Server Components call `/api/*` route handlers or the lib functions — never raw `fs` directly in page.tsx.

### Anti-Pattern 4: Global EventEmitter Without Max Listeners

**What:** Using a plain EventEmitter without increasing the maxListeners limit.
**Why bad:** Node.js warns at 11 listeners by default. Each open SSE tab adds a listener set. On a developer's machine, you might have 3-5 tabs open during development — each adds 3 listeners (updated/added/removed). Hit 11 fast.
**Instead:** `EventBus.setMaxListeners(50)` on initialization, or use a dedicated pub/sub with proper cleanup.

### Anti-Pattern 5: Hardcoded Scan Paths

**What:** `'/Users/rob/project_orchestration/code'` as a string literal anywhere.
**Why bad:** Path breaks immediately if run on another machine or if the user renames their home directory.
**Instead:** Always `path.join(os.homedir(), 'project_orchestration', 'code')`.

### Anti-Pattern 6: Blocking Markdown Parsing on git

**What:** Awaiting git data before returning parsed markdown data.
**Why bad:** Git on large repos with many commits can be slow. Blocks the UI from showing project metadata.
**Instead:** Return parser data immediately, stream git data separately or show a loading state per-card.

---

## Directory Structure

```
pro-orc/                             # Next.js project root
├── instrumentation.ts               # Singleton watcher bootstrap
├── app/
│   ├── layout.tsx                   # Root layout, ThemeProvider
│   ├── page.tsx                     # Server Component: initial dashboard render
│   ├── tools/
│   │   └── page.tsx                 # Claude tools inventory page
│   └── api/
│       ├── sse/
│       │   └── route.ts             # SSE endpoint (force-dynamic, nodejs runtime)
│       ├── projects/
│       │   ├── route.ts             # GET all projects snapshot
│       │   └── [id]/
│       │       └── route.ts         # GET single project (post-SSE refresh)
│       └── tools/
│           └── route.ts             # GET Claude tools inventory
├── components/
│   ├── project-card.tsx             # 'use client' — single project card
│   ├── project-grid.tsx             # 'use client' — grid layout with SSE state
│   ├── sse-listener.tsx             # 'use client' — EventSource lifecycle
│   ├── tools-panel.tsx              # Claude tools list (Server Component safe)
│   └── ui/                          # shadcn/ui generated components
├── lib/
│   ├── watcher.ts                   # chokidar singleton (server-only)
│   ├── event-bus.ts                 # EventEmitter singleton (server-only)
│   ├── scanner.ts                   # Directory scanning + project classification
│   ├── parser.ts                    # .planning/ markdown parsing
│   ├── git-reader.ts                # simple-git with timeout (server-only)
│   ├── tools-reader.ts              # ~/.claude/ inventory (server-only)
│   └── types.ts                     # Shared TypeScript types
├── hooks/
│   └── use-sse.ts                   # 'use client' — EventSource hook
└── next.config.ts
```

---

## Build Order (Phase Dependencies)

This is the dependency graph that should drive roadmap phase sequencing:

```
Phase 1: Foundation
  ├─ next.config.ts + TypeScript setup
  ├─ Tailwind v4 + shadcn/ui dark mode theme
  └─ lib/types.ts (shared types, no deps)

Phase 2: Scanner + Parser (no UI, testable in isolation)
  ├─ lib/scanner.ts — reads code/ and project research/
  ├─ lib/parser.ts — parses .planning/ files
  └─ lib/git-reader.ts — simple-git with timeout
  (These have no Next.js dependency — pure Node.js modules)

Phase 3: API Layer
  ├─ app/api/projects/route.ts — uses Phase 2 modules
  └─ Verify data shape is correct via curl before building UI

Phase 4: Static Dashboard UI
  ├─ app/page.tsx — Server Component fetching from Phase 3 API
  ├─ components/project-card.tsx — renders ProjectData
  └─ components/project-grid.tsx — layout
  (Works without live updates — this is the MVP)

Phase 5: Watcher + SSE (adds live updates)
  ├─ lib/event-bus.ts — EventEmitter singleton
  ├─ lib/watcher.ts — chokidar + EventBus integration
  ├─ instrumentation.ts — bootstrap watcher on server start
  ├─ app/api/sse/route.ts — SSE endpoint
  ├─ hooks/use-sse.ts — browser EventSource hook
  └─ components/sse-listener.tsx — integrates hook with grid

Phase 6: Claude Tools Inventory
  ├─ lib/tools-reader.ts — reads ~/.claude/
  ├─ app/api/tools/route.ts
  └─ app/tools/page.tsx + components/tools-panel.tsx

Phase 7: Quick Actions
  └─ app/api/open/route.ts — shell exec via child_process
     (open -a Terminal, open -R in Finder, open notion:// URL)
```

**Why this order:**
- Scanner/Parser before API ensures data shape is right before building UI
- Static UI before SSE proves the dashboard value without the complexity of real-time
- SSE after static UI means each SSE event has a known refresh target (the API from Phase 3)
- Tools inventory is self-contained, no dependency on watcher
- Quick Actions last — they're convenience features, not core value

---

## Scalability Considerations

This is a local single-user tool targeting <50 projects. Scalability is not a concern. The design choices are intentionally simple:

| Concern | Current Approach | If It Becomes a Problem |
|---------|-----------------|------------------------|
| Many projects | Scan all on start | Client-side filter (already in scope for v1) |
| Git slowness | 5s timeout, non-fatal | Per-card lazy loading |
| Many SSE tabs | EventBus with 50 max listeners | Not a real concern — single user |
| HMR in dev | Singleton guard | Already handled by guard |
| Large .planning/ files | readFile is synchronous-feeling but async | Not an issue at these sizes |

---

## Key Constraints (Verified)

| Constraint | Source | Impact |
|------------|--------|--------|
| `register()` called once per server instance | Next.js official docs v16.1.6 | Singleton initialization is safe here |
| `NEXT_RUNTIME` must be checked | Next.js official docs v16.1.6 | chokidar import MUST be guarded to Node.js only |
| SSE route needs `force-dynamic` | Next.js 15 default: GET handlers are dynamic, but explicit is safer | Prevents static optimization of SSE endpoint |
| SSE route needs `runtime = 'nodejs'` | chokidar + EventEmitter are Node.js-only | Without this, Edge runtime breaks the import chain |
| ReadableStream cleanup runs on disconnect | Web Streams API / Next.js route handlers | EventBus listener removal must happen in the cancel/return callback |
| `server-only` package | Best practice for lib/watcher.ts, lib/git-reader.ts | Prevents accidental client bundle inclusion of Node.js code |
| params is now a Promise | Next.js 15.0.0-RC breaking change | `const { id } = await params` in all dynamic route handlers |

---

## Sources

- Next.js 15 instrumentation docs: https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation (verified 2026-02-17, doc version 16.1.6)
- Next.js Route Handlers docs: https://nextjs.org/docs/app/building-your-application/routing/route-handlers (verified 2026-02-17, doc version 16.1.6)
- Next.js Server/Client Components: https://nextjs.org/docs/app/building-your-application/rendering/server-components (verified 2026-02-17, doc version 16.1.6)
- Project requirements: /Users/rob/project_orchestration/.planning/PROJECT.md (read 2026-02-17)
- Confidence: HIGH for Next.js architecture patterns (official docs), HIGH for chokidar singleton pattern (established Node.js singleton pattern), HIGH for SSE via ReadableStream (Web Streams API standard)
