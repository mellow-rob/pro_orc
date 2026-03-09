---
phase: 25-open-source-polish
plan: 01
subsystem: repo-docs
tags: [license, contributing, readme, github-templates, repo-cleanup]
dependency_graph:
  requires: []
  provides: [mit-license, contributing-guide, github-templates, updated-readme]
  affects: [readme, repo-root]
tech_stack:
  added: []
  patterns: [github-forms-yaml]
key_files:
  created:
    - LICENSE
    - CONTRIBUTING.md
    - .github/ISSUE_TEMPLATE/bug_report.yml
    - .github/ISSUE_TEMPLATE/feature_request.yml
    - .github/pull_request_template.md
  modified:
    - README.md
    - pro_orc/lib/data/services/memory_reader.dart
    - pro_orc/README.md
decisions:
  - "MIT License with copyright 2026 mellow-rob"
  - "CONTRIBUTING.md in English for international community"
  - "GitHub Forms YAML format for issue templates (not markdown)"
  - "pro_orc/README.md replaced with link to root README"
metrics:
  duration: 416s
  completed: 2026-03-09
  tests_added: 0
  tests_total: 134
  loc_added: ~180
---

# Phase 25 Plan 01: Open Source Polish Summary

MIT license, CONTRIBUTING guide, GitHub issue/PR templates, README update with v2.0 features, and hardcoded path cleanup for public release readiness.

## Tasks Completed

| Task | Name | Status | Key Files |
|------|------|--------|-----------|
| 1 | LICENSE and CONTRIBUTING.md | Done | LICENSE, CONTRIBUTING.md |
| 2 | GitHub Issue and PR Templates | Done | bug_report.yml, feature_request.yml, pull_request_template.md |
| 3 | README Update and Repo Cleanup | Done | README.md, memory_reader.dart, pro_orc/README.md |

## Implementation Details

### LICENSE
- Standard MIT License text, year 2026, copyright holder mellow-rob
- Placed in repo root

### CONTRIBUTING.md
- Written in English for international community
- Sections: Prerequisites, Development Setup, Running Tests, Code Style, PR Process, Reporting Issues, Architecture Overview
- References CLAUDE.md for detailed conventions

### GitHub Templates
- Bug report (YAML/Forms): description, steps to reproduce, expected/actual behavior, macOS version, Pro Orc version
- Feature request (YAML/Forms): description, use case, proposed solution, alternatives
- PR template (Markdown): description, changes list, checklist (flutter test, flutter analyze, conventions)

### README Updates
- Added 3 new features: Claude-Button, Onboarding wizard, Skill/Plugin browser
- Updated Quick actions line to mention Claude-Button as primary action
- Updated Getting Started to mention first-launch setup wizard
- Replaced "Private project" license with MIT link

### Repo Cleanup
- Removed hardcoded `/Users/rob` from memory_reader.dart comments (replaced with generic `$HOME` / `~/`)
- Replaced Flutter boilerplate in pro_orc/README.md with link to root README

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

- `flutter test`: 134 tests passed (0 new, no regressions)
- `flutter analyze`: No issues found
- Hardcoded path check: 0 occurrences of `/Users/rob` in pro_orc/lib/ (excluding .g.dart)
- All created files verified on disk
- README contains MIT, Claude-Button, and Onboarding references

## Success Criteria

- [x] OSS-01: README erklaert Features (inkl. v2.0), enthaelt Installationsanleitung und Quick-Start
- [x] OSS-02: LICENSE (MIT) und CONTRIBUTING.md liegen im Repo-Root
- [x] OSS-03: Keine hardcoded /Users/rob im Source Code
- [x] OSS-04: GitHub Issue Templates und PR Template sind konfiguriert
- [x] Alle Tests weiterhin gruen, Analyzer sauber

## Self-Check: PASSED

All 5 created files and 3 modified files verified on disk. 134 tests passing, 0 analyzer issues. README content verified for MIT and v2.0 features.
