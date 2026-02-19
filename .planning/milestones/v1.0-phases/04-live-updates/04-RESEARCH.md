# Phase 4: Live Updates - Research

**Researched:** 2026-02-17
**Domain:** chokidar v3 filesystem watcher + Next.js App Router SSE (Server-Sent Events) via ReadableStream + globalThis singleton pattern
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIVE-01 | chokidar filesystem watcher monitors `.planning/` changes across all projects | `chokidar.watch([PATHS.code, PATHS.research], { ignored: [...] })` with recursive watching; `change`/`add`/`unlink` events map file path back to project via `projectIdFromPath()` |
| LIVE-02 | Watcher runs as singleton (via `instrumentation.ts` on `globalThis`, not per-request) | `instrumentation.ts` `register()` function runs once at server startup; guard with `process.env.NEXT_RUNTIME === 'nodejs'`; store on `globalThis.__watcher` so HMR re-runs don't create duplicate watchers |
| LIVE-03 | Watcher excludes `node_modules/`, `.git/`, `.next/` | chokidar `ignored` option accepts a string array: `['**/node_modules/**', '**/.git/**', '**/.next/**']` — verified working in v3.6.0 |
| LIVE-04 | SSE push delivers change events via ReadableStream route handler | `GET /api/events` route handler returns `new Response(readableStream, { headers: { 'Content-Type': 'text/event-stream', ... } })`; clients subscribe via global subscriber set; chokidar emits → subscriber set notified |
| LIVE-05 | Affected project card updates without full page reload | Client hook `useLiveProject(projectId)` subscribes to `EventSource('/api/events')`; on `project:updated` event matching `projectId`, re-fetches `/api/projects/[id]`; updates local state; card re-renders with new data |
| LIVE-06 | Watcher events are debounced (300ms) | `setTimeout`/`clearTimeout` debounce in the chokidar event handler before calling subscribers; per-project debounce keyed by projectId so simultaneous saves to different projects are independent |
</phase_requirements>

---

## Summary

Phase 4 wires three pieces together: a chokidar v3 filesystem watcher that watches `.planning/` directories, a subscriber registry that SSE clients register into, and a `ReadableStream`-based SSE route handler that pushes signal-only events to the browser. The browser then re-fetches a `/api/projects/[id]` route to get fresh data for the changed project and updates the card in place without a page reload.

The core architectural challenge is resource management across two boundaries: (1) the Next.js development server's HMR cycle, which re-executes module code and would create duplicate watchers if not guarded; and (2) browser tab lifecycle, where opening and closing tabs must produce exactly one SSE connection per tab with clean teardown on close. Both are solved with known patterns: `globalThis` for the watcher singleton, and `request.signal` abort listener for SSE cleanup.

The signal-only pattern is the right choice here. Watcher events carry only `{ type, projectId }`. The browser re-fetches `/api/projects/[id]` for full project data. This keeps the SSE channel thin and avoids the complexity of serializing full `Project` objects through the event stream. It also means the `/api/projects/[id]` route is useful at startup (for hydrating state without a page reload) and on events — one well-defined data source of truth.

**Primary recommendation:** `instrumentation.ts` → `globalThis.__watcher` for chokidar singleton; `globalThis.__sseSubscribers` for the subscriber Set; `GET /api/events` route handler for SSE; `GET /api/projects/[id]` route handler for per-project data; `useProjectEvents` hook in client components to subscribe and re-fetch.

---

## Standard Stack

### Core (all already installed — no new dependencies needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| chokidar | 3.6.0 (installed) | Filesystem watcher for `.planning/` dirs | Already in `package.json`; `serverExternalPackages` already configured in `next.config.ts`; v3 chosen over v4 (ESM-only friction) |
| Next.js App Router | 16.1.6 (installed) | Route handlers for `/api/events` and `/api/projects/[id]`; `instrumentation.ts` for singleton init | Already configured; Turbopack-compatible |
| React | 19.2.3 (installed) | `useSyncExternalStore` or `useState`/`useEffect` for live state in client components | Already installed |
| Web Platform APIs | Node.js 24 / Browser | `ReadableStream`, `TextEncoder`, `EventSource`, `AbortSignal` | Built-in; no install needed |

### No New Dependencies

```bash
# Nothing to install — chokidar is already in package.json at ^3.6.0
# serverExternalPackages already includes 'chokidar' and 'fsevents' in next.config.ts
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| chokidar v3 | chokidar v4 | v4 is ESM-only, causes bundling friction with Next.js; v3 is CommonJS-compatible and works with `serverExternalPackages` as already configured |
| SSE (EventSource) | WebSocket | WebSockets require a custom server (breaks Next.js API routes model); SSE is unidirectional server→client which is all we need |
| Signal-only SSE events | Full-payload SSE events | Full payload means serializing `Project` objects through SSE; re-fetch pattern is simpler, keeps SSE thin, and reuses the `/api/projects/[id]` route |
| `globalThis` singleton | Module-level singleton | Module-level singletons are re-instantiated on every HMR cycle; `globalThis` persists across re-runs within the same process |

---

## Architecture Patterns

### Recommended File Structure

```
pro-orc/
├── instrumentation.ts              MODIFY: add chokidar singleton init (stub already exists)
├── app/
│   ├── api/
│   │   ├── events/
│   │   │   └── route.ts            NEW: SSE route handler — GET /api/events
│   │   └── projects/
│   │       └── [id]/
│   │           └── route.ts        NEW: per-project data route — GET /api/projects/[id]
│   ├── page.tsx                    UNCHANGED: async Server Component, initial render
│   └── actions.ts                  UNCHANGED: Terminal/Finder server actions
├── components/
│   ├── projectTabs.tsx             MODIFY: accept live data override props or use hook
│   ├── codeProjectCard.tsx         MODIFY: consume live project state via hook
│   ├── researchProjectCard.tsx     MODIFY: consume live project state via hook
│   └── ...
├── hooks/
│   ├── usePrivateProjects.ts       UNCHANGED
│   └── useProjectEvents.ts         NEW: SSE client hook, manages EventSource + re-fetch
└── lib/
    ├── watcher.ts                  NEW: chokidar setup, subscriber registry, debounce logic
    ├── types.ts                    UNCHANGED (SseEvent, SseEventType already defined)
    ├── scanner.ts                  UNCHANGED (scanProjects reused by /api/projects/[id])
    └── paths.ts                    UNCHANGED (PATHS.code, PATHS.research used by watcher)
```

### Pattern 1: Chokidar Singleton via `instrumentation.ts` + `globalThis` (LIVE-01, LIVE-02)

**What:** `instrumentation.ts` exports a `register()` function that Next.js calls once at server startup. The watcher is stored on `globalThis` so HMR re-runs of `register()` find the existing watcher and skip re-initialization.

**Why `globalThis`:** During development, Next.js Turbopack re-executes module code on every hot reload. A module-level `let watcher = null` would be reset on each HMR cycle, creating a new chokidar instance and leaking file descriptors. `globalThis` is the true Node.js process global — it survives module re-execution.

**Why `process.env.NEXT_RUNTIME === 'nodejs'`:** `instrumentation.ts` `register()` is called in both Node.js and Edge runtimes. chokidar requires Node.js APIs (`fs`, `fsevents`). The runtime guard prevents chokidar from loading in the Edge runtime.

```typescript
// instrumentation.ts
// Source: Next.js official docs (https://nextjs.org/docs/app/guides/instrumentation)
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Dynamic import keeps chokidar out of the Edge bundle
    await import('./lib/watcher')
  }
}
```

```typescript
// lib/watcher.ts
// Source: chokidar v3 README + globalThis singleton pattern from Next.js community
import chokidar, { FSWatcher } from 'chokidar'
import { PATHS, projectIdFromPath } from '@/lib/paths'
import type { SseEvent } from '@/lib/types'
import path from 'path'

// Subscriber registry — one entry per SSE connection
type Subscriber = (event: SseEvent) => void

// Extend globalThis with typed watcher fields
declare global {
  var __watcher: FSWatcher | undefined
  var __watcherSubscribers: Set<Subscriber> | undefined
  var __watcherDebounceTimers: Map<string, ReturnType<typeof setTimeout>> | undefined
}

// Initialize subscriber registry once
if (!globalThis.__watcherSubscribers) {
  globalThis.__watcherSubscribers = new Set<Subscriber>()
}
if (!globalThis.__watcherDebounceTimers) {
  globalThis.__watcherDebounceTimers = new Map()
}

// Initialize chokidar watcher once — guard prevents HMR re-creation
if (!globalThis.__watcher) {
  globalThis.__watcher = chokidar.watch(
    [PATHS.code, PATHS.research],
    {
      ignored: ['**/node_modules/**', '**/.git/**', '**/.next/**'],
      persistent: true,
      ignoreInitial: true,  // Don't emit events for existing files at startup
      depth: 5,             // Limit recursion depth for performance
    }
  )

  globalThis.__watcher.on('all', (event, filePath) => {
    // Only care about .planning/ directory changes
    if (!filePath.includes('.planning')) return

    // Map file path back to project ID
    // filePath: /Users/rob/project_orchestration/code/my-project/.planning/STATE.md
    // Extract the project directory from the path
    const planningIdx = filePath.indexOf('/.planning/')
    if (planningIdx === -1) return
    const projectPath = filePath.slice(0, planningIdx)
    const projectId = projectIdFromPath(projectPath)

    // Debounce per project (300ms) — LIVE-06
    const timers = globalThis.__watcherDebounceTimers!
    if (timers.has(projectId)) {
      clearTimeout(timers.get(projectId)!)
    }
    timers.set(projectId, setTimeout(() => {
      timers.delete(projectId)
      const sseEvent: SseEvent = {
        type: 'project:updated',
        projectId,
        changedFile: path.relative(projectPath, filePath),
      }
      // Notify all SSE subscribers
      globalThis.__watcherSubscribers!.forEach(sub => sub(sseEvent))
    }, 300))
  })
}

// Exported helpers for the SSE route handler
export const watcherSubscribers = globalThis.__watcherSubscribers
```

### Pattern 2: SSE Route Handler via ReadableStream (LIVE-04)

**What:** `GET /api/events` returns a long-lived `ReadableStream` response with SSE headers. When a new connection arrives, the handler registers a subscriber in `watcherSubscribers`. When the browser closes the tab, `request.signal` fires an `abort` event, which triggers cleanup.

**Critical details:**
- `export const dynamic = 'force-dynamic'` prevents Next.js from caching/statically optimizing the route
- `X-Accel-Buffering: no` prevents nginx proxy buffering (relevant in prod; harmless in dev)
- The `abort` event on `request.signal` is the ONLY reliable way to detect browser disconnect in Next.js App Router route handlers
- Each browser connection gets its own `ReadableStream` instance; the shared singleton is the `watcherSubscribers` Set

```typescript
// app/api/events/route.ts
// Source: Next.js App Router route handler pattern + SSE pattern from pedroalonso.net
import { type NextRequest } from 'next/server'
import { watcherSubscribers } from '@/lib/watcher'
import type { SseEvent } from '@/lib/types'

export const dynamic = 'force-dynamic'

export function GET(request: NextRequest) {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    start(controller) {
      // Send initial ping to confirm connection
      controller.enqueue(
        encoder.encode(`data: ${JSON.stringify({ type: 'ping' } satisfies SseEvent)}\n\n`)
      )

      // Register subscriber — this function is called when chokidar fires
      const subscriber = (event: SseEvent) => {
        try {
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify(event)}\n\n`)
          )
        } catch {
          // Stream closed (client disconnected) — subscriber will be cleaned up below
        }
      }

      watcherSubscribers.add(subscriber)

      // Cleanup on browser disconnect — CRITICAL for no zombie streams
      request.signal.addEventListener('abort', () => {
        watcherSubscribers.delete(subscriber)
        controller.close()
      })
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  })
}
```

### Pattern 3: Per-Project Data Route (LIVE-05)

**What:** `GET /api/projects/[id]` re-scans a single project and returns its `Project` data as JSON. The browser calls this after receiving an SSE event for `projectId`.

**Why not re-scan all projects:** Full `scanProjects()` runs git log for every code project, taking up to 5 seconds. Re-fetching one project is near-instant.

**Challenge:** The existing `scanProjects()` scans entire directories. A `scanProject(projectPath)` function needs to be extracted or written to handle a single project. The scanner.ts `scanDir()` is already structured to handle individual directories — it can be adapted.

```typescript
// app/api/projects/[id]/route.ts
import { type NextRequest } from 'next/server'
import { scanProjectById } from '@/lib/scanner'  // new export needed

export const dynamic = 'force-dynamic'

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const project = await scanProjectById(id)
  if (!project) {
    return Response.json({ error: 'not found' }, { status: 404 })
  }
  return Response.json(project)
}
```

### Pattern 4: Client Hook for Live Updates (LIVE-05)

**What:** `useProjectEvents(project, onUpdate)` — a client-side hook that subscribes to `/api/events` via `EventSource`, listens for events matching the project's ID, re-fetches `/api/projects/[id]`, and calls `onUpdate` with the fresh `Project`. The hook manages cleanup on unmount.

**Key behavior:** One `EventSource` per dashboard page (not per card). The hook is called at the `ProjectTabs` level with a shared subscription, which dispatches updates to individual cards. This avoids opening N EventSources for N cards.

```typescript
// hooks/useProjectEvents.ts
// Source: MDN EventSource API + React useEffect cleanup pattern
'use client'

import { useEffect, useCallback } from 'react'
import type { Project, SseEvent } from '@/lib/types'

export function useProjectEvents(
  onUpdate: (projectId: string, data: Project) => void
) {
  useEffect(() => {
    const source = new EventSource('/api/events')

    source.onmessage = async (event: MessageEvent) => {
      const sseEvent = JSON.parse(event.data) as SseEvent
      if (sseEvent.type !== 'project:updated' || !sseEvent.projectId) return

      // Re-fetch the updated project
      try {
        const res = await fetch(`/api/projects/${sseEvent.projectId}`)
        if (!res.ok) return
        const project: Project = await res.json()
        onUpdate(sseEvent.projectId, project)
      } catch {
        // Network error — ignore, next event will retry
      }
    }

    source.onerror = () => {
      // EventSource reconnects automatically on error (browser built-in behavior)
      // No manual retry needed
    }

    return () => {
      source.close()  // Cleanup on unmount — prevents zombie connections
    }
  }, [onUpdate])
}
```

### Pattern 5: Live State Management in ProjectTabs (LIVE-05)

**What:** `ProjectTabs` is already a client component. Add a `useState` for a live overlay map (`Map<projectId, Project>`) that overrides server-rendered data when an SSE update arrives. Merge with initial props on render.

```typescript
// components/projectTabs.tsx — additions
'use client'

import { useState, useCallback } from 'react'
import { useProjectEvents } from '@/hooks/useProjectEvents'
import type { Project } from '@/lib/types'

export function ProjectTabs({ codeProjects, researchProjects }) {
  // Live overlay: projectId → updated Project data
  const [liveData, setLiveData] = useState<Map<string, Project>>(new Map())

  const handleUpdate = useCallback((projectId: string, project: Project) => {
    setLiveData(prev => new Map(prev).set(projectId, project))
  }, [])

  useProjectEvents(handleUpdate)

  // Merge server props with live overrides
  const resolvedCode = codeProjects.map(p => (liveData.get(p.id) as CodeProject) ?? p)
  const resolvedResearch = researchProjects.map(p => (liveData.get(p.id) as ResearchProject) ?? p)

  // ... rest of render unchanged, use resolvedCode/resolvedResearch
}
```

### Anti-Patterns to Avoid

- **Module-level chokidar singleton in `lib/watcher.ts` without `globalThis`:** A `let watcher: FSWatcher | null = null` at module level resets to `null` on every HMR re-run. Always use `globalThis.__watcher ?? (globalThis.__watcher = chokidar.watch(...))`.
- **Starting EventSource per card component:** Creates N connections for N cards. Put the single `EventSource` in `ProjectTabs` (or a root-level hook) and dispatch to cards.
- **Not closing EventSource on component unmount:** `source.close()` in the `useEffect` cleanup is mandatory. Without it, tabs accumulate dead connections.
- **Watching entire `PATHS.code` and `PATHS.research` without `depth` limit:** Without `depth`, chokidar recurses into all subdirectories including `node_modules/` subdirs that may not be excluded by `ignored` patterns. Set `depth: 5` as a safety bound (`.planning/` is at depth 1 from project root).
- **Not guarding chokidar with `NEXT_RUNTIME === 'nodejs'`:** chokidar imports `fs`, `fsevents` — these are not available in the Edge runtime. Without the guard, Edge runtime routes will fail to load.
- **Using `setInterval` for heartbeat/ping instead of relying on reconnect:** `EventSource` reconnects automatically after ~3 seconds on connection loss. Adding a ping heartbeat is optional for long-idle connections (e.g., > 45 seconds to prevent proxy timeouts) but not required for localhost.
- **Serializing full `Project` objects through SSE:** The `SseEvent` type is `{ type, projectId?, changedFile? }` — signal only. Browser re-fetches. Don't put `Project` data in the SSE event payload.
- **Missing `export const dynamic = 'force-dynamic'`:** Next.js may statically optimize route handlers that it thinks are static. The SSE route must be `force-dynamic` to prevent this.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Filesystem watching | Custom `fs.watch()` polling loop | chokidar v3 (already installed) | `fs.watch()` has platform quirks, no debounce, no glob ignore, unreliable on macOS for directory watching |
| SSE reconnection logic | Manual `setTimeout(() => new EventSource(...))` | Browser `EventSource` built-in reconnect | `EventSource` reconnects automatically with exponential backoff; custom logic is error-prone |
| Debounce utility | Custom `debounce()` function | Inline `setTimeout`/`clearTimeout` with `Map<projectId, timer>` | Problem is simple enough that a library is overkill; per-project debouncing requires keyed timers anyway |
| Subscriber pattern | Custom event emitter class | Plain `Set<Subscriber>` in `globalThis` | An EventEmitter class adds abstraction without benefit; a Set of callbacks is 5 lines and trivially testable |

**Key insight:** The entire feature is connective tissue between three built-in/installed mechanisms: chokidar (already installed), the Web `EventSource` API (browser built-in), and Next.js ReadableStream route handlers (platform API). The code is plumbing, not invention.

---

## Common Pitfalls

### Pitfall 1: File Descriptor Accumulation on HMR (LIVE-02 Core Risk)

**What goes wrong:** In development mode, Turbopack hot-reloads changed files. Each HMR cycle re-executes `instrumentation.ts` and any module it imports. Without `globalThis` guard, each HMR creates a new `chokidar.watch()` instance. The old instance is garbage-collected eventually but may hold file descriptors open in the interim. After many reloads, the process hits the OS file descriptor limit.

**Why it happens:** JavaScript modules don't have destructors. `chokidar.watch()` opens native OS file watch handles (kqueue on macOS, inotify on Linux). These are not closed by GC alone — `watcher.close()` must be called explicitly, or the watcher must not be re-created.

**How to avoid:** The `globalThis.__watcher` guard in `lib/watcher.ts` is the fix. The `if (!globalThis.__watcher)` check ensures `chokidar.watch()` is called at most once per process lifetime, regardless of how many times HMR re-executes the module.

**Warning signs:** Dev server becomes slow over time; `lsof -p <node-pid> | wc -l` count keeps growing.

### Pitfall 2: Zombie SSE Connections on Tab Navigation

**What goes wrong:** Every time the user navigates to the dashboard, a new `EventSource('/api/events')` is created on the client. If the previous `EventSource` is not closed on unmount, the server accumulates subscriber callbacks in `watcherSubscribers`. Each extra subscriber adds a function call on every file change event. More critically, each zombie subscriber tries to enqueue into a closed `ReadableStream` controller (browser gone), potentially causing errors.

**Why it happens:** `useEffect` cleanup (the returned function) is only called when the component unmounts. If the developer omits the `return () => source.close()`, the `EventSource` keeps the connection open indefinitely.

**How to avoid:** Always return `() => source.close()` from the `useEffect` in `useProjectEvents`. The route handler also defensively catches errors when `controller.enqueue()` fails for a closed stream.

**Warning signs:** Browser DevTools Network tab shows multiple concurrent `/api/events` connections for the same page.

### Pitfall 3: `ignored` Pattern Not Excluding Deeply Nested node_modules

**What goes wrong:** `chokidar.watch([PATHS.code, PATHS.research], { ignored: ['**/node_modules/**'] })` works for top-level project directories. But if a project has deeply nested `.planning/` files, chokidar may still traverse some intermediate directories before hitting the `ignored` pattern.

**Why it happens:** The `ignored` pattern in chokidar v3 is applied per path segment. Glob patterns like `**/node_modules/**` correctly match any `node_modules` at any depth. However, paths that are checked before chokidar traverses into them — chokidar still emits readdir syscalls for parent directories before deciding to ignore children.

**How to avoid:** Use `['**/node_modules/**', '**/.git/**', '**/.next/**']` as the `ignored` array. These glob patterns are the standard way to exclude these directories in chokidar v3. Verified working with v3.6.0 in this project.

**Warning signs:** High CPU usage in dev; many `change` events for files outside `.planning/`.

### Pitfall 4: `params` Must Be Awaited in Next.js 16 Route Handlers

**What goes wrong:** In Next.js 16, dynamic route params (`{ params }`) are a Promise, not a plain object. Writing `const { id } = params` (without `await`) causes a TypeScript error and runtime failure.

**Why it happens:** Next.js 15+ changed params to be async (Promises) as part of the App Router async APIs migration.

**How to avoid:** Always `await` params: `const { id } = await params`. The route handler signature should type it as `{ params: Promise<{ id: string }> }`.

**Warning signs:** TypeScript error "Property 'id' does not exist on type 'Promise<...>'".

### Pitfall 5: `scanProject(id)` Needs to Map ID Back to Path

**What goes wrong:** The SSE event carries `projectId` (e.g., `"my-project"`). The `/api/projects/[id]` route handler needs to find the filesystem path for that ID to re-scan it. But `projectIdFromPath()` is one-way — it slugifies a path. There's no reverse lookup built into the existing code.

**Why it happens:** The existing scanner scans both `PATHS.code` and `PATHS.research` directories. To find one project by ID, the route must either (a) scan all directories and filter, or (b) try both roots directly.

**How to avoid:** In `scanProjectById(id)`, try `path.join(PATHS.code, id)` and `path.join(PATHS.research, id)` with a directory existence check. If neither exists, try scanning both dirs and filtering by ID as a fallback. This handles projects whose directory name contains characters that get stripped by `projectIdFromPath()`.

**Warning signs:** `/api/projects/[id]` returns 404 for projects whose names contain spaces or special characters.

### Pitfall 6: SSE Route Must Be `force-dynamic`

**What goes wrong:** Omitting `export const dynamic = 'force-dynamic'` from the SSE route allows Next.js to cache or statically analyze the route. In practice this means the route might be pre-rendered or optimized in a way that prevents streaming.

**Why it happens:** Next.js tries to be smart about caching by default. SSE routes are long-lived and must never be cached.

**How to avoid:** Add `export const dynamic = 'force-dynamic'` at the top of `app/api/events/route.ts` and `app/api/projects/[id]/route.ts`.

**Warning signs:** SSE connection opens then immediately closes; no events received by browser.

---

## Code Examples

Verified patterns from official sources and installed packages:

### Chokidar v3 Watch with Ignored Patterns

```typescript
// Source: chokidar v3 README (github.com/paulmillr/chokidar) + verified against v3.6.0
import chokidar from 'chokidar'

const watcher = chokidar.watch(['/path/to/code', '/path/to/research'], {
  ignored: ['**/node_modules/**', '**/.git/**', '**/.next/**'],
  persistent: true,
  ignoreInitial: true,  // Don't fire 'add' events for existing files
  depth: 5,
})

watcher.on('all', (event, filePath) => {
  console.log(event, filePath)
  // event: 'add' | 'change' | 'unlink' | 'addDir' | 'unlinkDir'
})

// Cleanup (call on server shutdown)
await watcher.close()
```

### GlobalThis Singleton Guard

```typescript
// Source: Next.js community pattern (github.com/vercel/next.js/discussions/31496)
// Ensures only one instance across HMR re-executions in dev mode
declare global {
  var __watcher: import('chokidar').FSWatcher | undefined
}

if (!globalThis.__watcher) {
  globalThis.__watcher = chokidar.watch(...)
}
```

### SSE Route Handler with ReadableStream and AbortSignal Cleanup

```typescript
// Source: Next.js official docs (route.mdx) + pedroalonso.net SSE pattern
// Verified: ReadableStream is available in Next.js App Router route handlers
export const dynamic = 'force-dynamic'

export function GET(request: NextRequest) {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    start(controller) {
      const subscriber = (event: SseEvent) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`))
      }

      subscribers.add(subscriber)

      // CRITICAL: Clean up on browser disconnect
      request.signal.addEventListener('abort', () => {
        subscribers.delete(subscriber)
        controller.close()
      })
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  })
}
```

### instrumentation.ts with Runtime Guard

```typescript
// Source: Next.js official docs (nextjs.org/docs/app/guides/instrumentation)
// The register() function is called once at server startup
// NEXT_RUNTIME === 'nodejs' ensures chokidar (Node-only) is not loaded in Edge
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./lib/watcher')
    // Side effect: lib/watcher.ts initializes globalThis.__watcher on first import
  }
}
```

### Client EventSource Hook with Cleanup

```typescript
// Source: MDN EventSource API + React useEffect cleanup pattern
// Source: Next.js App Router client component pattern
'use client'
import { useEffect } from 'react'

export function useProjectEvents(onUpdate: (id: string, data: Project) => void) {
  useEffect(() => {
    const source = new EventSource('/api/events')

    source.onmessage = async (e) => {
      const event = JSON.parse(e.data) as SseEvent
      if (event.type !== 'project:updated' || !event.projectId) return
      const res = await fetch(`/api/projects/${event.projectId}`)
      if (res.ok) onUpdate(event.projectId, await res.json())
    }

    return () => source.close()  // CRITICAL: prevent zombie connections
  }, [onUpdate])  // onUpdate must be stable (useCallback in parent)
}
```

### Per-Project Debounce with Map

```typescript
// Source: Standard JavaScript debounce pattern adapted for per-key debouncing
// LIVE-06: 300ms debounce per projectId
const timers = new Map<string, ReturnType<typeof setTimeout>>()

function debouncedEmit(projectId: string, event: SseEvent) {
  if (timers.has(projectId)) clearTimeout(timers.get(projectId)!)
  timers.set(projectId, setTimeout(() => {
    timers.delete(projectId)
    subscribers.forEach(sub => sub(event))
  }, 300))
}
```

### Dynamic Route Params in Next.js 16 (Must Await)

```typescript
// Source: Next.js 16 App Router route handler API
// In Next.js 15+, route segment params are Promises
export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params  // REQUIRED: await the params Promise
  // ...
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `fs.watch()` for file monitoring | chokidar (wraps FSEvents/inotify) | ~2012 | Cross-platform reliability, debounce, recursive watching built-in |
| Pages Router API route (`res.write()` SSE) | App Router `ReadableStream` route handler | Next.js 13+ | Web-standard API, no Node.js-specific `res` object, works in Edge runtime |
| `globalThis` workaround for singletons | Still `globalThis` — no better option in Next.js | Ongoing | Next.js has not provided a first-party "process singleton" mechanism; `globalThis` remains the recommended pattern |
| Full-page re-render for live data | SSE signal-only + targeted component re-render | 2023-2025 (SSE + React state) | No page reload; only affected card updates |
| Polling (`setInterval + fetch`) | SSE push | SSE supported in all modern browsers | Server pushes, no wasted requests when nothing changes |

**Deprecated/outdated in this context:**
- `pages/api/sse.ts` with `res.write()` loop: This project uses App Router exclusively. The `ReadableStream` approach is the correct App Router pattern.
- Long-polling (client repeatedly fetches `/api/projects` on a timer): SSE is strictly better for this use case.
- chokidar v4: ESM-only, requires bundler changes. v3 is installed and configured; stay on v3.

---

## Implementation Notes for Planner

### What Needs to Change (vs Phase 3 State)

1. **`instrumentation.ts`** — Currently a stub. Fill in the `register()` body with the Node.js runtime guard and `await import('./lib/watcher')`.

2. **`lib/watcher.ts`** — New file. Initialize chokidar singleton on `globalThis`, set up subscriber registry, implement per-project debounce.

3. **`lib/scanner.ts`** — Add `scanProjectById(id: string): Promise<Project | null>` export. This requires finding the project path from the ID (try code root, then research root).

4. **`app/api/events/route.ts`** — New route handler for SSE. Returns `ReadableStream` response with SSE headers. Registers/unregisters subscriber from `watcherSubscribers`.

5. **`app/api/projects/[id]/route.ts`** — New route handler. Calls `scanProjectById(id)`, returns `Response.json(project)`.

6. **`hooks/useProjectEvents.ts`** — New hook. Opens one `EventSource` per dashboard mount, dispatches updates to parent via `onUpdate` callback.

7. **`components/projectTabs.tsx`** — Add `useState` for live data overlay, call `useProjectEvents`, merge with server-rendered props.

### What Does NOT Need to Change

- `lib/types.ts` — `SseEvent` and `SseEventType` are already defined correctly.
- `next.config.ts` — `serverExternalPackages` already includes `chokidar` and `fsevents`.
- `components/codeProjectCard.tsx` — Only the props it receives change; the card itself is unchanged.
- `components/researchProjectCard.tsx` — Same as above.
- `app/page.tsx` — Initial server render is unchanged; live updates are a client-side overlay.
- All Phase 3 server actions — Unchanged.

### Plan Boundary Suggestion

The planner may split this into 2 plans:

**Plan 04-01: Server side** — `lib/watcher.ts`, `instrumentation.ts`, `app/api/events/route.ts`, `app/api/projects/[id]/route.ts`, `lib/scanner.ts` addition.

**Plan 04-02: Client side** — `hooks/useProjectEvents.ts`, `components/projectTabs.tsx` modifications.

This boundary means Plan 04-01 can be tested with `curl` before any UI work.

---

## Open Questions

1. **Single `EventSource` placement: `ProjectTabs` vs root layout**
   - What we know: The dashboard currently has one page with tabs. The `ProjectTabs` component is the right level for the EventSource — it holds the project arrays.
   - What's unclear: If future phases add other pages, the EventSource would need to move up.
   - Recommendation: Put the EventSource in `ProjectTabs` for now. Refactor to a context provider if needed in Phase 5.

2. **`scanProjectById` path resolution for projects with special characters in names**
   - What we know: `projectIdFromPath` strips non-alphanumeric characters. A project named "My Project!" becomes `"my-project"`. Looking up `PATHS.code/my-project` would fail if the actual directory is `"My Project!"`.
   - What's unclear: Are there any actual projects with such names in the code/research roots?
   - Recommendation: Implement `scanProjectById` to try the ID as a direct directory name first, then fall back to scanning all dirs and filtering by ID match. This covers both simple and complex cases.

3. **SSE connection on mobile / background tab**
   - What we know: This is a localhost dashboard, desktop only.
   - Recommendation: Ignore; mobile and background tab behavior is irrelevant for this use case.

4. **Heartbeat / ping to prevent proxy timeouts**
   - What we know: This is localhost-only. No proxy is involved in dev mode.
   - Recommendation: Send a `ping` event on initial connection (already in the pattern above) but don't add a periodic heartbeat timer for v1. Add it in a future phase if needed.

---

## Sources

### Primary (HIGH confidence)

- `/Users/rob/project_orchestration/pro-orc/instrumentation.ts` — Existing stub confirming the register() pattern is in place
- `/Users/rob/project_orchestration/pro-orc/lib/types.ts` — `SseEvent`, `SseEventType` types already defined (lines 93-104)
- `/Users/rob/project_orchestration/pro-orc/next.config.ts` — `serverExternalPackages: ['chokidar', 'simple-git', 'fsevents']` confirmed
- `/Users/rob/project_orchestration/pro-orc/package.json` — `chokidar@^3.6.0` confirmed installed; exact version 3.6.0 verified via `require('./package.json').version`
- `/Users/rob/project_orchestration/pro-orc/lib/paths.ts` — `PATHS.code`, `PATHS.research`, `projectIdFromPath()` — exact exports the watcher needs
- `/Users/rob/project_orchestration/pro-orc/components/projectTabs.tsx` — Client component architecture; confirms `'use client'` and existing project array props
- `/Users/rob/project_orchestration/pro-orc/hooks/usePrivateProjects.ts` — Hook pattern in use; confirms `useSyncExternalStore` pattern available
- chokidar v3 README (github.com/paulmillr/chokidar) — `watch()` API, `ignored` array syntax, `persistent`/`ignoreInitial` options, events, `close()` method
- Next.js official instrumentation docs (nextjs.org/docs/app/api-reference/file-conventions/instrumentation) — `register()` called once at startup, `NEXT_RUNTIME` guard pattern, version history (stable since v15.0.0)
- Next.js official instrumentation guide (nextjs.org/docs/app/guides/instrumentation) — Dynamic import pattern within `register()`, side-effect imports
- Context7 `/vercel/next.js` — `ReadableStream` route handler pattern, SSE headers, route handler streaming

### Secondary (MEDIUM confidence)

- pedroalonso.net/blog/sse-nextjs-real-time-notifications — Subscriber Set pattern, `request.signal` abort cleanup, `ReadableStream` start() with subscriber registration
- michaelangelo.io/blog/server-sent-events — `TransformStream` alternative to `ReadableStream`, type-safe SSE message interface
- github.com/vercel/next.js/discussions/31496 — `globalThis` singleton pattern explanation: "bundle for API routes would be separate to bundle for pages... classic JS singleton approach doesn't work"
- Bash verification: `node -e "require('chokidar')"` confirmed chokidar v3.6.0 loads without errors; `chokidar.watch('/tmp', { ignored: [...] })` confirmed working with array ignore patterns

### Tertiary (LOW confidence)

- WebSearch results about Next.js SSE — Mention of `X-Accel-Buffering: no` for nginx proxy, `force-dynamic` requirement; not verified against official docs but cross-referenced with multiple sources

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — chokidar v3.6.0 confirmed installed and loadable; `serverExternalPackages` already configured; `SseEvent` types already defined
- Architecture: HIGH — `instrumentation.ts` stub already in place; `globalThis` pattern verified via official Next.js docs and community; `ReadableStream` SSE pattern verified via Context7 and official docs
- Pitfalls: HIGH — file descriptor leak, zombie connections, and params Promise pitfalls are verified against official sources and observed patterns in Next.js issues

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (chokidar v3 and Next.js 16 App Router are stable; core patterns unlikely to change)
