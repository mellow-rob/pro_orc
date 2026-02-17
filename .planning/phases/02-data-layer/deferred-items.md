# Deferred Items - Phase 02 Data Layer

## Pre-existing Test Failures

- **parser.test.ts** (from 02-01): Two integration tests fail — `parses real .planning/ directory without crashing` and `extracts gsdStatus as a known value from real STATE.md`. These test against the live STATE.md which now has "Phase complete" status format that the parser doesn't map. Not caused by 02-02 changes.
