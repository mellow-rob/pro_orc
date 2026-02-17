# Project Research Summary

**Project:** Pro Orc — Project Orchestration Dashboard
**Domain:** Local single-user developer dashboard with filesystem monitoring, git integration, and real-time SSE updates
**Researched:** 2026-02-17
**Confidence:** HIGH

## Executive Summary

Pro Orc is a localhost-only Next.js dashboard that reads project state from the filesystem and surfaces it in a card grid with live updates. Experts build this class of tool as a thin read-only UI layer over existing data — no database, no auth, no external APIs. The architecture centers on a single chokidar filesystem watcher (initialized once via `instrumentation.ts`) that pushes change signals to browser clients over SSE, where they trigger targeted re-fetches of per-project data from a simple Route Handler API layer. This is a well-understood pattern with no architectural unknowns.

The recommended stack is Next.js 16.1.6 (App Router), React 19.2.4, TypeScript 5.9.3, Tailwind CSS 4.1.18, shadcn/ui, chokidar 3.6.0 (v3, not v4), and simple-git 3.x. All versions are confirmed as currently installed on this machine. The only non-obvious technology decision is using chokidar v3 rather than v4: v4 is ESM-only and creates bundling friction with Next.js; v3 is CJS-compatible and battle-tested on macOS with fsevents. Start on Next.js 16.x from day one — the spec reference to 15.2 is outdated and starting there would require migration work.

The key risks are infrastructure-level, not domain-level: chokidar and simple-git must be declared in `serverExternalPackages` on day one or fsevents breaks silently; the chokidar singleton must be stored on `globalThis` (not module scope) to survive HMR in dev mode; the SSE route handler must wire cleanup to `request.signal` or zombie streams accumulate; and all markdown parsing must be wrapped in try/catch or a mid-save file write will crash the event pipeline. These pitfalls are well-documented and entirely preventable with upfront configuration.

---

## Key Findings

### Recommended Stack

The stack is deliberately minimal for a local single-user tool. Next.js App Router provides everything needed out of the box: Server Components for initial render, Route Handlers for the API layer and SSE endpoint, and `instrumentation.ts` for singleton initialization. No database is needed because the filesystem IS the database — `.planning/STATE.md`, `ROADMAP.md`, and `PROJECT.md` are the authoritative data sources.

**Core technologies:**
- **Next.js 16.1.6**: App framework — App Router + Route Handlers for SSE, `instrumentation.ts` for chokidar singleton, Server Components reduce client bundle
- **React 19.2.4**: UI rendering — required peer dep of Next.js 16; Server Components handle read-heavy initial render
- **TypeScript 5.9.3**: Type safety — essential for complex data shapes from filesystem parsing; `next.config.ts` supported natively
- **Tailwind CSS 4.1.18**: Styling — v4 uses `@theme` in CSS, no `tailwind.config.js`; dark-mode-first, no toggle needed
- **shadcn/ui (CLI)**: Components — installed via `npx shadcn@latest`, not a package; owns `Card`, `Badge`, `Button`, `Tooltip`, `Separator`
- **chokidar 3.6.0**: Filesystem watching — v3 (NOT v4); CJS-compatible, fsevents on macOS, reliable directory recursion
- **simple-git 3.x**: Git integration — async Promise API for `git log`, `git status`, `git branch` with timeout wrapper
- **gray-matter 4.0.3**: Markdown parsing — frontmatter extraction and content parsing for `.planning/` files; fault-tolerant
- **SSE via ReadableStream**: Live updates — native Web API in Next.js 16 Route Handlers; no extra package needed

**Critical config:** `serverExternalPackages: ['chokidar', 'simple-git', 'fsevents']` in `next.config.ts` must be set before writing any watcher code.

See full stack research: `.planning/research/STACK.md`

### Expected Features

The dashboard has a small, well-defined feature set. The core value proposition is GSD workflow awareness + Claude tool inventory + localhost-first simplicity — no comparable tool combines all three.

**Must have (table stakes):**
- Project card grid with auto-discovery of `code/` and `project research/` directories
- GSD phase + next step displayed on each card face
- Git last commit timestamp and branch per code project
- Live updates via chokidar + SSE (dashboard that requires F5 feels broken)
- Research project card variant (no git metrics, different metadata)
- Quick actions: Open in Terminal, Open in Finder, Open Notion URL (parsed from PROJECT.md)
- Dark mode only — no toggle needed for a developer tool

**Should have (differentiators):**
- Claude Tools inventory panel (Skills, MCP servers, Plugins from `~/.claude/`)
- Phase progress indicator (checkbox counting in ROADMAP.md)
- Dual card types: code projects vs research projects render differently
- Notion URL auto-discovery from `<!-- notion: URL -->` comment in PROJECT.md

**Defer (v2+):**
- Light mode toggle
- Inline markdown preview (adds remark/rehype deps for little gain)
- Notion API read/write (OAuth, token management — disproportionate for localhost tool)
- Multi-terminal support (Terminal.app only in v1)
- Any editing capability in the UI (Pro Orc is a read window, not an editor)
- Triggering GSD commands from the UI

See full features research: `.planning/research/FEATURES.md`

### Architecture Approach

The architecture is deliberately simple: one singleton chokidar watcher emits to an in-memory EventBus, SSE Route Handlers subscribe to that bus and push change signals to browser clients, and browsers re-fetch per-project data from a standard API layer. There is no database, no external services, and no auth layer. All complexity concentrates in the watcher-to-SSE bridge and in parsing `.planning/` files correctly.

The critical architectural decision is the SSE signal-only pattern: SSE events carry only `{ type, projectId }`, not full project data. The browser re-fetches `/api/projects/[id]` on receiving a signal. This keeps the SSE channel lightweight, avoids serialization complexity, and ensures git data (which is async) is always fresh.

**Major components:**
1. **WatcherService** (`lib/watcher.ts`) — chokidar singleton stored on `globalThis`; emits normalized change events to EventBus
2. **EventBus** (`lib/event-bus.ts`) — in-memory EventEmitter with `setMaxListeners(50)`; fan-out to N SSE subscribers
3. **SSE Route Handler** (`app/api/sse/route.ts`) — holds open HTTP connections; subscribes to EventBus; cleanup wired to `request.signal`
4. **Scanner** (`lib/scanner.ts`) — walks `code/` and `project research/`; classifies project type
5. **Parser** (`lib/parser.ts`) — parses `STATE.md`, `ROADMAP.md`, `PROJECT.md`; all calls wrapped in try/catch
6. **GitReader** (`lib/git-reader.ts`) — `Promise.allSettled` + 5s timeout; non-fatal failures; single instance per repo
7. **Projects API** (`app/api/projects/route.ts`) — snapshot endpoint; Scanner + Parser + GitReader in parallel
8. **SSEListener Client Component** (`components/sse-listener.tsx`) — manages EventSource lifecycle; cleanup on unmount
9. **ProjectCard Client Component** (`components/project-card.tsx`) — renders single project; re-fetches on SSE signal
10. **ToolsReader** (`lib/tools-reader.ts`) — reads `~/.claude/` for Skills, MCP servers, Plugins

**Build order from architecture research:** Foundation → Scanner/Parser/GitReader → API Layer → Static Dashboard UI → SSE (live updates) → Claude Tools → Quick Actions. This order ensures data shape is validated before building UI, and live updates are added onto a working static dashboard.

See full architecture research: `.planning/research/ARCHITECTURE.md`

### Critical Pitfalls

1. **chokidar/simple-git not in `serverExternalPackages`** — Add `serverExternalPackages: ['chokidar', 'simple-git', 'fsevents']` to `next.config.ts` on day zero. Without this, fsevents binary fails, chokidar silently polls at 100% CPU, and the watcher never fires reliably.

2. **Chokidar singleton on module scope (not `globalThis`)** — Module scope can be reset by HMR in dev mode; `globalThis.__chokidarWatcher` persists across re-evaluations. Without this guard, each HMR cycle leaks file descriptors until the process crashes with `EMFILE: too many open files`.

3. **SSE Route Handler missing `request.signal` cleanup** — Wire `request.signal.addEventListener('abort', cleanupFn)` in every SSE route. Without it, zombie streams accumulate per tab navigation, eventually triggering `MaxListenersExceededWarning` and degraded event delivery.

4. **Missing `export const dynamic = 'force-dynamic'` on SSE route** — Next.js may statically cache the route. Dashboard appears to work in dev but is silently broken in production (client connects with HTTP 200 but receives no live events).

5. **Markdown parsing without try/catch** — chokidar fires `change` before the file is fully written to disk. A half-written `STATE.md` will throw a parse error. If that error propagates to the SSE stream controller, it kills the event pipeline for all connected clients. Every `parseMarkdownSafe()` call must return `null` on error, never throw.

6. **Tailwind v4 utility class name changes** — `shadow-sm` → `shadow-xs`, `ring` → `ring-3`, `outline-none` → `outline-hidden`, `bg-opacity-*` removed. shadcn/ui components may use v3 class names. Run `npx @tailwindcss/upgrade` before any component work; audit all shadcn components after `npx shadcn@latest add`.

7. **Concurrent simple-git calls on rapid file changes** — Debounce chokidar events (300-500ms) before triggering git operations. Use one `SimpleGit` instance per repository. Without this, bulk git operations (checkout, rebase) fire 50+ concurrent `git status` spawns, causing `.git/index.lock` contention errors.

See full pitfalls research: `.planning/research/PITFALLS.md`

---

## Implications for Roadmap

Based on the dependency graph established in architecture research and the pitfall phase warnings, the natural build sequence is 7 phases:

### Phase 1: Foundation + Configuration
**Rationale:** Several critical pitfalls must be configured before writing a single line of feature code — `serverExternalPackages`, Tailwind v4 setup, and dark mode CSS variables. Getting these wrong requires rewrites. Architecture also establishes `lib/types.ts` as the first file with no dependencies.
**Delivers:** Working Next.js project with correct config, Tailwind v4 + shadcn/ui initialized, shared TypeScript types defined, dark mode CSS in place
**Addresses:** Auto-discovery groundwork, dark mode (table stakes)
**Avoids:** Pitfalls 1 (bundling), 7 (Tailwind v4 class names), PITFALL.md Minor Pitfall 3 (params as Promise)
**Research flag:** Standard patterns — skip research-phase

### Phase 2: Data Layer — Scanner, Parser, Git Reader
**Rationale:** These are pure Node.js modules with no Next.js or UI dependency. They can be built and tested in isolation (via `ts-node` or Jest) before wiring into any route. Validating data shape here prevents UI rebuilds later. Architecture research explicitly calls this Phase 2.
**Delivers:** Working `scanner.ts` (project discovery + type classification), `parser.ts` (STATE.md/ROADMAP.md/PROJECT.md extraction), `git-reader.ts` (parallel git calls with timeout + singleton-per-repo)
**Uses:** chokidar 3.6.0, simple-git 3.x, gray-matter 4.0.3
**Avoids:** Pitfalls 5 (git concurrency), 6 (markdown mid-save), Moderate Pitfall 4 (non-git directory guard)
**Research flag:** Standard patterns — skip research-phase

### Phase 3: API Layer — Projects Snapshot
**Rationale:** Build the `/api/projects` and `/api/projects/[id]` Route Handlers using Phase 2 modules before building any UI. Verify data shape via `curl` before any component work. The static API is the MVP's backbone.
**Delivers:** `GET /api/projects` returning all project cards, `GET /api/projects/[id]` for per-project refresh
**Implements:** Projects Route Handler component from architecture
**Avoids:** Pitfall 4 (force-dynamic — not needed yet but establish the pattern)
**Research flag:** Standard patterns — skip research-phase

### Phase 4: Static Dashboard UI
**Rationale:** Build a fully functional read-only dashboard without live updates. This proves core value before adding SSE complexity. Architecture research explicitly recommends this ordering: "Works without live updates — this is the MVP." Once this is shippable, every subsequent phase is an enhancement.
**Delivers:** Server Component dashboard (`app/page.tsx`), `ProjectCard` component, `ProjectGrid` layout, both card types (code + research), quick actions (Terminal, Finder, Notion)
**Addresses:** Project card grid, GSD phase display, next step, git activity, dual card types, quick actions, Notion URL discovery — all table stakes and most differentiators
**Uses:** shadcn/ui Card/Badge/Button/Tooltip, Tailwind v4, lucide-react
**Avoids:** Pitfall 7 (Tailwind v4 class name audit after each `shadcn add`)
**Research flag:** Standard patterns — skip research-phase

### Phase 5: Live Updates — Watcher + SSE
**Rationale:** SSE is built on top of a working static dashboard. The `/api/projects/[id]` endpoint already exists from Phase 3 — SSE just signals the browser to call it. This ordering means each SSE event has a known, tested refresh target. Architecture research calls this dependency out explicitly.
**Delivers:** `lib/event-bus.ts`, `lib/watcher.ts` (chokidar singleton on `globalThis`), `instrumentation.ts`, `/api/sse/route.ts`, `hooks/use-sse.ts`, `components/sse-listener.tsx` — dashboard updates in real time when any `.planning/` file changes
**Avoids:** Pitfalls 2 (globalThis singleton), 3 (AbortSignal cleanup), 4 (force-dynamic), Moderate Pitfall 1 (React Strict Mode double-connection), Moderate Pitfall 3 (Turbopack HMR loop), Minor Pitfall 4 (heartbeat ping)
**Research flag:** Phase likely needs careful implementation review — most pitfalls cluster here. Well-documented patterns, but multiple interacting concerns (HMR, cleanup, Strict Mode). No research-phase needed; pitfalls are already documented.

### Phase 6: Claude Tools Inventory
**Rationale:** Self-contained feature with no dependency on the watcher or SSE. `~/.claude/` directory is static (changes rarely) — no live updates needed. Can be built independently after the core dashboard is working. Architecture research assigns this its own phase.
**Delivers:** `lib/tools-reader.ts`, `/api/tools/route.ts`, `app/tools/page.tsx`, `components/tools-panel.tsx` — Skills, MCP servers, and Plugins displayed in a dedicated page
**Addresses:** Claude Tools inventory differentiator, MCP server/plugin type tagging
**Research flag:** May benefit from `/gsd:research-phase` if `~/.claude/` directory structure is more complex than anticipated. File format for MCP configs is not deeply documented in existing research.

### Phase 7: Polish + Edge Cases
**Rationale:** Phase progress bar (checkbox counting), client-side name filter, error states, loading skeletons, and any UX improvements after the full feature set is wired together. These are low-risk, no-dependency enhancements.
**Delivers:** Phase progress indicator, card loading states, graceful error display for git failures, client-side filter by project name
**Addresses:** Phase progress indicator (differentiator), responsive reflow polish
**Research flag:** Standard patterns — skip research-phase

### Phase Ordering Rationale

- Scanner/Parser/GitReader before API because data shape validation prevents UI rewrites
- Static UI before SSE because a working dashboard validates the architecture before adding the most pitfall-dense feature
- SSE depends on the `[id]` API endpoint (Phase 3) — you cannot signal a re-fetch before the fetch target exists
- Claude Tools is self-contained with no watcher dependency — correct to isolate it
- Quick actions are embedded in Phase 4 (not a separate phase) because they are low-complexity and tied to the card component

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 6 (Claude Tools):** The `~/.claude/` directory structure for MCP servers and plugins may vary by installation method and version. If the inventory reader needs to handle multiple config formats, a brief research-phase is warranted before implementation.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** Next.js + Tailwind v4 + shadcn/ui init is fully documented and pitfalls are pre-empted in this research
- **Phase 2 (Data Layer):** gray-matter, simple-git, and directory scanning are well-documented libraries with established patterns
- **Phase 3 (API Layer):** Next.js Route Handlers are well-documented; data shape comes from Phase 2
- **Phase 4 (Static UI):** shadcn/ui component patterns are well-documented; Tailwind v4 pitfalls are pre-empted
- **Phase 5 (SSE):** All critical patterns are documented in ARCHITECTURE.md and PITFALLS.md; no unknown territory
- **Phase 7 (Polish):** Standard UI work with no novel dependencies

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions confirmed from installed `node_modules` on this machine; Next.js 16.1.6 verified from 4 active projects; only simple-git version is MEDIUM (no local install found, but 3.x line stable since 2023) |
| Features | MEDIUM | Derived from PROJECT.md (HIGH) + developer tooling domain knowledge (MEDIUM — training data); web search unavailable in research session; feature scope is owner-defined so domain comparison matters less |
| Architecture | HIGH | All patterns verified against Next.js 16.1.6 official docs; SSE via ReadableStream is Web Streams API standard; chokidar singleton is established Node.js pattern; confidence degraded only by MEDIUM on `globalThis` HMR behavior |
| Pitfalls | HIGH (critical) / MEDIUM (moderate) | Critical pitfalls verified against official Next.js docs and Tailwind v4 upgrade guide; chokidar/simple-git specifics are ecosystem knowledge from training data |

**Overall confidence:** HIGH

### Gaps to Address

- **simple-git exact version:** No local install confirmed. Use `npm install simple-git@latest` and pin the 3.x line. Verify `serverExternalPackages` includes it before first use.
- **`~/.claude/` directory structure:** MCP server and plugin config formats may differ by Claude installation method. Inspect the actual directory before building `tools-reader.ts` — take 10 minutes to read the config files rather than assuming structure.
- **chokidar v4 ESM concern:** The v3 recommendation is based on known Next.js + ESM-only package friction, not directly tested with Next.js 16. If chokidar v3 has any incompatibility discovered during Phase 5, the fallback is to use `serverExternalPackages` more aggressively and test v4 with explicit ESM config.
- **Tailwind v4 + shadcn/ui compatibility:** As of early 2026, shadcn/ui's `npx shadcn@latest init` generates v4-compatible output, but individual component source may still carry v3 class names. Run the audit after each `npx shadcn@latest add` rather than at the end.
- **Feature confidence caveat:** The features list is based on project spec and domain inference, not user research. The owner IS the user, so this is lower risk than a multi-user product, but revisit if requirements evolve during planning.

---

## Sources

### Primary (HIGH confidence)
- Next.js 16.1.6 official docs — instrumentation, Route Handlers, serverExternalPackages, SSE streaming, Turbopack, reactStrictMode: https://nextjs.org
- Tailwind CSS v4 upgrade guide — breaking changes, class name changes: https://tailwindcss.com/docs/upgrade-guide
- Next.js self-hosting guide — X-Accel-Buffering for SSE through proxies
- Project spec: `/Users/rob/project_orchestration/.planning/PROJECT.md`
- Installed packages verified: chokidar 3.6.0, Tailwind 4.1.18, React 19.2.4, TypeScript 5.9.3, Next.js 16.1.6, lucide-react 0.563.0, gray-matter 4.0.3, clsx 2.1.1, tailwind-merge 3.4.0, zod 4.3.6

### Secondary (MEDIUM confidence)
- Developer tooling ecosystem — Portainer, LinearB, Backstage, Raycast comparisons (training data, 2025 cutoff)
- chokidar v4 ESM friction with Next.js — ecosystem knowledge, not directly tested
- simple-git concurrency / git index.lock behavior — ecosystem knowledge
- Markdown mid-save write risks — ecosystem knowledge

### Tertiary (LOW confidence)
- `~/.claude/` directory format for MCP servers/plugins — inferred from project context; needs direct inspection before Phase 6 implementation

---
*Research completed: 2026-02-17*
*Ready for roadmap: yes*
