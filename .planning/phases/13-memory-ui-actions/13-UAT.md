---
status: testing
phase: 13-memory-ui-actions
source: [13-01-SUMMARY.md]
started: 2026-02-24T09:00:00Z
updated: 2026-02-24T09:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: Memory indicator on Code cards
expected: |
  In the Code tab, each project card shows a small book icon (bookMarked) in the title row, between the version/name text and the eye icon. Projects with Claude memory directories show a colored icon; projects without show a gray icon.
awaiting: user response

## Tests

### 1. Memory indicator on Code cards
expected: In the Code tab, each project card shows a small book icon (bookMarked) in the title row. Projects with Claude memory show a colored icon; projects without show a gray icon.
result: [pending]

### 2. Memory indicator on Research cards
expected: In the Research tab, each project card shows the same book icon in the title row. Colored when memory exists, gray when not.
result: [pending]

### 3. Visual states — fresh vs stale vs none
expected: Projects with recent memory (< 7 days) show violet/purple icon. Projects with old memory (> 7 days) show amber/orange icon. Projects without memory show dim gray icon.
result: [pending]

### 4. German tooltip on hover
expected: Hovering over the book icon shows a tooltip. With memory: "Letzte Konsolidierung: DD.MM.YYYY" (date formatted). Without memory: "Keine Memory vorhanden".
result: [pending]

### 5. MoonStar quick action button
expected: On cards that have memory data, a moon/star icon appears in the quick actions row. Cards without memory do NOT show this action.
result: [pending]

### 6. MoonStar opens Terminal
expected: Clicking the moonStar quick action opens Terminal.app at the project's directory path.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0

## Gaps

[none yet]
