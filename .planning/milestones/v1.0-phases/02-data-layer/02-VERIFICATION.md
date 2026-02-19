---
phase: 02-data-layer
verified: 2026-02-17T13:37:00Z
status: gaps_found
score: 15/16 must-haves verified
re_verification: false
gaps:
  - truth: "TypeScript compilation passes with no type errors across all three modules"
    status: partial
    reason: "scanner.test.ts uses beforeAll as a vitest global but vitest/globals is not referenced in tsconfig.json compilerOptions.types, causing tsc --noEmit to report TS2304: Cannot find name 'beforeAll'. Vitest runs correctly at runtime (globals:true in vitest.config.ts), but the tsc check the plan requires fails."
    artifacts:
      - path: "pro-orc/lib/__tests__/scanner.test.ts"
        issue: "beforeAll used as global (line 13) but not imported from vitest; vitest/globals not in tsconfig types"
      - path: "pro-orc/tsconfig.json"
        issue: "Missing compilerOptions.types entry for vitest/globals to expose beforeAll, afterAll, etc."
    missing:
      - "Add 'vitest/globals' to tsconfig.json compilerOptions.types array so tsc resolves vitest global types"
      - "OR add 'beforeAll' to the vitest import on line 1 of scanner.test.ts: import { describe, it, expect, vi, beforeAll } from 'vitest'"
human_verification: []
---

# Phase 02: Data Layer Verification Report

**Phase Goal:** Scanner, Parser, and Git Reader modules that reliably read the filesystem and git history — tested in isolation so data shapes are validated before any route handler or UI component touches them
**Verified:** 2026-02-17T13:37:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Parser extracts currentPhase from STATE.md with multiple format variants | VERIFIED | parser.ts lines 38-53: 6 regex patterns (bold + plain, English + German). Tests pass for **Phase:**, **Current Phase:**, plain Phase: formats. |
| 2 | Parser extracts nextStep from STATE.md with multiple field name variants | VERIFIED | parser.ts lines 62-77: 6 patterns for Next Action, Next Step, Nächster Schritt (bold + plain). 3 tests cover variants. |
| 3 | Parser derives gsdStatus from STATE.md status field | VERIFIED | parser.ts lines 85-96: deriveStatus() maps complete/archived/paused/research/planning/progress/phase-N to typed GsdStatus. 8 status tests pass. |
| 4 | Parser counts completed vs total plan checkboxes from ROADMAP.md for phaseProgress | VERIFIED | parser.ts lines 104-110: case-insensitive [x] and [ ] regex, Math.round percentage. Tests cover 60%, 100%, [X] uppercase, no-checkbox cases. |
| 5 | Parser extracts notionUrl from HTML comment in PROJECT.md | VERIFIED | parser.ts lines 119-120: regex matches `<!-- notion: URL -->` including extra whitespace. 3 tests pass including whitespace variant. |
| 6 | Missing .planning/ directory returns empty object (no error) | VERIFIED | parser.ts lines 137-139: when all three reads return null, returns `{}`. Integration test against nonexistent path passes. |
| 7 | Malformed or empty files return partial data (no crash) | VERIFIED | Each internal parser function starts with `if (!content) return {}`. Test for partial data (only STATE.md present) passes. |
| 8 | Git reader returns lastCommitTimestamp, lastCommitMessage, lastCommitSha (7-char) | VERIFIED | git-reader.ts lines 23-27: extracts all three fields. Test asserts SHA length === 7. |
| 9 | Non-git directories return empty object (no error thrown) | VERIFIED | git-reader.ts lines 28-30: catch block returns `{}`. Test uses mkdtemp tempDir, asserts `{}`. |
| 10 | Git calls have a hard 5-second timeout (block:5000, stdOut:false, stdErr:false) | VERIFIED | git-reader.ts lines 12-16: `timeout: { block: 5000, stdOut: false, stdErr: false }`. simpleGit constructor inside try block. |
| 11 | Repos with no commits return empty object | VERIFIED | git-reader.ts line 21: `if (!log.latest) return {}`. |
| 12 | Scanner discovers all non-hidden subdirectories from code/ and research/ roots | VERIFIED | scanner.ts lines 27-29: `entry.isDirectory() && !entry.name.startsWith('.')`. Integration test asserts no name starts with '.'. |
| 13 | Projects from code/ have type 'code'; projects from research/ have type 'research' | VERIFIED | scanner.ts lines 65-68, 72-75: type literal assigned by scan root. Integration test asserts path contains `/code/` or `/project research/` per type. |
| 14 | Code projects include git data; research projects do not | VERIFIED | scanner.ts uses Promise.allSettled only for codeDirs; researchProjects mapped without git enrichment. 2 integration tests verify. |
| 15 | Git calls run concurrently via Promise.allSettled | VERIFIED | scanner.ts line 61: `await Promise.allSettled(codeDirs.map(p => getGitData(p.path)))`. |
| 16 | TypeScript compilation passes (tsc --noEmit) | FAILED | `tsc --noEmit` reports TS2304: Cannot find name 'beforeAll' in scanner.test.ts line 13. `vitest.config.ts` sets `globals: true` (runtime injection), but tsconfig.json does not include `vitest/globals` in compilerOptions.types. All 42 tests pass at runtime. |

**Score:** 15/16 truths verified

### Required Artifacts

| Artifact | Min Lines | Actual Lines | Status | Details |
|----------|-----------|--------------|--------|---------|
| `pro-orc/lib/parser.ts` | — | 147 | VERIFIED | Exports parseGsdData(), GsdParseResult interface. Imports planningDir and GsdStatus. Real implementation. |
| `pro-orc/lib/__tests__/parser.test.ts` | 80 | 432 | VERIFIED | 30 tests across parseState, parseRoadmap, parseProject, integration, and edge cases. |
| `pro-orc/lib/git-reader.ts` | — | 31 | VERIFIED | Exports getGitData(), GitFields type. simpleGit with absolute timeout. Constructor inside try block. |
| `pro-orc/lib/__tests__/git-reader.test.ts` | 50 | 59 | VERIFIED | 4 tests: real git repo, temp dir, nonexistent path, type-level test. |
| `pro-orc/lib/scanner.ts` | — | 79 | VERIFIED | Exports scanProjects(). Orchestrates parser + git-reader. Promise.allSettled. Missing-root catch(). |
| `pro-orc/lib/__tests__/scanner.test.ts` | 60 | 102 | VERIFIED | 8 integration tests against real filesystem. All pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `parser.ts` | `paths.ts` | planningDir() import | WIRED | Line 5: `import { planningDir } from '@/lib/paths'` — called at line 128 |
| `parser.ts` | `types.ts` | GsdStatus type import | WIRED | Line 6: `import type { GsdStatus } from '@/lib/types'` — used in deriveStatus return type |
| `git-reader.ts` | `simple-git` | simpleGit with timeout | WIRED | Line 3: import; lines 10-17: constructor with block:5000, stdOut:false, stdErr:false inside try block |
| `git-reader.ts` | `types.ts` | CodeProject type | WIRED | Line 4: `import type { CodeProject } from '@/lib/types'` — used in GitFields Pick<> |
| `scanner.ts` | `parser.ts` | parseGsdData import | WIRED | Line 7: `import { parseGsdData } from '@/lib/parser'` — called at line 36 |
| `scanner.ts` | `git-reader.ts` | getGitData import | WIRED | Line 8: `import { getGitData } from '@/lib/git-reader'` — called at line 62 |
| `scanner.ts` | `paths.ts` | PATHS constants | WIRED | Line 5: `import { PATHS, projectIdFromPath } from '@/lib/paths'` — PATHS.code and PATHS.research used at lines 56-57 |
| `scanner.ts` | `types.ts` | Project union type | WIRED | Line 6: `import type { Project, CodeProject, ResearchProject } from '@/lib/types'` — all three used |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| SCAN-01 | 02-03 | Auto-scans `~/project_orchestration/code/` | SATISFIED | scanner.ts: `PATHS.code` from paths.ts; scanDir called with it |
| SCAN-02 | 02-03 | Auto-scans `~/project_orchestration/project research/` | SATISFIED | scanner.ts: `PATHS.research`; `path.join(BASE, 'project research')` in paths.ts |
| SCAN-03 | 02-03 | Automatically detects project type (code vs research) | SATISFIED | scanner.ts: type assigned as `'code' as const` or `'research' as const` by scan root |
| SCAN-04 | 02-01 | Parses `.planning/STATE.md` for current phase and next step | SATISFIED | parser.ts: parseState() extracts currentPhase, nextStep via 6 pattern variants each |
| SCAN-05 | 02-01 | Parses `.planning/ROADMAP.md` for phase structure and progress | SATISFIED | parser.ts: parseRoadmap() counts [x] vs [ ] checkboxes, returns phaseProgress 0-100 |
| SCAN-06 | 02-01 | Parses `.planning/PROJECT.md` for project name and Notion URL | SATISFIED | parser.ts: parseProject() extracts notionUrl from `<!-- notion: URL -->` comment |
| SCAN-07 | 02-01 | Handles missing `.planning/` gracefully (no crash) | SATISFIED | parser.ts lines 137-139: all-null returns `{}`. Test for nonexistent path passes. |
| SCAN-08 | 02-01 | Handles malformed or mid-save files gracefully (no crash) | SATISFIED | readFile() returns null on any error; all parse functions guard `if (!content) return {}` |
| GIT-01 | 02-02 | Shows last commit timestamp per project (async, non-blocking) | SATISFIED | git-reader.ts: `lastCommitTimestamp: log.latest.date` returned |
| GIT-02 | 02-02 | Shows last commit message per project | SATISFIED | git-reader.ts: `lastCommitMessage: log.latest.message` returned |
| GIT-03 | 02-03 | Git calls run concurrently via Promise.allSettled | SATISFIED | scanner.ts line 61: `await Promise.allSettled(codeDirs.map(p => getGitData(p.path)))` |
| GIT-04 | 02-02 | Git calls have explicit 5s timeout | SATISFIED | git-reader.ts: `timeout: { block: 5000, stdOut: false, stdErr: false }` — absolute timeout (not reset on I/O) |
| GIT-05 | 02-02 | Non-git directories handled gracefully | SATISFIED | git-reader.ts: catch block returns `{}` for non-git dirs and nonexistent paths |

All 13 Phase 2 requirements are satisfied. No orphaned requirements found. REQUIREMENTS.md traceability table maps exactly SCAN-01 through SCAN-08 and GIT-01 through GIT-05 to Phase 2.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scanner.test.ts` | 13 | `beforeAll` used without import; tsconfig missing `vitest/globals` | Warning | tsc --noEmit fails; tests pass at runtime. One-line fix. |
| `parser.ts` | 26 | `return null` | Info | Intentional: readFile() returns null on ENOENT/EACCES as part of defensive pattern. Not a stub. |
| `git-reader.ts` | 21, 29 | `return {}` | Info | Intentional: empty object returned for no-commits and error conditions as per spec. Not a stub. |

No blocker anti-patterns in the implementation files. No TODO/FIXME/placeholder comments. No console.log-only implementations.

### Human Verification Required

None — all phase 2 behaviors are deterministic filesystem and parsing operations that are fully verifiable programmatically through the test suite.

### Gaps Summary

One gap blocks full passing status:

**TypeScript type check failure:** `scanner.test.ts` uses `beforeAll` as a vitest global (via `globals: true` in vitest.config.ts) but does not import it explicitly. The `tsconfig.json` does not include `vitest/globals` in `compilerOptions.types`, so `tsc --noEmit` cannot resolve the global declaration and reports TS2304. This is a configuration inconsistency — vitest injects the globals at runtime correctly (all 42 tests pass), but TypeScript's static checker is unaware of them.

**Fix options (either resolves the issue):**

Option A — Fix the import in scanner.test.ts (line 1):
```typescript
import { describe, it, expect, vi, beforeAll } from 'vitest'
```

Option B — Add vitest globals to tsconfig.json compilerOptions:
```json
"types": ["vitest/globals"]
```

The three implementation files (`parser.ts`, `git-reader.ts`, `scanner.ts`) are fully correct, substantive, and wired. The data layer goal is achieved functionally. The gap is a test infrastructure type configuration issue.

---

_Verified: 2026-02-17T13:37:00Z_
_Verifier: Claude (gsd-verifier)_
