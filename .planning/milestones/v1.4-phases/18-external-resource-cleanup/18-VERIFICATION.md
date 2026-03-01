---
phase: 18-external-resource-cleanup
verified: 2026-02-27T14:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 18: External Resource Cleanup Verification Report

**Phase Goal:** Dialog erkennt verlinkte externe Ressourcen und fragt schrittweise ob diese ebenfalls geloescht werden sollen
**Verified:** 2026-02-27T14:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Dialog erkennt Notion-Link aus `<!-- notion: URL -->` in PROJECT.md und zeigt eine Ja/Nein-Abfrage an | VERIFIED | `resource_detector.dart:27` reads `project.gsd?.notionUrl`; GsdData.notionUrl exists at `gsd_data.dart:8`; rendered as checkbox row in `_buildResources()` |
| 2 | Dialog erkennt GitHub Remote aus `git remote -v` und zeigt eine Ja/Nein-Abfrage fuer das Repo-Loeschen an | VERIFIED | `resource_detector.dart:41` reads `project.git?.githubUrl`; GitData.githubUrl exists at `git_data.dart:5`; rendered as checkbox row in `_buildResources()` |
| 3 | Dialog erkennt Figma-Links und andere externe Ressourcen-URLs aus Projektdateien und zeigt sie einzeln an | VERIFIED | `resource_detector.dart:71` calls `_scanMdFilesForUrls()` which regex-scans .md files up to 2 levels deep; classifies figma.com, firebase, vercel, and generic domains; rendered individually in resource list |
| 4 | Dialog erkennt Claude Memory unter `~/.claude/projects/` und MCP-erstellte Daten (Firebase, Vercel, etc.) und fragt einzeln nach | VERIFIED | `resource_detector.dart:54` uses `encodeProjectPath()` from memory_reader to check `~/.claude/projects/{encodedPath}` existence; Firebase/Vercel classified via URL scan |
| 5 | Jede erkannte externe Ressource wird als eigenstaendiger Schritt mit separatem Ja/Nein angezeigt — keine Ressource wird ohne explizite Bestaetigung geloescht | VERIFIED | `_buildResources()` renders per-resource Checkbox widgets; `_selectedResources` Set defaults empty (all unchecked); `_onDelete` never calls any external deletion API — informational only |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `pro_orc/lib/data/models/external_resource.dart` | ExternalResource model with ExternalResourceType enum (5 types) | VERIFIED | 44 lines; enum with 5 values (notion, github, figma, claudeMemory, other); immutable const class with type, label, uri, hint |
| `pro_orc/lib/data/services/resource_detector.dart` | detectExternalResources() top-level async function | VERIFIED | 179 lines; top-level function accepting ProjectModel, returning Future<List<ExternalResource>>; covers all 4 CLN categories; separate try/catch per step |
| `pro_orc/lib/features/shared/delete_project_dialog.dart` | Extended DeleteProjectDialog with resource detection and step-by-step display | VERIFIED | 514 lines; imports ExternalResource and detectExternalResources; _loadResources() in initState; _buildResources() + _buildSummary() + _iconForType(); wired into both CodeProjectCard and ResearchProjectCard |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `resource_detector.dart` | `project_model.dart` | reads `project.gsd?.notionUrl` and `project.git?.githubUrl` | WIRED | Pattern `project\.gsd\?\.notionUrl` confirmed at line 27; `project.git?.githubUrl` at line 41 |
| `resource_detector.dart` | `memory_reader.dart` | calls `encodeProjectPath` for Claude Memory lookup | WIRED | `encodeProjectPath` imported and called at line 57 |
| `delete_project_dialog.dart` | `resource_detector.dart` | calls `detectExternalResources` in initState | WIRED | Imported at line 8; called in `_loadResources()` at line 56, invoked from `initState` at line 52 |
| `delete_project_dialog.dart` | `external_resource.dart` | imports ExternalResource and ExternalResourceType for rendering | WIRED | Imported at line 5; ExternalResourceType used in `_iconForType()` switch; ExternalResource used in `_buildResources()` and `_buildSummary()` |
| `delete_project_dialog.dart` | `code_project_card.dart` + `research_project_card.dart` | dialog called via showDialog in card quick actions | WIRED | Confirmed in both cards at lines 383 and 286 respectively |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CLN-01 | 18-01-PLAN.md, 18-02-PLAN.md | Dialog erkennt verlinkte Notion-Seite und fragt ob sie geloescht werden soll | SATISFIED | `resource_detector.dart:26-37` detects via `project.gsd?.notionUrl`; checkbox rendered in dialog |
| CLN-02 | 18-01-PLAN.md, 18-02-PLAN.md | Dialog erkennt GitHub Remote und fragt ob das Repo geloescht werden soll | SATISFIED | `resource_detector.dart:40-51` detects via `project.git?.githubUrl`; checkbox rendered in dialog |
| CLN-03 | 18-01-PLAN.md, 18-02-PLAN.md | Dialog erkennt Figma und andere externe Ressourcen-Links aus Projektdateien | SATISFIED | `_scanMdFilesForUrls()` scans .md files; `_classifyUrl()` handles figma.com, firebase, vercel, generic domains |
| CLN-04 | 18-01-PLAN.md, 18-02-PLAN.md | Dialog erkennt MCP-erstellte Daten (Claude Memory, Firebase, Vercel, etc.) und fragt schrittweise nach | SATISFIED | Claude Memory detection via `encodeProjectPath` at line 54-69; Firebase/Vercel via URL scan classification |
| CLN-05 | 18-02-PLAN.md | Alle erkannten Ressourcen werden schrittweise einzeln abgefragt (Ja/Nein pro Ressource) | SATISFIED | Per-resource Checkbox widgets; `_selectedResources` Set defaults empty (all unchecked by default); no external resource auto-deleted |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `delete_project_dialog.dart` | 82-86 | Summary shown regardless of `success` value when resources are selected | Warning | If deletion fails, user still sees a "Projekt geloescht" summary — misleading on error. Does not block the phase goal. |

---

### Human Verification Required

#### 1. Resource List Rendering in Live Dialog

**Test:** Open a project that has a Notion URL in PROJECT.md (e.g. `<!-- notion: https://notion.so/... -->`) and trigger the delete dialog via right-click menu.
**Expected:** The "Verknuepfte externe Ressourcen" section appears between the red warning box and the project name label, showing the Notion entry as an unchecked checkbox row with the truncated URL.
**Why human:** Visual layout, scroll behavior with multiple resources, and MacOS glassmorphism rendering cannot be verified programmatically.

#### 2. Post-Deletion Summary Screen

**Test:** Open the delete dialog for a project with at least one detected resource. Check the checkbox on one resource, type the project name, and click "Loeschen".
**Expected:** After deletion the dialog body is replaced with a summary showing "Projekt geloescht" with a green checkmark, then the resource label, full URI, and hint text for each checked resource. A "Schliessen" button closes the dialog.
**Why human:** Dialog state transition (form -> summary in-place) and the full URI display (not truncated) require visual confirmation.

#### 3. Zero-Resource Case Is Unchanged

**Test:** Open the delete dialog for a project with no Notion URL, no GitHub remote, no Claude Memory, and no external URLs in its .md files.
**Expected:** The dialog looks identical to the Phase 17 version — no "Verknuepfte externe Ressourcen" section, no empty state placeholder. Just warning box, project name, text field, and buttons.
**Why human:** Absence of a UI section requires visual confirmation that no stub/empty container is rendered.

---

### Gaps Summary

No gaps found. All five success criteria are satisfied at all three verification levels (exists, substantive, wired). All five CLN requirements are accounted for across both plans. The warning-level issue (summary shown on deletion failure when resources are selected) is a minor edge-case UX concern and does not block the phase goal.

---

_Verified: 2026-02-27T14:30:00Z_
_Verifier: Claude (gsd-verifier)_
