# Roadmap: Pro Orc — Project Orchestration Dashboard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-02-19)
- ✅ **v1.1 Flutter macOS Rewrite** — Phases 6-11 (shipped 2026-02-23)
- ✅ **v1.2 Memory Indicator** — Phases 12-13 (shipped 2026-02-24)
- ✅ **v1.3 Project Creator** — Phases 14-16 (shipped 2026-02-26)
- ✅ **v1.4 Projekt-Loeschfunktion** — Phases 17-18 (shipped 2026-03-01)
- ✅ **v1.5 Import & Detail-Panel** — Phases 19-20 (shipped 2026-03-05)
- 🚧 **v2.0 Open Source Public Release** — Phases 22-25 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-02-19</summary>

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-02-17
- [x] Phase 2: Data Layer (3/3 plans) — completed 2026-02-17
- [x] Phase 3: Static Dashboard (2/2 plans) — completed 2026-02-17
- [x] Phase 4: Live Updates (2/2 plans) — completed 2026-02-17
- [x] Phase 5: Claude Tools (2/2 plans) — completed 2026-02-17

See: milestones/v1.0-ROADMAP.md for full details

</details>

<details>
<summary>✅ v1.1 Flutter macOS Rewrite (Phases 6-11) — SHIPPED 2026-02-23</summary>

- [x] Phase 6: Native Foundation (3/3 plans) — completed 2026-02-19
- [x] Phase 7: Data Layer (4/4 plans) — completed 2026-02-19
- [x] Phase 8: Reactive State (2/2 plans) — completed 2026-02-19
- [x] Phase 9: Theme + UI Shell (2/2 plans) — completed 2026-02-22
- [x] Phase 10: Card Widgets + Quick Actions (4/4 plans) — completed 2026-02-23
- [x] Phase 11: Claude Tools Panel (3/3 plans) — completed 2026-02-23

See: milestones/v1.1-ROADMAP.md for full details

</details>

<details>
<summary>✅ v1.2 Memory Indicator (Phases 12-13) — SHIPPED 2026-02-24</summary>

- [x] Phase 12: Memory Detection (2/2 plans) — completed 2026-02-24
- [x] Phase 13: Memory UI + Actions (1/1 plan) — completed 2026-02-24

See: milestones/v1.2-ROADMAP.md for full details

</details>

<details>
<summary>✅ v1.3 Project Creator (Phases 14-16) — SHIPPED 2026-02-26</summary>

- [x] Phase 14: Add Card + Dialog (2/2 plans) — completed 2026-02-25
- [x] Phase 15: Project Creation (2/2 plans) — completed 2026-02-26
- [x] Phase 16: Notion via Claude (1/1 plan) — completed 2026-02-26

See: milestones/v1.3-ROADMAP.md for full details

</details>

<details>
<summary>✅ v1.4 Projekt-Loeschfunktion (Phases 17-18) — SHIPPED 2026-03-01</summary>

- [x] Phase 17: Deletion Core (2/2 plans) — completed 2026-02-27
- [x] Phase 18: External Resource Cleanup (2/2 plans) — completed 2026-02-27

See: milestones/v1.4-ROADMAP.md for full details

</details>

<details>
<summary>✅ v1.5 Import & Detail-Panel (Phases 19-20) — SHIPPED 2026-03-05</summary>

- [x] Phase 19: Detail-Panel Typography (1/1 plan) — completed 2026-03-05
- [x] Phase 20: Folder Import (2/2 plans) — completed 2026-03-05

~~Phase 21: Memory Tab~~ — gestrichen, Obsidian Vault ersetzt die Funktion.

See: milestones/v1.5-ROADMAP.md for full details

</details>

### v2.0 Open Source Public Release

**Milestone Goal:** Pro Orc als vollwertiges Open Source Produkt veroeffentlichen — mit Claude-Button als primaerer Action, erweitertem Tool-Browser (read-only), Onboarding fuer Erstbenutzer und professioneller Dokumentation.

**Execution Strategy:** Wave-basiert mit Parallelisierung (~60% parallel statt 100% sequentiell)

```
Wave 0 (30min):  Fix Tests + Analyzer + Hardcoded Paths
                  |
       ┌──────────┴──────────┐
Wave 1a: Phase 22 (1-2h)     | Wave 1b: Phase 23 (3-4h)
       (parallel, worktree)   | (parallel, worktree)
       └──────────┬──────────┘
                  |              Wave 3A: Phase 25 Legal (parallel mit Wave 1)
Wave 2 (3-4h):   Phase 24
                  |
Wave 3B (2-3h):  Phase 25 README + Screenshots (interaktiv)
```

- [ ] **Wave 0: Foundation Cleanup** - Fix failing tests, analyzer warnings, hardcoded /Users/rob paths
- [ ] **Phase 22: Claude-Button** - Prominenter Claude-Button als primaere Action auf allen Projektkarten
- [ ] **Phase 23: Skill/Plugin Browser Upgrade** - Read-only Pro-Projekt-Status, Quick Actions und Metadaten im Claude Tools Tab
- [ ] **Phase 24: Onboarding** - First-Run Wizard mit Claude Code Detection und Setup-Hilfe
- [ ] **Phase 25: Open Source Polish** - README, LICENSE, Contributing Guide, Repo-Audit und Release Templates

## Phase Details

### Wave 0: Foundation Cleanup (Prerequisite)
**Goal**: Sauberer Feedback-Loop fuer alle nachfolgenden Phasen
**Depends on**: Nothing
**Tasks**:
  1. Fix 2 failing tests (space encoding + truncation limit)
  2. Fix analyzer warnings (use_build_context_synchronously etc.)
  3. Replace hardcoded `/Users/rob` fallbacks with `Platform.environment['HOME']!`
**Done when**: `flutter test` = 0 failures, `flutter analyze` = 0 issues, kein `/Users/rob` in lib/

### Phase 22: Claude-Button
**Goal**: User startet Claude Code Sessions direkt von Projektkarten — ein Klick vom Dashboard ins Terminal
**Depends on**: Wave 0
**Parallel with**: Phase 23 (zero file overlap — Phase 22 touches project cards, Phase 23 touches Claude Tools tab)
**Requirements**: CLB-01, CLB-02, CLB-03
**Success Criteria** (what must be TRUE):
  1. User klickt den Claude-Button auf einer Projektkarte und eine Terminal-Session oeffnet sich mit `claude` im richtigen Projektverzeichnis
  2. Der Claude-Button ist visuell als primaere Action erkennbar (Cyan, prominente Position links)
  3. Terminal-Zugang bleibt ueber Kontextmenue oder sekundaere Action erreichbar — kein Funktionsverlust
**Plans:** 1 plan

Plans:
- [x] 22-01-PLAN.md — Claude-Button auf Projektkarten + Terminal ins Kontextmenue

### Phase 23: Skill/Plugin Browser Upgrade
**Goal**: User sieht auf einen Blick welche Skills und Plugins pro Projekt aktiv sind und kann sie direkt oeffnen
**Depends on**: Wave 0
**Parallel with**: Phase 22 (zero file overlap)
**Scope**: Read-only — keine settings.json Writes. Toggle-Writes deferred auf v2.1 (Race Condition Risiko mit laufenden Claude Sessions)
**Requirements**: SPB-01, SPB-02, SPB-03
**Success Criteria** (what must be TRUE):
  1. User sieht im Claude Tools Tab pro Projekt welche Skills und Plugins installiert/aktiv sind
  2. User kann per Quick Action ein Skill oder Plugin im Editor oeffnen oder dessen Dokumentation anzeigen
  3. Jedes Plugin zeigt Metadaten: Autor, Installationsdatum, letzte Aktualisierung
**Plans:** 2 plans

Plans:
- [ ] 23-01-PLAN.md — Data layer: Plugin-Metadaten + Per-Project Scanner
- [ ] 23-02-PLAN.md — UI: Projekt-Dropdown, Metadaten-Anzeige, Editor-Quick-Actions

### Phase 24: Onboarding
**Goal**: Erstbenutzer werden beim ersten Start durch Claude Code Detection und Ersteinrichtung gefuehrt
**Depends on**: Phase 22 + 23 (Onboarding referenziert Claude-Button und Browser Features)
**Requirements**: ONB-01, ONB-02, ONB-03
**Success Criteria** (what must be TRUE):
  1. Beim allerersten Start erkennt Pro Orc ob Claude Code CLI installiert ist und zeigt verstaendliche Setup-Hilfe falls nicht
  2. Der Setup-Wizard fuehrt durch: Claude Code Check, Scan-Verzeichnisse konfigurieren, ersten Projekt-Import
  3. Jeder Wizard-Schritt ist ueberspringbar und der gesamte Wizard kann spaeter ueber Settings erneut gestartet werden
  4. Erfahrene User mit existierender ~/.claude/ und konfigurierten Scan-Dirs werden nicht durch den Wizard belaestigt
**Plans**: TBD

### Phase 25: Open Source Polish
**Goal**: Pro Orc ist bereit fuer die oeffentliche GitHub-Veroeffentlichung mit professioneller Dokumentation und sauberem Repo
**Depends on**: Splitbar — Legal/Repo-Audit (25A) parallel mit Wave 1, README+Screenshots (25B) nach Phase 24
**Requirements**: OSS-01, OSS-02, OSS-03, OSS-04
**Sub-tasks**:
  - **25A (parallel mit Wave 1)**: LICENSE, CONTRIBUTING.md, Issue Templates, PR Template, .gitignore Audit, Secrets-Scan
  - **25B (nach Phase 24)**: README mit Screenshots, Feature-Beschreibung, Installationsanleitung, Quick-Start Guide
**Success Criteria** (what must be TRUE):
  1. GitHub README erklaert Features, zeigt Screenshots, enthaelt Installationsanleitung (Homebrew + DMG) und Quick-Start Guide
  2. LICENSE-Datei und CONTRIBUTING.md mit Build/Test/PR Conventions liegen im Repo-Root
  3. Keine hardcoded /Users/rob Pfade im Source Code, keine Secrets in der Git-History, .gitignore ist vollstaendig
  4. GitHub Issue Templates und Release Notes Template sind konfiguriert
  5. Ein neuer User kann Pro Orc allein anhand der README installieren und starten
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-02-17 |
| 2. Data Layer | v1.0 | 3/3 | Complete | 2026-02-17 |
| 3. Static Dashboard | v1.0 | 2/2 | Complete | 2026-02-17 |
| 4. Live Updates | v1.0 | 2/2 | Complete | 2026-02-17 |
| 5. Claude Tools | v1.0 | 2/2 | Complete | 2026-02-17 |
| 6. Native Foundation | v1.1 | 3/3 | Complete | 2026-02-19 |
| 7. Data Layer | v1.1 | 4/4 | Complete | 2026-02-19 |
| 8. Reactive State | v1.1 | 2/2 | Complete | 2026-02-19 |
| 9. Theme + UI Shell | v1.1 | 2/2 | Complete | 2026-02-22 |
| 10. Card Widgets + Quick Actions | v1.1 | 4/4 | Complete | 2026-02-23 |
| 11. Claude Tools Panel | v1.1 | 3/3 | Complete | 2026-02-23 |
| 12. Memory Detection | v1.2 | 2/2 | Complete | 2026-02-24 |
| 13. Memory UI + Actions | v1.2 | 1/1 | Complete | 2026-02-24 |
| 14. Add Card + Dialog | v1.3 | 2/2 | Complete | 2026-02-25 |
| 15. Project Creation | v1.3 | 2/2 | Complete | 2026-02-26 |
| 16. Notion via Claude | v1.3 | 1/1 | Complete | 2026-02-26 |
| 17. Deletion Core | v1.4 | 2/2 | Complete | 2026-02-27 |
| 18. External Resource Cleanup | v1.4 | 2/2 | Complete | 2026-02-27 |
| 19. Detail-Panel Typography | v1.5 | 1/1 | Complete | 2026-03-05 |
| 20. Folder Import | v1.5 | 2/2 | Complete | 2026-03-05 |
| ~~21. Memory Tab~~ | v1.5 | — | Gestrichen | — |
| 22. Claude-Button | v2.0 | 1/1 | Complete | 2026-03-09 |
| 23. Skill/Plugin Browser Upgrade | v2.0 | 0/2 | Not started | - |
| 24. Onboarding | v2.0 | 0/? | Not started | - |
| 25. Open Source Polish | v2.0 | 0/? | Not started | - |
