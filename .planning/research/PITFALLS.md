# Domain Pitfalls

**Domain:** Local Next.js 15.2 dashboard with filesystem monitoring (chokidar + SSE + git integration)
**Researched:** 2026-02-17
**Confidence:** HIGH for Next.js lifecycle and SSE patterns (official docs verified); MEDIUM for chokidar/simple-git specifics (training data + ecosystem knowledge, not directly verifiable via WebFetch); HIGH for Tailwind v4 breaking changes (official upgrade guide verified)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or complete feature failure.

---

### Pitfall 1: chokidar Not in serverExternalPackages — Silent Bundling Failure

**What goes wrong:** Next.js App Router automatically bundles all server-side dependencies. When chokidar (and simple-git) are bundled by Next.js's webpack/Turbopack, their native Node.js bindings (`fsevents` on macOS, native watchers) are stripped or fail to resolve. The result is either a hard crash on startup, silent fallback to polling (extremely CPU-intensive), or a confusing "module not found" error for native binaries.

**Why it happens:** Neither `chokidar` nor `simple-git` are in Next.js's auto-excluded packages list (verified against the official `server-external-packages.jsonc`). Popular auto-excluded packages include `sharp`, `prisma`, `pino` — but NOT chokidar or simple-git.

**Consequences:** On macOS, `fsevents` binary fails to load through the bundler → chokidar silently falls back to polling mode → 100% CPU on file-heavy directories. On Linux, inotify bindings break → watcher never fires → dashboard shows stale data forever with no error.

**Prevention:**
```js
// next.config.js
module.exports = {
  serverExternalPackages: ['chokidar', 'simple-git', 'fsevents'],
}
```
Add this before writing a single line of watcher code. Verify by checking `process.env.NEXT_RUNTIME === 'nodejs'` in instrumentation.ts and logging the chokidar version on startup.

**Detection:** CPU usage spikes to 100% on `next dev`. Watcher events stop firing after the first file change. Console shows `Error: Cannot find module 'fsevents'` or similar.

**Phase:** Foundation/Setup phase — Day 0 of implementation.

---

### Pitfall 2: chokidar Watcher Not Closed on Hot Reload — File Descriptor Exhaustion

**What goes wrong:** In `next dev`, the Node.js server process does NOT restart on every file change. Hot module replacement (HMR) keeps the same process alive. If instrumentation.ts creates a chokidar watcher but has no singleton guard, every HMR cycle that touches instrumentation.ts (or any file it imports) creates a new watcher instance without closing the old one. On macOS, the default `fs.watch` limit is 256 open kqueue file descriptors per process. A directory with 50 markdown files accumulates 4-5 watcher instances before the process crashes with `EMFILE: too many open files`.

**Why it happens:** The Next.js docs state that `register()` in instrumentation.ts is called "once when a new Next.js server instance is initiated." This is true for production. In development, HMR can cause `register()` to be called again if instrumentation.ts or any of its imports are modified. The docs are silent on this edge case.

**Consequences:** Progressive file descriptor leak during development. The crash typically manifests 10-30 minutes into a dev session when the project has many `.md` files. Production is unaffected.

**Prevention:** Use a module-level singleton guard:
```typescript
// instrumentation.ts
let watcherInitialized = false

export async function register() {
  if (process.env.NEXT_RUNTIME !== 'nodejs') return
  if (watcherInitialized) return
  watcherInitialized = true

  const { startWatcher } = await import('./lib/watcher')
  await startWatcher()
}
```
In the watcher module, store the watcher instance on `globalThis` (not module scope) because module scope can be reset by bundler HMR, but `globalThis` persists across module re-evaluations in the same process:
```typescript
// lib/watcher.ts
declare global {
  var __chokidarWatcher: import('chokidar').FSWatcher | undefined
}

export async function startWatcher() {
  if (globalThis.__chokidarWatcher) {
    await globalThis.__chokidarWatcher.close()
  }
  globalThis.__chokidarWatcher = chokidar.watch(WATCH_PATH, { persistent: true })
}
```

**Detection:** Run `lsof -p $(pgrep -f 'next dev') | grep inotify | wc -l` (Linux) or `lsof -p $(pgrep -f 'next dev') | grep kqueue | wc -l` (macOS) during a dev session. Count should be stable. If it grows monotonically, you have a leak.

**Phase:** Core watcher infrastructure phase.

---

### Pitfall 3: SSE Route Handler Leaks — Missing AbortSignal Cleanup

**What goes wrong:** SSE route handlers in Next.js App Router return a `ReadableStream` that stays open as long as the client is connected. When the browser tab closes, refreshes, or the user navigates away, the client connection drops. Without explicit cleanup tied to `request.signal` (the AbortSignal), the server-side ReadableStream controller and any associated event listeners remain alive indefinitely. With multiple browser tabs, this compounds: 10 open tabs = 10 zombie streams holding chokidar event listeners.

**Why it happens:** Next.js route handlers do not automatically cancel the ReadableStream when a client disconnects. The `request.signal` AbortSignal IS available and fires `abort` on disconnect, but the developer must explicitly wire cleanup to it. The official Next.js streaming docs show a basic pull-based iterator pattern with no cleanup example.

**Consequences:** Memory leak proportional to the number of unique SSE connections ever made (across page navigations). Each zombie stream also holds a chokidar `change` listener, eventually causing the event emitter to emit a `MaxListenersExceededWarning` and degraded event delivery.

**Prevention:**
```typescript
// app/api/events/route.ts
export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  const encoder = new TextEncoder()
  let cleanupFn: (() => void) | undefined

  const stream = new ReadableStream({
    start(controller) {
      const listener = (event: FileChangeEvent) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`))
      }
      fileChangeEmitter.on('change', listener)

      cleanupFn = () => {
        fileChangeEmitter.off('change', listener)
        controller.close()
      }
    },
    cancel() {
      cleanupFn?.()
    },
  })

  // Also wire to AbortSignal for immediate cleanup on client disconnect
  request.signal.addEventListener('abort', () => cleanupFn?.())

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
    },
  })
}
```

**Detection:** Open 20 browser tabs pointing to the dashboard, navigate away from all of them, then check process memory. It should return to baseline. If it keeps growing, cleanup is broken.

**Phase:** SSE/streaming infrastructure phase.

---

### Pitfall 4: SSE Route Handler Served Cached — Missing `dynamic = 'force-dynamic'`

**What goes wrong:** In Next.js 15, GET route handlers default to `dynamic = 'auto'`. For routes that don't use Dynamic APIs (cookies, headers, searchParams), Next.js may statically cache the response at build time or ISR. An SSE route handler cached this way returns a static response body to every client — the stream body is captured once and replayed as a static string, not as a live stream. The client appears connected but receives no new events.

**Why it happens:** Next.js 15 changed GET handler caching default from static to dynamic (v15.0.0-RC), but `'auto'` heuristics can still cache routes that appear static. SSE endpoints must explicitly opt out.

**Consequences:** Dashboard appears to work in development (where routes are always dynamic) but is broken in production builds. Silent failure — the client EventSource connects with HTTP 200 but never receives `change` events.

**Prevention:** Every SSE route handler must export:
```typescript
export const dynamic = 'force-dynamic'
```
This is non-negotiable for any long-lived streaming endpoint.

**Detection:** Run `next build && next start`. Open the dashboard. Make a file change. If no SSE event arrives within 2 seconds, the route is being statically cached.

**Phase:** SSE/streaming infrastructure phase — add as the first line of any route.ts file serving SSE.

---

### Pitfall 5: simple-git Concurrent Calls Cause Contention or Timeout

**What goes wrong:** simple-git instances are NOT concurrency-safe by default. Each `SimpleGit` instance wraps a child process queue. If `chokidar` fires rapid file change events (e.g., a bulk git checkout modifying 50 files), each change event triggers a `git.log()` or `git.status()` call. With a naive implementation, these pile up as concurrent promises. Git itself serializes via its lock file (`.git/index.lock`): concurrent git processes on the same repository throw `fatal: Unable to create '.../.git/index.lock': File exists`. simple-git surfaces this as a rejected promise with an unhelpful `GitError`.

**Why it happens:** File watchers fire per-file, not per-operation. A git checkout of 50 files fires 50 `change` events in rapid succession. Without debouncing AND per-instance queueing, the result is 50 simultaneous `git status` spawns.

**Consequences:** Git lock errors cascade through the SSE event pipeline. The dashboard shows error states or stale data. In worst cases, git leaves behind a stale `.git/index.lock` that blocks all subsequent git operations until manually removed.

**Prevention:**
1. Debounce chokidar events before triggering git operations (300-500ms minimum):
```typescript
import { debounce } from 'lodash-es'

const handleChange = debounce(async (filePath: string) => {
  const status = await git.status()
  broadcast(status)
}, 400)

watcher.on('all', handleChange)
```
2. Use a single `SimpleGit` instance per repository — never create one per event.
3. Wrap all `git.*()` calls in try/catch and detect lock errors specifically for graceful retry:
```typescript
try {
  return await git.status()
} catch (e) {
  if (String(e).includes('index.lock')) {
    await new Promise(r => setTimeout(r, 200))
    return await git.status() // single retry
  }
  throw e
}
```

**Detection:** Enable simple-git debug logging (`DEBUG=simple-git:*`) and watch for concurrent `spawn git` entries. If you see them interleaved, debouncing is broken.

**Phase:** Git integration phase.

---

### Pitfall 6: Markdown Parsing Mid-Save File — Crash on Malformed Content

**What goes wrong:** Editors write files atomically (write to temp file, rename) or non-atomically (write bytes progressively). chokidar fires `change` on the first write, which may arrive before the file is fully flushed to disk. Parsing a half-written YAML frontmatter block (`---\ntitle: My Proj`) with a YAML parser throws a `YAMLException`. A half-written code fence (`` ```js `` without closing ```` ``` ````) causes some remark plugins to enter infinite loops or produce deeply wrong ASTs. If the parse error propagates to the SSE broadcast, it kills the event stream for all connected clients.

**Why it happens:** The `change` event fires on file modification, not on file close. There is no cross-platform "file-closed" event in Node.js. Atomic writes (common in VS Code) solve this, but not all editors (Vim, Emacs, nano) are atomic.

**Consequences:** Dashboard crashes or shows stale data whenever a user saves mid-type. UX is broken during active editing — exactly the use case the dashboard exists for.

**Prevention:**
1. Wrap ALL markdown parsing in try/catch — never let a parse error propagate to the stream controller:
```typescript
function parseMarkdownSafe(content: string): ParsedFile | null {
  try {
    return parseMarkdown(content)
  } catch {
    return null  // return null, broadcast nothing, try again on next change event
  }
}
```
2. Add a `awaitWriteFinish` option to chokidar for non-atomic editors:
```typescript
chokidar.watch(path, {
  awaitWriteFinish: {
    stabilityThreshold: 100,  // ms file size must be stable
    pollInterval: 50,
  }
})
```
3. For frontmatter: use a fault-tolerant parser like `gray-matter` with `{ excerpt: false }` and catch all exceptions. Never use raw `js-yaml.load()` directly on untrusted frontmatter.

**Detection:** Open a markdown file in any editor. Save it during mid-word typing. If the dashboard shows an error state or logs a parse exception, the guard is missing.

**Phase:** Markdown parsing / file processing phase.

---

### Pitfall 7: Tailwind CSS v4 Breaking Changes from v3 — shadcn/ui Component Breakage

**What goes wrong:** Tailwind CSS v4.0 is a breaking rewrite. Projects migrating from v3 (or using documentation/components written for v3) face multiple silent failures: components render with wrong shadows, borders, ring widths, and color opacities without any build-time error. The breaking changes are purely at the class name level — the build succeeds, the styles just don't do what v3 did.

**Specific breaking changes verified in v4 upgrade guide:**
- `shadow-sm` → `shadow-xs`, `shadow` → `shadow-sm` (one step smaller)
- `blur-sm` → `blur-xs`, `blur` → `blur-sm` (one step smaller)
- `rounded-sm` → `rounded-xs`, `rounded` → `rounded-sm`
- `ring` → `ring-3` (default ring width changed from 3px to 1px)
- `outline-none` → `outline-hidden`
- `bg-opacity-*`, `text-opacity-*`, `border-opacity-*` removed — use `/` syntax: `bg-black/50`
- `flex-shrink-*` → `shrink-*`, `flex-grow-*` → `grow-*`
- `!` modifier moves from prefix to suffix: `!flex` → `flex!`
- PostCSS plugin: `tailwindcss` → `@tailwindcss/postcss`
- CSS import: `@tailwind base/components/utilities` → `@import "tailwindcss"`
- Config file: `tailwind.config.js` is no longer scanned by default — use CSS `@theme` instead
- Space-between selector changed from `:not([hidden]) ~ :not([hidden])` to `:not(:last-child)` — affects spacing in certain layouts

**Why it happens:** shadcn/ui components use v3 utility class names. Any component copied from shadcn before they updated for v4 will have broken styles. The `npx shadcn@latest init` command as of early 2026 generates v4-compatible CSS variable patterns, but individual component code may still use v3 class names in their source if not yet updated.

**Consequences:** The entire UI looks subtly wrong — wrong shadow depths, wrong ring colors on focus states, wrong border colors (`border` defaults to `currentColor` in v4, not `gray-200`). Design QA failures that are tedious to fix component-by-component.

**Prevention:**
1. Run `npx @tailwindcss/upgrade` before writing any custom CSS.
2. Use `npx shadcn@latest init` (not an older shadcn version) to ensure v4-compatible CSS variables.
3. After init, verify `postcss.config.mjs` uses `@tailwindcss/postcss` not `tailwindcss`.
4. Audit every component for: `shadow-sm`, `rounded-sm`, `blur-sm`, `ring`, `outline-none`, `bg-opacity-*`.
5. If the upgrade tool is insufficient, fall back to Tailwind v3 (the Next.js docs explicitly document a v3 setup path for "broader browser support").

**Detection:** Inspect focus rings on buttons — if they are 1px wide and gray instead of 3px wide and blue, Tailwind v4's defaults are active but components were written for v3.

**Phase:** UI/styling setup phase — resolve before building any components.

---

## Moderate Pitfalls

### Pitfall 1: React Strict Mode Double-Effect on SSE EventSource — Duplicate Connections

**What goes wrong:** React Strict Mode is enabled by default in Next.js App Router (since v13.5.1). In development, Strict Mode mounts every component twice (mount → unmount → mount) to detect side effects. Any `useEffect` that creates an `EventSource` for SSE will open 2 connections to the route handler. If cleanup in the effect's return function is missing or async (EventSource close is synchronous but takes a tick), both connections survive, and the client receives every event twice.

**Prevention:** Always return a cleanup function from the SSE effect:
```typescript
useEffect(() => {
  const es = new EventSource('/api/events')
  es.onmessage = handleEvent
  return () => es.close()  // synchronous close — survives strict mode double-mount
}, [])
```

**Detection:** In dev, add a `console.log('SSE connected')` in the route handler. You should see it logged twice on initial page load if cleanup is missing.

**Phase:** Client-side SSE consumption phase.

---

### Pitfall 2: nginx / Reverse Proxy Buffering Breaks SSE

**What goes wrong:** nginx and most reverse proxies buffer response bodies by default. SSE relies on the client receiving individual `data:` chunks as they are flushed. With proxy buffering enabled, chunks accumulate in the proxy buffer until it fills, then all events arrive at once (burst delivery) or not at all until the connection closes.

**Why it happens:** nginx's `proxy_buffering on` is the default. This is appropriate for normal HTTP responses but catastrophic for SSE.

**Consequences:** SSE events are delayed by seconds or never arrive if the dashboard is behind nginx (common in local dev setups with nginx proxying to `next dev`).

**Prevention:** Set `X-Accel-Buffering: no` in SSE route handler response headers (nginx respects this header to disable buffering per-response):
```typescript
return new Response(stream, {
  headers: {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    'X-Accel-Buffering': 'no',
    Connection: 'keep-alive',
  },
})
```
This is documented in the Next.js self-hosting guide as the correct approach.

**Detection:** Test SSE through nginx. If events arrive in bursts rather than one by one, buffering is active.

**Phase:** Infrastructure/deployment phase. Not critical for pure localhost dev without a proxy.

---

### Pitfall 3: Turbopack Filesystem Watch Root Boundary Excludes Watched Directories

**What goes wrong:** Turbopack (the default bundler in `next dev` as of Next.js 15) restricts its own filesystem watching to the project root (determined by lockfile location). This is separate from the app's chokidar watcher, but the interaction matters: if the dashboard watches a directory outside the project root (e.g., `~/Documents/projects/`), Turbopack's watch boundary is unaffected. However, if the watched directory is inside the project root, Turbopack may reload or trigger additional HMR events for `.md` files it picks up as "source files". This can cause HMR loops.

**Prevention:** Configure the watched content directory to be outside the `src/` tree (e.g., a `content/` directory at the project root or an external path). Add the content directory to `.gitignore` if it is auto-generated. If watching inside `src/`, exclude `.md` files from Turbopack's processing using `turbopack.rules` or `next.config.js` exclusions.

**Detection:** Editing a `.md` file in the watched directory triggers a full Next.js HMR reload instead of only an SSE event.

**Phase:** Core watcher infrastructure phase.

---

### Pitfall 4: simple-git Called Without Guarding Against Non-Git Directories

**What goes wrong:** The dashboard watches a filesystem directory. If a user points the watcher at a directory that is not a git repository (no `.git` folder), simple-git throws `fatal: not a git repository (or any of the parent directories): .git`. This error is not caught, crashes the git integration module, and can take down the SSE event pipeline.

**Prevention:**
```typescript
async function isGitRepo(dir: string): Promise<boolean> {
  try {
    await git.cwd(dir).revparse(['--git-dir'])
    return true
  } catch {
    return false
  }
}
```
Call this before initializing git integration. If false, skip git operations and surface a clear UI warning rather than a crash.

**Detection:** Point the watcher at a non-git directory (e.g., `/tmp`). If the process throws an unhandled rejection, the guard is missing.

**Phase:** Git integration phase.

---

## Minor Pitfalls

### Pitfall 1: chokidar `usePolling: true` Set Accidentally — CPU Spike

**What goes wrong:** If `serverExternalPackages` is not configured and chokidar is bundled (see Critical Pitfall 1), it falls back to polling. Developers often discover this and add `usePolling: true` explicitly to "fix" the issue instead of fixing the root cause (missing `serverExternalPackages`). Polling on a directory with hundreds of markdown files runs every 100ms per file — creating 1,000+ `fs.stat` calls per second.

**Prevention:** Never use `usePolling: true` in production. Fix the bundling issue instead. Polling is only acceptable in Docker/WSL environments where native watchers are unreliable.

**Phase:** Core watcher infrastructure phase.

---

### Pitfall 2: Markdown `gray-matter` Frontmatter Throws on `---` in Body

**What goes wrong:** `gray-matter` uses `---` as a frontmatter delimiter. If a markdown file has `---` as a horizontal rule anywhere in the body (which is valid Markdown), gray-matter may misparse the document, treating the body content as additional frontmatter. This produces corrupt parsed objects or throws a YAML parse error.

**Prevention:** Configure gray-matter to use a unique delimiter or use a more robust frontmatter approach. Alternatively, validate that `---` horizontal rules in markdown are replaced with `* * *` or `---` only at the start of file for frontmatter. Always wrap gray-matter calls in try/catch (see Critical Pitfall 6).

**Phase:** Markdown parsing phase.

---

### Pitfall 3: Next.js 15.2 `params` Is Now a Promise — Breaks Route Handler Param Access

**What goes wrong:** In Next.js 15.0+, `context.params` in Route Handlers is a Promise, not a plain object. Code like `const { id } = context.params` silently returns `undefined`. The correct pattern is `const { id } = await context.params`. This is a breaking change from Next.js 14 that trips up developers copying older code examples.

**Prevention:** Always `await context.params` in route handlers. Enable TypeScript strict mode to catch this at compile time.

**Phase:** Any route handler implementation phase.

---

### Pitfall 4: SSE `heartbeat` Omission — Proxy/Browser Drops Idle Connections

**What goes wrong:** If the watched directory has no file changes for 30+ seconds, SSE connections go idle. Many HTTP proxies (nginx, Caddy, HAProxy) have default idle timeout of 60-75 seconds. Browsers also impose their own timeout. Without a periodic heartbeat comment (`: ping\n\n`), the connection is silently dropped and the EventSource client may or may not reconnect automatically.

**Prevention:** Send a `: ping\n\n` comment every 15-20 seconds:
```typescript
const heartbeat = setInterval(() => {
  try {
    controller.enqueue(encoder.encode(': ping\n\n'))
  } catch {
    clearInterval(heartbeat)
  }
}, 15000)
```
Wire `clearInterval(heartbeat)` to the cleanup function.

**Phase:** SSE/streaming infrastructure phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Project setup / next.config.js | chokidar/simple-git bundled by Next.js | Add to `serverExternalPackages` on day 0 |
| instrumentation.ts singleton | Multiple watcher instances on HMR | `globalThis` guard + close before re-create |
| SSE route handler | Not force-dynamic → cached response | `export const dynamic = 'force-dynamic'` |
| SSE route handler | No AbortSignal cleanup → zombie streams | Wire `request.signal.addEventListener('abort', cleanup)` |
| Client SSE hook | React Strict Mode double-connection | Always return `() => es.close()` from useEffect |
| Git integration | Concurrent git calls → index.lock errors | Single instance + debounce + lock error retry |
| Git integration | Non-git directory crash | `isGitRepo()` guard before any git call |
| Markdown parsing | Mid-save parse crash → stream death | try/catch ALL parsing; never propagate parse errors to stream |
| Markdown frontmatter | `---` in body confuses gray-matter | Try/catch + validate output; use `excerpt: false` |
| Tailwind v4 setup | Wrong utility names from v3 docs | Run upgrade tool; audit shadow/ring/rounded classes |
| shadcn/ui components | v3 class names in component code | Use latest `npx shadcn@latest` CLI; audit after add |
| Reverse proxy | SSE chunks buffered | `X-Accel-Buffering: no` header on SSE response |
| Turbopack dev | Watched `.md` files trigger HMR loop | Keep content dir outside or excluded from Turbopack watch |

---

## Sources

- Next.js instrumentation.ts docs (official, verified): https://nextjs.org/docs/app/guides/instrumentation
- Next.js instrumentation.ts API reference (official, verified): https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation
- Next.js route handlers docs (official, verified): https://nextjs.org/docs/app/building-your-application/routing/route-handlers
- Next.js route segment config / dynamic / maxDuration (official, verified): https://nextjs.org/docs/app/api-reference/file-conventions/route-segment-config
- Next.js serverExternalPackages (official, verified — chokidar/simple-git confirmed NOT in auto-list): https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages
- Next.js self-hosting / streaming / X-Accel-Buffering (official, verified): https://nextjs.org/docs/app/guides/self-hosting
- Next.js Fast Refresh docs (official, verified): https://nextjs.org/docs/architecture/fast-refresh
- Next.js reactStrictMode (official, verified — App Router strict mode ON by default since 13.5.1): https://nextjs.org/docs/app/api-reference/config/next-config-js/reactStrictMode
- Next.js Turbopack docs (official, verified — filesystem watch root boundary): https://nextjs.org/docs/app/api-reference/config/next-config-js/turbopack
- Tailwind CSS v4 breaking changes / upgrade guide (official, verified): https://tailwindcss.com/docs/upgrade-guide
- Next.js CSS / Tailwind v4 setup (official, verified): https://nextjs.org/docs/app/building-your-application/styling/tailwind-css
- chokidar singleton patterns, file descriptor limits, polling fallback: MEDIUM confidence — ecosystem knowledge, training data
- simple-git concurrency / git index.lock behavior: MEDIUM confidence — ecosystem knowledge, training data
- Markdown mid-save parsing risks: MEDIUM confidence — ecosystem knowledge, training data
