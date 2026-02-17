---
phase: 02-data-layer
plan: 02
subsystem: data
tags: [git, simple-git, server-only, timeout]

requires:
  - phase: 01-foundation
    provides: "Next.js project scaffold with TypeScript and types.ts"
provides:
  - "getGitData() function for per-project git commit data"
  - "GitFields type (Pick<CodeProject, lastCommitMessage | lastCommitTimestamp | lastCommitSha>)"
affects: [02-03, 03-api-layer]

tech-stack:
  added: [vitest]
  patterns: [server-only-guard, graceful-error-swallow, absolute-timeout]

key-files:
  created:
    - pro-orc/lib/git-reader.ts
    - pro-orc/lib/__tests__/git-reader.test.ts
    - pro-orc/vitest.config.ts
  modified:
    - pro-orc/package.json

key-decisions:
  - "simpleGit constructor inside try-catch — constructor throws synchronously for nonexistent paths"
  - "Vitest with node environment and @/ alias for testing server-only modules"

patterns-established:
  - "server-only guard: import 'server-only' at top of server modules"
  - "graceful error swallow: return empty object on expected failures (non-git dirs, timeouts)"
  - "absolute timeout: block:5000 with stdOut:false, stdErr:false prevents hung git processes"

requirements-completed: [GIT-01, GIT-02, GIT-04, GIT-05]

duration: 3min
completed: 2026-02-17
---

# Phase 02 Plan 02: Git Reader Summary

**Per-project git log reader using simple-git with 5s absolute timeout, returning lastCommitMessage/Timestamp/Sha with graceful fallback to empty object**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-17T12:22:45Z
- **Completed:** 2026-02-17T12:25:54Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- getGitData() retrieves last commit message, timestamp, and short SHA for any git project directory
- Graceful handling of non-git directories, nonexistent paths, and timeout errors (all return empty object)
- simpleGit configured with 5000ms absolute timeout (stdOut:false, stdErr:false) to prevent hung git processes
- Comprehensive unit tests covering real git repos, temp dirs, and nonexistent paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Create git reader with timeout and graceful error handling** - `d16f032` (feat)
2. **Task 2: Write unit tests including real git repos and non-git dirs** - `b2e4dc6` (test)

## Files Created/Modified
- `pro-orc/lib/git-reader.ts` - Git data reader with getGitData() and GitFields type
- `pro-orc/lib/__tests__/git-reader.test.ts` - Unit tests for all git reader scenarios
- `pro-orc/vitest.config.ts` - Vitest configuration with @/ alias resolution
- `pro-orc/package.json` - Added vitest dependency and test script

## Decisions Made
- Moved simpleGit() constructor call inside try-catch block because it throws synchronously for nonexistent paths (discovered during testing)
- Used vitest with node environment for testing server-only modules (mocking server-only import)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] simpleGit constructor throws synchronously for nonexistent paths**
- **Found during:** Task 2 (unit tests)
- **Issue:** `simpleGit({ baseDir: '/nonexistent' })` throws "Cannot use simple-git on a directory that does not exist" before any async operation, bypassing the try-catch around git.log()
- **Fix:** Moved simpleGit constructor inside the try block so both sync and async errors are caught
- **Files modified:** pro-orc/lib/git-reader.ts
- **Verification:** All 4 unit tests pass, including nonexistent path test
- **Committed in:** b2e4dc6 (Task 2 commit)

**2. [Rule 3 - Blocking] Vitest test infrastructure setup**
- **Found during:** Pre-task setup
- **Issue:** No test runner configured — vitest not installed, no vitest.config.ts, no test script
- **Fix:** Installed vitest, created vitest.config.ts with @/ alias, added "test" script (note: vitest and test script were already present from 02-01)
- **Files modified:** pro-orc/vitest.config.ts (new)
- **Verification:** npm test runs successfully
- **Committed in:** d16f032 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
- Manual verification command from plan (`npx tsx -e ...`) fails because `server-only` module requires Next.js runtime. Unit tests mock this correctly. Not a code issue.
- Pre-existing parser.test.ts failures (2 integration tests) from plan 02-01 — logged to deferred-items.md, not caused by this plan's changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Git reader ready for integration into project scanner (02-03)
- GitFields type exported for use in API responses
- Test infrastructure (vitest) available for all future plans

---
*Phase: 02-data-layer*
*Completed: 2026-02-17*
