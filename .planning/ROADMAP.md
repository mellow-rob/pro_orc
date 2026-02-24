# Roadmap: Pro Orc — Project Orchestration Dashboard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-02-19)
- ✅ **v1.1 Flutter macOS Rewrite** — Phases 6-11 (shipped 2026-02-23)
- ✅ **v1.2 Memory Indicator** — Phases 12-13 (shipped 2026-02-24)
- 🚧 **v1.3 Project Creator** — Phases 14-17 (in progress)

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

### 🚧 v1.3 Project Creator (In Progress)

**Milestone Goal:** Neue Projekte direkt aus Pro Orc erstellen — Add+ Karte, Erstellungs-Dialog, Filesystem-Scaffolding, Notion API Integration.

- [ ] **Phase 14: Notion Settings** - Notion API Key + Parent Page in Settings tab, verschluesselt gespeichert in Drift DB
- [ ] **Phase 15: Add Card + Dialog** - Add+ Karte in Code- und Research-Grid, Erstellungs-Dialog mit Tab-Switcher und allen Toggles/Feldern
- [ ] **Phase 16: Project Creation** - Filesystem-Operationen: Ordner, git init, GSD skeleton, CLAUDE.md, .gitignore, Terminal, rem-sleep
- [ ] **Phase 17: Notion Integration** - Notion-Seite via API erstellen, URL als Kommentar in PROJECT.md schreiben

## Phase Details

### Phase 14: Notion Settings
**Goal**: User kann Notion API Key und Parent Page ID in Settings speichern — Voraussetzung fuer Research-Projekt-Erstellung mit Notion.
**Depends on**: Phase 13
**Requirements**: NOT-01, NOT-02
**Success Criteria** (what must be TRUE):
  1. Settings-Tab zeigt zwei neue Felder: Notion API Key (verschleiert) und Notion Parent Page ID
  2. Eingegebene Werte werden nach App-Neustart korrekt geladen (Drift DB Persistenz)
  3. API Key wird als verschluesselter Wert gespeichert, nicht als Klartext in der DB sichtbar
**Plans**: 1 plan

Plans:
- [ ] 14-01-PLAN.md — Drift DB schema v3 + encryption helper + Notion settings UI

### Phase 15: Add Card + Dialog
**Goal**: User sieht Add+ Karte im Code- und Research-Grid und kann daraus einen Erstellungs-Dialog oeffnen, der alle Optionen fuer den neuen Projekttyp zeigt.
**Depends on**: Phase 14
**Requirements**: ADD-01, ADD-02, ADD-03, ADD-04, DLG-01, DLG-02, DLG-03, DLG-04, DLG-05, DLG-06, DLG-07, DLG-08
**Success Criteria** (what must be TRUE):
  1. Add+ Karte erscheint als letzte Karte in Code-Tab und Research-Tab (nach allen Projekt-Karten)
  2. Klick auf Add+ im Code-Tab oeffnet Dialog mit vorausgewaehltem Code-Tab; Klick im Research-Tab oeffnet Dialog mit Research-Tab
  3. Dialog zeigt Namensfeld plus alle Code-spezifischen Toggles (git init, GSD skeleton, CLAUDE.md, .gitignore Dropdown) wenn Code-Tab aktiv
  4. Dialog zeigt Namensfeld plus alle Research-spezifischen Optionen (Notion-Seite, Terminal, rem-sleep) wenn Research-Tab aktiv
  5. Tab-Switcher innerhalb des Dialogs wechselt zwischen Code- und Research-Optionen ohne Dialog zu schliessen
**Plans**: TBD

Plans:
- [ ] 15-01: AddProjectCard Widget
- [ ] 15-02: CreateProjectDialog Widget

### Phase 16: Project Creation
**Goal**: User kann ein neues Projekt erstellen — Ordner wird angelegt, git/GSD/CLAUDE.md/gitignore optional initialisiert, Terminal oeffnet sich im neuen Verzeichnis, optionaler rem-sleep laeuft an.
**Depends on**: Phase 15
**Requirements**: CRE-01, CRE-02, CRE-03, CRE-04, CRE-05, CRE-06, CRE-07
**Success Criteria** (what must be TRUE):
  1. Neuer Projektordner erscheint nach Erstellung automatisch im entsprechenden Tab (via Watcher-Invalidierung)
  2. git init, .planning/PROJECT.md, CLAUDE.md und .gitignore werden nur erstellt wenn der jeweilige Toggle aktiv war
  3. Terminal.app oeffnet sich im neuen Projektordner wenn Terminal-Toggle aktiv
  4. rem-sleep laeuft im neuen Projektordner via osascript wenn rem-sleep-Toggle aktiv
**Plans**: TBD

Plans:
- [ ] 16-01: ProjectCreatorService (Filesystem + git + file scaffolding)
- [ ] 16-02: Dialog wired to service + post-creation actions

### Phase 17: Notion Integration
**Goal**: Research-Projekte koennen automatisch eine Notion-Seite bei Erstellung anlegen lassen, und die Notion-URL wird in PROJECT.md des neuen Projekts gespeichert.
**Depends on**: Phase 16
**Requirements**: NOT-03, NOT-04
**Success Criteria** (what must be TRUE):
  1. Nach Erstellung eines Research-Projekts mit aktivem Notion-Toggle existiert eine neue Seite im konfigurierten Notion Workspace
  2. Die neue Seite traegt den Projektnamen als Titel
  3. PROJECT.md des neuen Projekts enthaelt `<!-- notion: URL -->` Kommentar mit der Notion-URL der erstellten Seite
  4. Fehler bei der Notion API (kein Key, ungueltige ID, Netzwerkfehler) zeigen eine verstaendliche Fehlermeldung im Dialog ohne den Erstellungsprozess abzubrechen
**Plans**: TBD

Plans:
- [ ] 17-01: NotionService + Integration in ProjectCreatorService

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
| 14. Notion Settings | v1.3 | 0/TBD | Not started | - |
| 15. Add Card + Dialog | v1.3 | 0/TBD | Not started | - |
| 16. Project Creation | v1.3 | 0/TBD | Not started | - |
| 17. Notion Integration | v1.3 | 0/TBD | Not started | - |
