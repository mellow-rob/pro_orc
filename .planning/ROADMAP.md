# Roadmap: Pro Orc — Project Orchestration Dashboard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-02-19)
- ✅ **v1.1 Flutter macOS Rewrite** — Phases 6-11 (shipped 2026-02-23)
- 🚧 **v1.2 Memory Indicator** — Phases 12-13 (in progress)

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

### v1.2 Memory Indicator

**Milestone Goal:** Auf jeder Project Card anzeigen ob rem-sleep Memory-Konsolidierung gelaufen ist, mit schlafendem Buch-Icon und Quick Action zum Triggern.

- [x] **Phase 12: Memory Detection** - Pure Dart Service erkennt Memory-Status pro Projekt via Dateisystem (completed 2026-02-24)
- [ ] **Phase 13: Memory UI + Actions** - Sleeping-Book-Icon auf Cards mit Stale-Indikator, Tooltip und Quick Action

## Phase Details

### Phase 12: Memory Detection
**Goal**: ProjectScanner liefert Memory-Konsolidierungsstatus pro Projekt als Teil des ProjectModel
**Depends on**: Phase 11 (existing data layer and ProjectScanner)
**Requirements**: MEM-01, MEM-02, MEM-03
**Success Criteria** (what must be TRUE):
  1. ProjectModel enthaelt Memory-Status (vorhanden/nicht vorhanden) und letztes Konsolidierungsdatum
  2. Pfad-Encoding wandelt beliebige Projektpfade korrekt ins Claude-Projektverzeichnis-Format um (Slashes werden Dashes)
  3. Unit Tests mit echten Temp-Verzeichnissen validieren Erkennung, Pfad-Encoding und fehlende Memory-Datei
**Plans:** 2/2 plans complete
Plans:
- [ ] 12-01-PLAN.md — TDD: MemoryData model + MemoryReader service (path encoding, detection, mtime)
- [ ] 12-02-PLAN.md — Wire MemoryReader into ProjectScanner + ProjectModel

### Phase 13: Memory UI + Actions
**Goal**: User sieht auf jeder Project Card den Memory-Status und kann rem-sleep direkt triggern
**Depends on**: Phase 12
**Requirements**: MUI-01, MUI-02, MUI-03, MACT-01
**Success Criteria** (what must be TRUE):
  1. Sleeping-Book-Icon erscheint auf Code- und Research-Cards und zeigt ob Memory vorhanden ist
  2. Icon wechselt visuell den Zustand wenn Memory aelter als 7 Tage ist (stale)
  3. Tooltip auf dem Icon zeigt "Letzte Konsolidierung: [Datum]" oder "Keine Memory vorhanden"
  4. Quick Action oeffnet Terminal mit `claude` im Projektverzeichnis zum rem-sleep Triggern
**Plans**: TBD

## Progress

**Execution Order:** 12 → 13

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
| 12. Memory Detection | v1.2 | Complete    | 2026-02-24 | - |
| 13. Memory UI + Actions | v1.2 | 0/? | Not started | - |
