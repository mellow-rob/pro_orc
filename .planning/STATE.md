# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-24)

**Core value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.
**Current focus:** v1.3 Project Creator — Phase 15: Project Creation

## Current Position

Phase: 15 of 16 (Project Creation)
Plan: 2 of 2 complete
Status: Complete
Last activity: 2026-02-26 — Completed 15-02: Dialog service wiring + post-creation actions

Progress: [████░░░░░░░░░░░░░░░░] 33% (v1.3 requirements)

## Performance Metrics

**v1.0 Velocity:**
- Total plans completed: 12
- Average duration: ~2 min/plan

**v1.1 Velocity:**
- Total plans completed: 18
- Average duration: ~6 min/plan

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 06    | 01   | 14 min   | 2     | 40    |
| 06    | 02   | 7 min    | 2     | 6     |
| 06    | 03   | ~15 min  | 2     | 0     |
| 07    | 01   | 2 min    | 2     | 9     |
| 07    | 02   | 3 min    | 3     | 2     |
| 07    | 03   | 6 min    | 3     | 4     |
| 07    | 04   | 3 min    | 3     | 2     |
| 08    | 01   | 7 min    | 2     | 4     |
| 08    | 02   | 3 min    | 2     | 5     |
| 09    | 01   | ~3 min   | 2     | 4     |
| 09    | 02   | ~20 min  | 3     | 6     |
| 10    | 01   | 4 min    | 2     | 10    |
| 10    | 02   | 3 min    | 2     | 5     |
| 10    | 03   | 4 min    | 2     | 4     |
| 10    | 04   | ~2 min   | 1     | 0     |
| 11    | 01   | 3 min    | 2     | 3     |
| 11    | 02   | 2 min    | 2     | 6     |
| 12    | 01   | ~1 min   | 2     | 3     |
| 12    | 02   | ~2 min   | 2     | 3     |
| 13    | 01   | 3 min    | 2     | 4     |
| 14    | 01   | 2 min    | 2     | 3     |
| 14    | 02   | 2 min    | 2     | 3     |
| 15    | 01   | 3 min    | 2     | 2     |

## Accumulated Context

### Decisions

Full decision log in PROJECT.md Key Decisions table.
v1.0 decisions archived to milestones/v1.0-ROADMAP.md.
v1.1 decisions archived to milestones/v1.1-ROADMAP.md.
v1.2 decisions archived to milestones/v1.2-ROADMAP.md.

**14-02 decisions:**
- CreateProjectDialog uses AnimatedSwitcher keyed on tab index for toggle group transitions
- Dialog glassmorphism: Dialog(transparent) + ClipRRect + BackdropFilter + Container(bgSurf) — same pattern as GlassCard
- activeThumbColor/activeTrackColor on SwitchListTile.adaptive (not deprecated activeColor)
- _isLoading kept mutable (not final) for Phase 15 create button spinner
- Add card: only "+" icon, no label text (cleaner minimal look, per visual verification)
- Toggle switch size reduced via FittedBox + fixed section height prevents dialog resize on tab switch
- [Phase 15]: ProjectCreatorService warnings-not-failures: only directory creation fails; git/file write errors are warnings
- [Phase 15]: Dialog keeps ProjectCreatorService import out until Phase 15-02 wiring to avoid unused import warning
- [Phase 15-02]: Post-creation actions (Terminal, rem-sleep) execute in tab context, not dialog — dialog pops with action flags
- [Phase 15-02]: New projects get DB projectType entry to bypass _inferType heuristic for empty directories
- [Phase 15-02]: osascript without runInShell for reliable Terminal command execution
- [Phase 15-02]: TabController listener tracks previousTabIndex to prevent toggle reset on unrelated setState

### Pending Todos

- Update ~/.zshrc to add `/opt/homebrew/share/flutter/bin` to PATH (or symlink to expected `/Users/rob/code/flutter`)
- Fix pre-existing withOpacity() in launch_dialog.dart:12 (deferred from 09-01)

### Blockers/Concerns

- Notion-Integration via Claude MCP — kein eigener API Key, Claude erstellt Notion-Seite per Prompt

## Session Continuity

Last session: 2026-02-26
Stopped at: Phase 15 complete — all plans executed and verified
Resume file: .planning/ROADMAP.md
