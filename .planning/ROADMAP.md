# Roadmap: Pro Orc — Project Orchestration Dashboard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-02-19)
- ✅ **v1.1 Flutter macOS Rewrite** — Phases 6-11 (shipped 2026-02-23)
- ✅ **v1.2 Memory Indicator** — Phases 12-13 (shipped 2026-02-24)
- ✅ **v1.3 Project Creator** — Phases 14-16 (shipped 2026-02-26)
- 🚧 **v1.4 Projekt-Loeschfunktion** — Phases 17-18 (in progress)

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

### 🚧 v1.4 Projekt-Loeschfunktion (In Progress)

**Milestone Goal:** Projekte komplett vom Filesystem loeschen mit Bestaetigungsdialog und optionalem Cleanup externer Ressourcen.

- [ ] **Phase 17: Deletion Core** - Rechtsklick-Eintrag, Bestaetigungsdialog mit Name-Eingabe, rm -rf und Auto-Refresh
- [ ] **Phase 18: External Resource Cleanup** - Erkennung und schrittweise Abfrage externer Ressourcen (Notion, GitHub, Figma, Claude Memory)

## Phase Details

### Phase 17: Deletion Core
**Goal**: User kann ein Projekt sicher und permanent vom Filesystem loeschen
**Depends on**: Phase 16
**Requirements**: DEL-01, DEL-02, DEL-03, DEL-04, DEL-05
**Success Criteria** (what must be TRUE):
  1. User sieht "Projekt loeschen" im Rechtsklick-Kontextmenue auf Code-Cards und Research-Cards
  2. Nach Klick oeffnet ein Dialog, der den Projektnamen als Freitext-Eingabe erfordert bevor der Loeschbutton aktiv wird
  3. Nur wenn der eingetippte Name exakt mit dem Projektnamen uebereinstimmt, wird der Loeschbutton freigeschaltet
  4. Nach Bestaetigung wird der Projektordner permanent geloescht (kein Papierkorb) und das Dashboard aktualisiert sich automatisch ohne manuelles Reload
**Plans**: 2 plans

Plans:
- [ ] 17-01-PLAN.md — Deletion service + context menu entry on Code- and Research-Cards
- [ ] 17-02-PLAN.md — Confirmation dialog with GitHub-style name input and provider invalidation

### Phase 18: External Resource Cleanup
**Goal**: Dialog erkennt verlinkte externe Ressourcen und fragt schrittweise ob diese ebenfalls geloescht werden sollen
**Depends on**: Phase 17
**Requirements**: CLN-01, CLN-02, CLN-03, CLN-04, CLN-05
**Success Criteria** (what must be TRUE):
  1. Dialog erkennt Notion-Link aus `<!-- notion: URL -->` in PROJECT.md und zeigt eine Ja/Nein-Abfrage an
  2. Dialog erkennt GitHub Remote aus `git remote -v` und zeigt eine Ja/Nein-Abfrage fuer das Repo-Loeschen an
  3. Dialog erkennt Figma-Links und andere externe Ressourcen-URLs aus Projektdateien und zeigt sie einzeln an
  4. Dialog erkennt Claude Memory unter `~/.claude/projects/` und MCP-erstellte Daten (Firebase, Vercel, etc.) und fragt einzeln nach
  5. Jede erkannte externe Ressource wird als eigenstaendiger Schritt mit separatem Ja/Nein angezeigt — keine Ressource wird ohne explizite Bestaetigung geloescht
**Plans**: TBD

Plans:
- [ ] 18-01: Resource detection service (Notion, GitHub, Figma, Claude Memory, other URLs)
- [ ] 18-02: Step-by-step cleanup UI wired into deletion dialog

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
| 17. Deletion Core | v1.4 | 0/2 | Not started | - |
| 18. External Resource Cleanup | v1.4 | 0/2 | Not started | - |
