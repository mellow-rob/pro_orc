# Roadmap: Pro Orc — Project Orchestration Dashboard

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-02-19)
- ✅ **v1.1 Flutter macOS Rewrite** — Phases 6-11 (shipped 2026-02-23)
- ✅ **v1.2 Memory Indicator** — Phases 12-13 (shipped 2026-02-24)
- ✅ **v1.3 Project Creator** — Phases 14-16 (shipped 2026-02-26)
- ✅ **v1.4 Projekt-Loeschfunktion** — Phases 17-18 (shipped 2026-03-01)
- 🚧 **v1.5 Import, Detail-Panel & Memory-Tab** — Phases 19-21 (in progress)

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

### 🚧 v1.5 Import, Detail-Panel & Memory-Tab (In Progress)

**Milestone Goal:** Existierende Ordner importieren, Detail-Panel Lesbarkeit verbessern, und neuen Memory-Tab mit Uebersicht und Actions einfuehren.

- [ ] **Phase 19: Detail-Panel Typography** - Beschreibungstexte lesbar machen mit Zeilenhoehe, Selektierbarkeit, Kontrast und Expand/Collapse
- [ ] **Phase 20: Folder Import** - Existierende Ordner per macOS Folder Picker importieren mit Auto-Scaffold und Scan-Dir-Erweiterung
- [ ] **Phase 21: Memory Tab** - Neuer Tab mit Master-Detail Layout, Memory-Vorschau, Quick Actions und Enum-basierter Navigation

## Phase Details

### Phase 19: Detail-Panel Typography
**Goal**: User kann Beschreibungstexte im Detail-Panel komfortabel lesen, selektieren und bei langen Texten ein-/ausklappen
**Depends on**: Phase 18 (v1.4 complete)
**Requirements**: DPL-01, DPL-02, DPL-03, DPL-04
**Success Criteria** (what must be TRUE):
  1. Beschreibungstexte im Detail-Panel haben sichtbar erhoehten Zeilenabstand (1.6+) und sind deutlich lesbarer als vorher
  2. User kann beliebige Textpassagen in Beschreibungen mit der Maus markieren und per Cmd+C kopieren
  3. Beschreibungstexte sind auf dem dunklen Glasmorphism-Hintergrund kontrastreich lesbar (WCAG AA konform)
  4. Lange Beschreibungen (>5 Zeilen) werden abgeschnitten mit "Mehr anzeigen" Button angezeigt; Klick expandiert den vollen Text, "Weniger anzeigen" klappt wieder zu
**Plans**: 1 plan

Plans:
- [ ] 19-01-PLAN.md — Typography + Selektierbarkeit + Expand/Collapse fuer Beschreibung und Naechster Schritt

### Phase 20: Folder Import
**Goal**: User kann einen existierenden Projektordner per Folder Picker ins Dashboard importieren — mit automatischer Typ-Erkennung, optionalem Scaffolding und sofortigem Erscheinen im richtigen Tab
**Depends on**: Phase 19
**Requirements**: IMP-01, IMP-02, IMP-03, IMP-04, IMP-05, IMP-06, IMP-07
**Success Criteria** (what must be TRUE):
  1. User klickt auf Add+ Karte, waehlt "Importieren", und ein nativer macOS Folder Picker oeffnet sich; nach Auswahl eines Ordners erscheint eine Vorschau mit erkanntem Typ (Code/Research), vorhandenen Dateien und geplanten Scaffold-Aktionen
  2. Fehlende Standard-Dateien (GSD skeleton, CLAUDE.md, .gitignore, git init) werden nach Bestaetigung automatisch angelegt ohne bestehende Dateien zu ueberschreiben
  3. Wenn der importierte Ordner ausserhalb aller bekannten Scan-Verzeichnisse liegt, wird das Parent-Verzeichnis automatisch als neues Scan-Dir hinzugefuegt und der Watcher neu gestartet
  4. Wenn der importierte Ordner bereits innerhalb eines bestehenden Scan-Dirs liegt, zeigt das Dashboard eine Warnung ("Dieser Ordner wird bereits gescannt") statt Duplikate zu erzeugen
  5. Nach erfolgreichem Import erscheint das Projekt sofort im korrekten Tab (Code oder Research) ohne manuelles Neuladen
**Plans**: TBD

### Phase 21: Memory Tab
**Goal**: User hat einen eigenen Tab mit Uebersicht aller Memory-Files, kann Inhalte lesen und Memory-Actions pro Projekt ausfuehren
**Depends on**: Phase 20
**Requirements**: MEM-01, MEM-02, MEM-03, MEM-04, MEM-05, MEM-06, MEM-07
**Success Criteria** (what must be TRUE):
  1. NavigationRail zeigt einen neuen Memory-Tab mit eigenem Icon; Tab-Wechsel funktioniert zuverlaessig (auch Settings bleibt erreichbar) dank Enum-basierter Tab-Selektion statt Integer-Indices
  2. Memory-Tab zeigt eine Projektliste mit Memory-Status (vorhanden/nicht vorhanden) und Freshness-Indikator (Datum der letzten Konsolidierung); Klick auf ein Projekt zeigt rechts den MEMORY.md Inhalt als Markdown-Vorschau
  3. User kann per Quick Action rem-sleep im Terminal fuer das ausgewaehlte Projekt triggern und das Memory-File im Standard-Editor oeffnen
  4. Projekte ohne Memory werden in einer separaten Sektion aufgelistet mit "rem-sleep starten" Action zum Erstellen der ersten Memory
  5. Memory-Tab laedt ohne spuerbares Ruckeln auch bei 20+ Projekten (async Datei-Lesen, Lazy Loading bei Selektion)

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
| 19. Detail-Panel Typography | v1.5 | 0/1 | Not started | - |
| 20. Folder Import | v1.5 | 0/? | Not started | - |
| 21. Memory Tab | v1.5 | 0/? | Not started | - |
