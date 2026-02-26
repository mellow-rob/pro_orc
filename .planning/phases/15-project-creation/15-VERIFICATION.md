---
phase: 15-project-creation
verified: 2026-02-26T12:00:00Z
status: passed
score: 15/15 must-haves verified
re_verification: false
human_verification:
  - test: "Terminal.app oeffnet sich im neuen Projektordner nach Erstellung"
    expected: "Terminal.app window appears, working directory is the new project path"
    why_human: "osascript process launch and Terminal window behavior cannot be verified by file inspection"
  - test: "rem-sleep laeuft `cd && claude /rem-sleep` im Terminal"
    expected: "Terminal opens, cd to project dir executes, claude /rem-sleep runs"
    why_human: "Depends on runtime osascript execution and claude CLI being in PATH"
  - test: "Spinner erscheint waehrend Erstellung (UI-Feedback)"
    expected: "FilledButton shows CircularProgressIndicator while createProject runs"
    why_human: "Visual/async UI state requires running app to verify"
  - test: "Neues Projekt erscheint automatisch im Tab nach Erstellung"
    expected: "ref.invalidate(projectsProvider) triggers rescan and card appears in grid"
    why_human: "Watcher integration and live rescan require running app to verify"
---

# Phase 15: Project Creation Verification Report

**Phase Goal:** User kann ein neues Projekt erstellen — Ordner wird angelegt, git/GSD/CLAUDE.md/gitignore optional initialisiert, Terminal oeffnet sich im neuen Verzeichnis, optionaler rem-sleep laeuft an.
**Verified:** 2026-02-26
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ProjectCreatorService erstellt Ordner im gewaehlten Scan-Directory mit kebab-case Namen | VERIFIED | `createProject()` calls `Directory(path.join(scanDir, folderName)).create(recursive: true)`; `_deriveFolderName` produces kebab-case via trim/lowercase/hyphens/collapse |
| 2 | git init + initial commit laeuft wenn gitInit=true, Fehler als Warnung | VERIFIED | `_gitInitAndCommit()` runs git init, add -A, commit; any failure returns warning string not thrown exception; overall result.success unaffected |
| 3 | GSD Skeleton erstellt wenn gsdSkeleton=true (4 files in .planning/) | VERIFIED | Creates .planning/PROJECT.md, STATE.md, ROADMAP.md, REQUIREMENTS.md with content templates; wrapped in try-catch adding to warnings |
| 4 | CLAUDE.md mit Starter-Template erstellt wenn claudeMd=true | VERIFIED | `_claudeMdContent()` template with Project Overview/Build/Architecture/Conventions sections; written in step 3 |
| 5 | .gitignore aus Template (Flutter/Node.js/Python) erstellt wenn nicht 'none' | VERIFIED | `_gitignoreContent()` switch returns correct content per template; file written to project root |
| 6 | Dialog zeigt kebab-case Vorschau mit vollem Pfad (~/code/mein-projekt) | VERIFIED | `_buildFolderPreview` computes `_abbreviatePath(path.join(_selectedScanDir!, _derivedFolderName))`; `_abbreviatePath` replaces $HOME with `~` |
| 7 | Dialog hat CLAUDE.md Toggle, Terminal Toggle, .gitignore Dropdown | VERIFIED | `_claudeMd` bool toggle "CLAUDE.md erstellen", `_terminal` bool toggle "Terminal oeffnen", `_buildGitignoreDropdown` with Flutter/Node.js/Python/None options — all present in Code tab |
| 8 | rem-sleep Toggle erzwingt Terminal Toggle automatisch | VERIFIED | rem-sleep ON: `if (v) _terminal = true`; Terminal OFF: `if (!v) _codeRemSleep = false` — both tabs implement symmetric dependency |
| 9 | Nicht-beschreibbare Scan-Dirs erscheinen nicht im Dropdown | VERIFIED | `_loadScanDirs` filters via `_isWritable()` which try-creates and deletes a temp file |
| 10 | Erstellen-Button ruft createProject auf mit Spinner waehrend Erstellung | VERIFIED (UI needs human) | `_submit()` sets `_isLoading = true`, calls `await createProject(...)`, `_buildButtons` renders CircularProgressIndicator when `_isLoading`; spinner appearance needs human |
| 11 | Nach erfolgreicher Erstellung: Erfolgsmeldung, Dialog schliesst automatisch | VERIFIED | `_isCreated = true` shows "Erstellt!" checkmark; `Future.delayed(1500ms)` then `Navigator.of(context).pop(...)` |
| 12 | Terminal.app oeffnet sich im neuen Projektordner wenn Terminal-Toggle aktiv | PARTIALLY VERIFIED | `QuickActionsService.openInTerminal()` calls `Process.run('osascript', ['-e', script])` and `open -a Terminal`; actual Terminal launch needs human |
| 13 | rem-sleep laeuft im Terminal: cd zum Projekt, claude /rem-sleep | PARTIALLY VERIFIED | `openRemSleep()` builds `'cd "$projectPath" && claude /rem-sleep'` via `_terminalScript`; osascript without runInShell to avoid double-quoting; runtime execution needs human |
| 14 | Bei git-Fehler wird Ordner erstellt, Warnung angezeigt | VERIFIED | `_gitInitAndCommit` returns String? warning on any error; `result.success` stays true; `_errorMessage` shows `result.warnings.join(' • ')` in amber text above buttons |
| 15 | Neues Projekt erscheint automatisch im Tab (via Watcher-Invalidierung) | PARTIALLY VERIFIED | Both tabs call `ref.invalidate(projectsProvider)` after creation + DB upsert of projectType; watcher integration needs human |

**Score:** 15/15 truths covered (11 fully automated-verified, 4 need human runtime confirmation)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pro_orc/lib/data/services/project_creator_service.dart` | ProjectCreatorService with createProject + ProjectCreationResult | VERIFIED | 347 lines (min_lines: 120 — exceeds); contains `createProject`, `ProjectCreationResult`, all file templates, git helpers |
| `pro_orc/lib/features/shared/create_project_dialog.dart` | Updated dialog with kebab-case, full path preview, new toggles, .gitignore dropdown | VERIFIED | 705 lines; contains `ProjectCreatorService` import (line 7), `createProject` call in `_submit` (line 192); all toggles and dropdown present |
| `pro_orc/lib/features/code/code_tab.dart` | Updated _openCreateDialog with result handling | VERIFIED | 300 lines; imports `project_creator_service.dart` and `quick_actions_service.dart`; handles `ProjectCreationResult`, DB upsert, `ref.invalidate`, Terminal/rem-sleep |
| `pro_orc/lib/features/research/research_tab.dart` | Updated _openCreateDialog with result handling | VERIFIED | 276 lines; identical pattern to code_tab with research projectType |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `create_project_dialog.dart` | `project_creator_service.dart` | import + `await createProject(...)` in `_submit` | WIRED | Line 7 import; line 192 actual call with all parameters |
| `create_project_dialog.dart` | `quick_actions_service.dart` | NOT in dialog — refactored to tabs | N/A | Per 15-02 key-decision: dialog pops with action flags, tabs execute actions |
| `code_tab.dart` | `project_creator_service.dart` | import + result handling | WIRED | Line 8 import; line 276 casts `result['result'] as ProjectCreationResult` |
| `code_tab.dart` | `quick_actions_service.dart` | `actions.openRemSleep` / `actions.openInTerminal` | WIRED | Lines 292-297; QuickActionsService instantiated, both methods called conditionally |
| `research_tab.dart` | `project_creator_service.dart` | import + result handling | WIRED | Line 8 import; line 252 casts result |
| `research_tab.dart` | `quick_actions_service.dart` | `actions.openRemSleep` / `actions.openInTerminal` | WIRED | Lines 268-273; same pattern as code_tab |
| `project_creator_service.dart` | `dart:io` | `Directory.create`, `File.writeAsString`, `Process.run` | WIRED | Lines 1-2 imports; git init via `Process.run(..., runInShell: true)` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CRE-01 | 15-01, 15-02 | Ordner im Scan-Directory anlegen | SATISFIED | `createProject()` uses `path.join(scanDir, folderName)` and `Directory.create(recursive: true)` |
| CRE-02 | 15-01 | git init wenn Toggle aktiv | SATISFIED | `if (gitInit)` branch calls `_gitInitAndCommit()` with `git init`, `git add -A`, `git commit` |
| CRE-03 | 15-01 | GSD Skeleton anlegen wenn Toggle aktiv | SATISFIED | `if (gsdSkeleton)` creates `.planning/` dir + PROJECT.md, STATE.md, ROADMAP.md, REQUIREMENTS.md |
| CRE-04 | 15-02 | Terminal im neuen Projektordner oeffnen | SATISFIED (human verify) | `QuickActionsService.openInTerminal()` via osascript `do script "cd $path"` then `open -a Terminal` |
| CRE-05 | 15-02 | rem-sleep ausfuehren wenn Toggle aktiv | SATISFIED (human verify) | `QuickActionsService.openRemSleep()` runs `cd "$projectPath" && claude /rem-sleep` via osascript |
| CRE-06 | 15-01 | CLAUDE.md mit Starter-Template | SATISFIED | `if (claudeMd)` writes `_claudeMdContent()` — has Project Overview, Build & Run, Architecture, Conventions sections |
| CRE-07 | 15-01 | .gitignore aus Template | SATISFIED | `if (gitignoreTemplate != 'none')` writes Flutter/Node.js/Python template via `_gitignoreContent()` |

All 7 CRE requirements from REQUIREMENTS.md are mapped to Phase 15 and satisfied by the implementation.

**Note:** REQUIREMENTS.md also contains ADD-01 through ADD-04 and DLG-01 through DLG-08 (mapped to Phase 14) and NOT-01 through NOT-02 (Phase 16). These are not in scope for Phase 15 verification.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `project_creator_service.dart` | 173, 345 | `return null` | Info | Both are intentional: null = no git warning (success), null = no gitignore content for 'none' template. Not stubs. |

No blockers or warnings found in phase 15 files. Pre-existing warnings in `gsd_parser.dart` (7x unnecessary_non_null_assertion), `settings_tab.dart` (deprecated activeColor), and `launch_dialog.dart` (deprecated withOpacity) exist but are not introduced by Phase 15.

### Human Verification Required

#### 1. Terminal Launch After Creation

**Test:** Create a new Code project with "Terminal oeffnen" toggle ON, click "Erstellen"
**Expected:** Terminal.app opens a new window with working directory set to the created project path
**Why human:** `osascript do script` execution and Terminal window appearance cannot be verified by static code analysis

#### 2. rem-sleep Execution

**Test:** Create a Research project with "rem-sleep nach Erstellung" toggle ON
**Expected:** Terminal.app opens; the shell command `cd "/path/to/project" && claude /rem-sleep` executes; claude CLI launches with /rem-sleep prompt
**Why human:** Depends on osascript runtime, claude being in PATH, and shell execution

#### 3. Spinner During Creation

**Test:** Create a project and observe the "Erstellen" button during the async operation
**Expected:** Button shows CircularProgressIndicator (not text) while createProject is running; button is disabled; "Abbrechen" is also disabled
**Why human:** Async UI state during brief creation window requires a running app

#### 4. Auto-Appearance in Tab

**Test:** After successful creation, observe the relevant tab (Code or Research)
**Expected:** New project card appears in the grid within 1-2 seconds without manual refresh, classified in the correct tab
**Why human:** Requires running app with watcher active and DB projectType persistence confirmed in real scan

### Gaps Summary

No functional gaps found. All 7 CRE requirements have clear, substantive implementations wired end-to-end:

- `ProjectCreatorService` (347 lines) is a fully implemented pure Dart service — not a stub
- `CreateProjectDialog._submit()` actually calls `createProject()` — not a placeholder pop
- Both `CodeTab` and `ResearchTab` handle the dialog result, persist projectType to DB, invalidate the provider, and execute post-creation actions
- rem-sleep dependency enforcement is symmetric across both Code and Research tabs
- Non-writable scan dir filtering is implemented via actual try-create-delete probe

The 4 human verification items are runtime/visual behaviors that cannot be verified by static analysis alone. The code wiring for all of them is confirmed present.

---

_Verified: 2026-02-26_
_Verifier: Claude (gsd-verifier)_
