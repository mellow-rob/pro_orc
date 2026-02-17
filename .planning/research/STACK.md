# Technology Stack

**Project:** Pro Orc — Project Orchestration Dashboard
**Researched:** 2026-02-17
**Confidence:** HIGH (verified against installed packages and official Next.js 16.1.6 docs)

---

## Version Alignment Warning

The project spec references Next.js 15.2. All active projects on this machine already run **Next.js 16.1.6** (confirmed in `masterplan_download_gsd`, `n3ural.a1_gsd`, `sc08_website_gsd`, `landlord_checker_gsd`). This research reflects the actual current state of the ecosystem as of February 2026.

**Recommendation: Start with Next.js 16.1.6, not 15.2.** The 15.2 → 16.x gap includes breaking changes that would require migration work if you started on 15.2 and upgraded later. Building on 16.x from the start avoids that pain.

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Next.js | 16.1.6 | App framework | Current stable on this machine. App Router + Route Handlers for SSE. `instrumentation.ts` for chokidar singleton. |
| React | 19.2.4 | UI rendering | Required peer dep of Next.js 16. Server Components reduce client bundle for this read-heavy dashboard. |
| TypeScript | 5.9.3 | Type safety | Current stable. `next.config.ts` supported natively. Essential for complex data shapes from filesystem parsing. |
| Node.js | 20.9+ | Runtime | Next.js 16 minimum. macOS default should satisfy this. |

**Confidence:** HIGH — versions confirmed from installed `node_modules` on this machine.

### Styling

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Tailwind CSS | 4.1.18 | Utility CSS | Current stable on this machine. v4 uses `@theme` directive in CSS, no `tailwind.config.js`. Dark mode first = `dark:` classes or CSS variables. |
| @tailwindcss/postcss | 4.1.18 | Tailwind v4 PostCSS integration | Required in v4 — replaces the old PostCSS plugin setup. Add to `devDependencies`. |
| shadcn/ui | latest (npx shadcn@latest) | Component library | Not a package — a CLI that copies components into your project. Supports Tailwind v4. Use `npx shadcn@latest init` and `npx shadcn@latest add [component]`. |
| lucide-react | 0.563.0 | Icon set | Current stable on this machine. shadcn/ui uses it by default. |
| clsx | 2.1.1 | Conditional class names | Required by shadcn's `cn()` utility. |
| tailwind-merge | 3.4.0 | Merge Tailwind classes without conflicts | Required by shadcn's `cn()` utility. |

**Confidence:** HIGH — versions verified from installed `node_modules`.

**shadcn/ui note:** shadcn/ui is installed via CLI, not as a package. Running `npx shadcn@latest init` adds dependencies (`@radix-ui/*`, `class-variance-authority`, `clsx`, `tailwind-merge`) and creates `lib/utils.ts` with the `cn()` function. Each component (`Card`, `Badge`, `Button`, `Tooltip`, `Separator`) is added individually and owned by your codebase.

### Filesystem Monitoring

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| chokidar | 3.6.0 (v3, NOT v4) | Filesystem watcher | **Use v3, not v4.** chokidar v4 switched to ESM-only, which creates bundling conflicts with Next.js's Node.js runtime in App Router. v3.6.0 is CJS-compatible and battle-tested on macOS with fsevents. |

**Confidence:** HIGH for v3 recommendation. MEDIUM for v4 ESM concern (based on known Next.js + ESM-only packages friction, not directly tested here).

**chokidar v3 vs v4 decision:** v4 (released 2024) is ESM-only. Next.js App Router's server-side bundling handles ESM packages but with some friction — requires `serverExternalPackages` config AND the package must be in the allowlist or explicitly named. v3 avoids this entirely. Since this is a local dev tool with no scaling concerns, v3 stability is worth more than v4's minor improvements.

**Singleton pattern via `instrumentation.ts`:**
```typescript
// instrumentation.ts (root of project, NOT in /app)
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./lib/watcher')  // side-effect: starts chokidar
  }
}
```
`register()` is called exactly once when the Next.js server starts. This is the correct pattern for global singletons — confirmed in Next.js 16.1.6 docs.

### Git Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| simple-git | ^3.x (latest 3.x) | Git operations from Node.js | Async Promise-based API. Supports timeout via `simpleGit({ timeout: { block: 5000 } })`. Need `simpleGit('/path/to/repo')` — always pass the working directory explicitly. |

**Confidence:** MEDIUM — simple-git 3.x API is well-established. Exact latest version not confirmed (no local install found), but 3.x line has been stable since 2023.

**simple-git note:** Must be added to `serverExternalPackages` in `next.config.ts` because it spawns child processes and uses Node.js internals that conflict with Next.js's server bundling.

### SSE (Live Updates)

| Mechanism | Version | Purpose | Why |
|-----------|---------|---------|-----|
| ReadableStream + Route Handler | Native Web API (Next.js 16) | Push filesystem change events to browser | No additional package needed. Built into Next.js Route Handlers. SSE via `text/event-stream` content type. |

**Pattern:**
```typescript
// app/api/events/route.ts
export const dynamic = 'force-dynamic'

export async function GET() {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    start(controller) {
      // Subscribe to chokidar singleton events
      const cleanup = subscribeToWatcher((event) => {
        const data = `data: ${JSON.stringify(event)}\n\n`
        controller.enqueue(encoder.encode(data))
      })

      return () => cleanup()
    }
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    }
  })
}
```

**`export const dynamic = 'force-dynamic'` is required** — without it, Next.js 16's default caching may try to statically optimize the route.

**Confidence:** HIGH — pattern confirmed from official Next.js 16.1.6 docs.

### Markdown Parsing

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| gray-matter | 4.0.3 | Parse YAML frontmatter from .md files | Current stable (confirmed in sc08_website_gsd project on this machine). Handles `STATE.md`, `ROADMAP.md`, `PROJECT.md` parsing. No YAML frontmatter in these files currently, but gray-matter also does clean content extraction. |

**Confidence:** HIGH — version confirmed from local `node_modules`.

**Alternative considered:** `remark` / `unified` — overkill for this use case. We don't need to render markdown to HTML; we need to extract structured data (headings, checkbox lists, specific sections). Use regex + string parsing for the GSD-specific formats (STATE.md, ROADMAP.md sections). gray-matter handles any YAML frontmatter that might be present.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| zod | 4.3.6 | Runtime type validation | Validate parsed filesystem data shapes (project cards, state entries) before passing to UI. ESM-only in v4 — use `serverExternalPackages` if needed. |
| clsx | 2.1.1 | Class name composition | Already required by shadcn/ui. Use everywhere for conditional classes. |
| tailwind-merge | 3.4.0 | Merge Tailwind classes | Already required by shadcn/ui. Use in `cn()` utility. |

**Confidence:** HIGH — versions from local `node_modules`.

---

## next.config.ts — Required Configuration

```typescript
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // Required: prevent Next.js from bundling Node.js-native packages
  serverExternalPackages: ['chokidar', 'simple-git', 'fsevents'],

  // Turbopack is default in Next.js 16 — no config needed to enable
  // Disable if you have custom webpack needs:
  // turbopack: false,

  // Optional: faster dev startup (beta)
  experimental: {
    turbopackFileSystemCacheForDev: true,
  },
}

export default nextConfig
```

**`serverExternalPackages` is critical.** Without it, Next.js will try to bundle `chokidar` and `simple-git` into server-side bundles, which fails because they use Node.js native modules (`fsevents`, `child_process`). Neither is in Next.js's built-in auto-exclude list.

---

## What NOT to Use

| Anti-Choice | Why Not | Use Instead |
|-------------|---------|-------------|
| chokidar v4 | ESM-only — friction with Next.js CJS/ESM bundling | chokidar 3.6.0 |
| WebSockets | Overkill for one-way server→client updates. Requires additional server setup | SSE via ReadableStream |
| Polling (`setInterval` + fetch) | Works but wastes resources when nothing has changed | SSE + chokidar events |
| Next.js Pages Router | Old API, no Server Components | App Router (default in Next.js 16) |
| SWR / React Query | Adds complexity for a local app with no API caching needs | Direct Server Component data fetching + SSE for live updates |
| Prisma / SQLite | The filesystem IS the database. Adding a DB layer defeats the purpose | `fs` module + gray-matter |
| next-themes | Unnecessary for a dark-mode-only, single-user app | Hard-code dark theme in CSS |
| framer-motion | Heavy for simple transitions on a utility dashboard | `motion` 12.x (already used in n3ural project) or CSS transitions |
| middleware.ts | Deprecated in Next.js 16, renamed to proxy.ts | `proxy.ts` for any request interception (but none needed for localhost-only app) |
| next/image | Unnecessary — no external images in a filesystem dashboard | Plain `<img>` or SVG icons |
| i18n | Deprecated in Next.js 16 App Router | Not needed for single-user German+UI tool |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Framework | Next.js 16 App Router | Vite + React SPA | App Router gives Server Components, SSE route handlers, and instrumentation.ts out of the box. For a local tool, the full Next.js setup is the right fit. |
| Filesystem watcher | chokidar 3.x | Node.js native `fs.watch` | `fs.watch` is unreliable on macOS for directory recursion and doesn't report changed file paths cleanly. chokidar's fsevents integration is far more reliable. |
| Git integration | simple-git | nodegit, isomorphic-git | simple-git is the simplest async Promise API for `git log`, `git status` calls. nodegit is a native C++ binding (compilation issues). isomorphic-git is for cross-platform/browser scenarios. |
| Component library | shadcn/ui | Radix UI (bare), Headless UI | shadcn/ui gives pre-built accessible components with Tailwind styles that you own. Bare Radix needs more setup; Headless UI is Tailwind Labs' library but less component-rich. |
| Icons | lucide-react | heroicons, phosphor-icons | shadcn/ui defaults to lucide-react. Staying consistent avoids dual icon libraries. |
| Markdown parser | gray-matter | remark, front-matter | gray-matter is battle-tested and minimal. remark is for full HTML rendering (overkill). `front-matter` is similar to gray-matter but less maintained. |

---

## Installation

```bash
# Initialize project
npx create-next-app@latest pro-orc --typescript --tailwind --eslint --app --src-dir

# After init, upgrade to latest versions if needed
npm install next@latest react@latest react-dom@latest

# Filesystem & Git
npm install chokidar@^3.6.0 simple-git gray-matter

# shadcn/ui (interactive CLI — run and follow prompts)
npx shadcn@latest init

# Add shadcn components as needed
npx shadcn@latest add card badge button tooltip separator progress

# UI utilities (installed by shadcn, but list explicitly)
npm install clsx tailwind-merge lucide-react

# Optional: validation
npm install zod

# Dev dependencies (likely already installed by create-next-app)
npm install -D @types/node typescript @tailwindcss/postcss
```

---

## Key Configuration Files

### `instrumentation.ts` (root)
```typescript
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Import watcher module as side effect — starts chokidar singleton
    await import('./lib/watcher')
  }
}
```

### `lib/watcher.ts`
```typescript
import chokidar from 'chokidar'
import os from 'os'
import path from 'path'

const BASE = path.join(os.homedir(), 'project_orchestration')
const SCAN_PATHS = [
  path.join(BASE, 'code'),
  path.join(BASE, 'project research'),
]

// Singleton: module is only loaded once
export const watcher = chokidar.watch(SCAN_PATHS, {
  persistent: true,
  ignoreInitial: true,
  depth: 4,
  ignored: /(node_modules|\.git|\.venv)/,
})

// Pub-sub: Route handlers subscribe to receive events
type Listener = (event: { type: string; path: string }) => void
const listeners = new Set<Listener>()

export function subscribeToWatcher(fn: Listener) {
  listeners.add(fn)
  return () => listeners.delete(fn)
}

watcher.on('all', (event, filePath) => {
  for (const fn of listeners) {
    fn({ type: event, path: filePath })
  }
})
```

---

## Sources

- Next.js 16.1.6 blog post: https://nextjs.org/blog/next-16 (release: October 21, 2025)
- Next.js 15.2 blog post: https://nextjs.org/blog/next-15-2 (release: February 26, 2025)
- Next.js 16.1.6 instrumentation docs: https://nextjs.org/docs/app/guides/instrumentation
- Next.js 16.1.6 instrumentation API reference: https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation
- Next.js 16.1.6 route handlers (SSE): https://nextjs.org/docs/app/api-reference/file-conventions/route
- Next.js 16.1.6 serverExternalPackages: https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages
- chokidar 3.6.0 package.json: confirmed in `/Users/rob/project_orchestration/code/PowerTrip/trip-agent/node_modules/chokidar/`
- Next.js 16.1.6 confirmed installed in 4 local projects
- Tailwind CSS 4.1.18 confirmed installed in local projects
- lucide-react 0.563.0 confirmed from n3ural.a1_gsd project
- gray-matter 4.0.3 confirmed from sc08_website_gsd project
- clsx 2.1.1, tailwind-merge 3.4.0, typescript 5.9.3, react 19.2.4 confirmed from local projects
- zod 4.3.6 confirmed from sc08_website_gsd project
