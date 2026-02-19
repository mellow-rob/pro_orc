---
phase: 04-live-updates
verified: 2026-02-17T00:00:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
human_verification:
  - test: "Edit a .planning/STATE.md file while the dashboard is open in a browser"
    expected: "The affected project card updates within ~1 second without page reload"
    why_human: "End-to-end SSE delivery and DOM re-render cannot be verified statically"
  - test: "Open the browser DevTools Network tab and reload the dashboard"
    expected: "Exactly one /api/events EventSource connection appears — not one per card"
    why_human: "Connection count requires runtime observation in browser devtools"
  - test: "Close the browser tab and reopen it"
    expected: "The old SSE connection closes (no zombie), exactly one new connection opens"
    why_human: "Cleanup lifecycle requires runtime observation"
  - test: "Save a .planning/STATE.md file 5 times in 1 second"
    expected: "Only one card update occurs (debounce is working)"
    why_human: "Debounce timing requires live observation"
---

# Phase 04: Live Updates Verification Report

**Phase Goal:** The dashboard updates in real time when any `.planning/` file changes — no page reload required — using a chokidar singleton watcher and SSE push
**Verified:** 2026-02-17
**Status:** PASSED (with human verification recommended for runtime behavior)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                      | Status     | Evidence                                                                                        |
|----|--------------------------------------------------------------------------------------------|------------|-------------------------------------------------------------------------------------------------|
| 1  | Chokidar watcher initializes once at server startup and survives HMR re-execution          | VERIFIED   | `globalThis.__watcher` guard at `watcher.ts:37`; Set/Map guards at lines 26 and 30             |
| 2  | SSE endpoint at `/api/events` streams events to connected clients                          | VERIFIED   | `app/api/events/route.ts` exports `GET` with `ReadableStream`, initial ping, subscriber fan-out |
| 3  | File changes in `.planning/` directories produce debounced SSE events                      | VERIFIED   | `watcher.ts:49` filters `.planning` paths; 300ms `setTimeout` debounce at lines 62-80          |
| 4  | GET `/api/projects/[id]` returns fresh JSON for a single project                           | VERIFIED   | Route calls `scanProjectById`, returns `Response.json(project)` with `force-dynamic`           |
| 5  | `node_modules`, `.git`, and `.next` directories are excluded from watching                 | VERIFIED   | `watcher.ts:41` ignored array: `['**/node_modules/**', '**/.git/**', '**/.next/**']`           |
| 6  | Editing a `.planning/STATE.md` causes the corresponding card to update without page reload | VERIFIED   | Full circuit: watcher → debounce → SSE → `useProjectEvents` fetch → `liveData` Map → re-render |
| 7  | Opening and closing the browser tab produces exactly one SSE connection (no zombies)       | VERIFIED   | `useProjectEvents.ts:39-41` cleanup: `return () => source.close()` in `useEffect`              |
| 8  | One EventSource per dashboard mount, not per card                                          | VERIFIED   | `useProjectEvents` called once in `ProjectTabs` at line 58, not inside card components         |

**Score:** 8/8 truths verified

---

### Required Artifacts

| Artifact                                      | Expected                                              | Exists | Substantive | Wired  | Status     |
|-----------------------------------------------|-------------------------------------------------------|--------|-------------|--------|------------|
| `pro-orc/lib/watcher.ts`                      | Chokidar singleton, subscriber registry, debounce     | YES    | YES         | YES    | VERIFIED   |
| `pro-orc/instrumentation.ts`                  | Server startup bootstrap with Node.js runtime guard   | YES    | YES         | YES    | VERIFIED   |
| `pro-orc/app/api/events/route.ts`             | SSE route handler with ReadableStream                 | YES    | YES         | YES    | VERIFIED   |
| `pro-orc/app/api/projects/[id]/route.ts`      | Per-project data endpoint                             | YES    | YES         | YES    | VERIFIED   |
| `pro-orc/hooks/useProjectEvents.ts`           | Client-side SSE subscription hook                     | YES    | YES         | YES    | VERIFIED   |
| `pro-orc/components/projectTabs.tsx`          | Live data overlay merged with server-rendered props   | YES    | YES         | YES    | VERIFIED   |

**Supporting artifact verified:**

| Artifact                    | Function                                  | Status   |
|-----------------------------|-------------------------------------------|----------|
| `pro-orc/lib/scanner.ts`    | Exports `scanProjectById()` at line 96    | VERIFIED |

---

### Key Link Verification

**Plan 01 Key Links**

| From                           | To                                  | Via                                  | Pattern Found                                               | Status  |
|--------------------------------|-------------------------------------|--------------------------------------|-------------------------------------------------------------|---------|
| `instrumentation.ts`           | `lib/watcher.ts`                    | dynamic import in `register()`        | `await import('./lib/watcher')` at line 6                   | WIRED   |
| `lib/watcher.ts`               | `globalThis.__watcherSubscribers`   | subscriber Set export                 | `globalThis.__watcherSubscribers` at lines 18, 26, 75, 93  | WIRED   |
| `app/api/events/route.ts`      | `lib/watcher.ts`                    | imports `watcherSubscribers`          | `import { watcherSubscribers } from '@/lib/watcher'`        | WIRED   |
| `app/api/projects/[id]/route.ts` | `lib/scanner.ts`                  | calls `scanProjectById`               | `import { scanProjectById }` + call at line 15              | WIRED   |

**Plan 02 Key Links**

| From                               | To                          | Via                       | Pattern Found                                              | Status  |
|------------------------------------|-----------------------------|---------------------------|------------------------------------------------------------|---------|
| `hooks/useProjectEvents.ts`        | `/api/events`               | EventSource connection    | `new EventSource('/api/events')` at line 10                | WIRED   |
| `hooks/useProjectEvents.ts`        | `/api/projects/[id]`        | fetch on SSE event        | `fetch('/api/projects/' + projectId)` at line 27           | WIRED   |
| `components/projectTabs.tsx`       | `hooks/useProjectEvents.ts` | hook invocation           | `import { useProjectEvents }` + `useProjectEvents(handleUpdate)` at line 58 | WIRED   |

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                                   | Status    | Evidence                                                                   |
|-------------|-------------|-------------------------------------------------------------------------------|-----------|----------------------------------------------------------------------------|
| LIVE-01     | 04-01       | chokidar filesystem watcher monitors `.planning/` changes across all projects | SATISFIED | `watcher.ts` watches `PATHS.code` and `PATHS.research`; filters `.planning` paths |
| LIVE-02     | 04-01       | Watcher runs as singleton via `instrumentation.ts` on `globalThis`            | SATISFIED | `globalThis.__watcher` guard prevents re-initialization on HMR; `instrumentation.ts` bootstraps |
| LIVE-03     | 04-01       | Watcher excludes `node_modules/`, `.git/`, `.next/`                           | SATISFIED | `ignored: ['**/node_modules/**', '**/.git/**', '**/.next/**']` at `watcher.ts:41` |
| LIVE-04     | 04-01       | SSE push delivers change events via ReadableStream route handler               | SATISFIED | `app/api/events/route.ts` uses `ReadableStream` with subscriber fan-out    |
| LIVE-05     | 04-02       | Affected project card updates without full page reload                         | SATISFIED | `useProjectEvents` → `liveData` Map → `resolvedCode`/`resolvedResearch` merge in `projectTabs.tsx` |
| LIVE-06     | 04-01       | Watcher events are debounced (300ms)                                           | SATISFIED | `setTimeout(..., 300)` per-project at `watcher.ts:65`; `clearTimeout` on repeat fires |

All 6 requirements (LIVE-01 through LIVE-06) satisfied. No orphaned requirements.

---

### Anti-Patterns Found

| File                  | Line | Pattern                                              | Severity | Impact                                       |
|-----------------------|------|------------------------------------------------------|----------|----------------------------------------------|
| `lib/watcher.ts`      | 38   | `console.log('[watcher] Initializing...')`           | Info     | Intentional startup diagnostic, not a stub   |
| `lib/watcher.ts`      | 87   | `console.log('[watcher] Watching:', ...)`            | Info     | Intentional startup diagnostic, not a stub   |
| `hooks/useProjectEvents.ts` | 3 | `useCallback` imported but unused in hook body  | Warning  | Hook correctly documents caller must wrap; unused import may trigger ESLint lint error |

No blockers found. The two `console.log` calls are deliberate startup diagnostics. The unused `useCallback` import is a lint warning only — it does not affect runtime behavior.

---

### Human Verification Required

#### 1. End-to-End Card Update

**Test:** Run `npm run dev` in `pro-orc/`. Open `localhost:3000`. In a terminal, edit any `.planning/STATE.md` file under `~/project_orchestration/code/` (e.g., change the phase number and save).
**Expected:** The corresponding project card on the dashboard updates with the new data within approximately 1 second, without any page reload.
**Why human:** SSE delivery latency and DOM re-render cannot be verified by static code analysis.

#### 2. Single EventSource Connection Per Tab

**Test:** Open browser DevTools (Network tab, filter by "EventSource" or "event-stream"). Load `localhost:3000`.
**Expected:** Exactly one `/api/events` connection appears in the Network tab — not one per project card.
**Why human:** Connection count requires runtime observation in browser devtools.

#### 3. No Zombie Connections on Tab Close

**Test:** Note the active `/api/events` connection in DevTools. Close the browser tab (or navigate away). Reopen.
**Expected:** The previous connection closes (status changes), and exactly one new connection opens — no accumulation of zombie streams.
**Why human:** EventSource cleanup lifecycle (`source.close()`) must be observed at runtime.

#### 4. Debounce Suppresses Rapid Saves

**Test:** Save a `.planning/STATE.md` file 5 times within 1 second.
**Expected:** The project card updates only once, approximately 300ms after the last save.
**Why human:** Debounce timing and event consolidation require runtime observation.

---

### Infrastructure Notes

- **chokidar** is correctly listed in `package.json` dependencies (`^3.6.0`) and externalized in `next.config.ts` via `serverExternalPackages` — prevents fsevents native binary from being bundled and avoids 100% CPU polling fallback.
- **instrumentation.ts** does not require an explicit config flag in Next.js 15+; the file is auto-detected at the project root.
- **Commit hashes** from SUMMARY files verified present in git log: `8a6b4df` (watcher + instrumentation), `5a72888` (SSE route + scanner), `1bf8c76` (client hook + projectTabs).

---

### Gaps Summary

No gaps found. All 8 observable truths are verified, all 6 artifacts pass all three levels (exists, substantive, wired), all 7 key links are wired, and all 6 LIVE requirements are satisfied.

The live update circuit is complete: disk file change → chokidar detects it → `.planning/` filter passes → 300ms debounce fires → SSE event pushed to all subscribers → browser EventSource receives event → hook fetches `/api/projects/[id]` → `liveData` Map updated → React re-renders affected card.

Human verification of runtime behavior is recommended before declaring the phase production-ready, but no static code deficiencies were found.

---

_Verified: 2026-02-17_
_Verifier: Claude (gsd-verifier)_
