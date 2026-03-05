# Requirements: Pro Orc

**Defined:** 2026-03-05
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der naechste Schritt ist, und welche Tools zur Verfuegung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v1.5 Requirements

Requirements for milestone v1.5: Import, Detail-Panel & Memory-Tab.

### Detail-Panel

- [ ] **DPL-01**: User sieht Beschreibungstexte mit erhoehter Zeilenhoehe (1.6+) fuer bessere Lesbarkeit
- [ ] **DPL-02**: User kann Beschreibungstexte selektieren und kopieren
- [ ] **DPL-03**: Beschreibungstexte erfuellen WCAG AA Kontrast auf dunklem Glasmorphism-Hintergrund
- [ ] **DPL-04**: Lange Beschreibungen werden mit "Mehr anzeigen"/"Weniger anzeigen" ein-/ausgeklappt

### Folder Import

- [ ] **IMP-01**: User kann ueber den Add+ Button einen existierenden Ordner per macOS Folder Picker auswaehlen
- [ ] **IMP-02**: Projekttyp (Code/Research) wird automatisch via bestehender _inferType()-Logik erkannt
- [ ] **IMP-03**: Fehlende Dateien (GSD skeleton, CLAUDE.md, .gitignore, git init) werden automatisch angelegt
- [ ] **IMP-04**: Ordner ausserhalb bekannter Scan-Verzeichnisse fuehren zur Erweiterung der Scan-Dirs (Parent-Verzeichnis)
- [ ] **IMP-05**: Duplikat-Erkennung: Ordner innerhalb bestehender Scan-Dirs zeigen Warnung statt erneutes Hinzufuegen
- [ ] **IMP-06**: Import-Vorschau zeigt erkannten Zustand (Typ, vorhandene Dateien, geplante Aktionen) vor Bestaetigung
- [ ] **IMP-07**: Nach Import erscheint das Projekt sofort im korrekten Tab (Live-Update via Watcher-Neustart)

### Memory Tab

- [ ] **MEM-01**: Neuer Memory-Tab in NavigationRail mit eigenem Icon zeigt alle Memory-Files
- [ ] **MEM-02**: Projektliste mit Memory-Status und Freshness-Indikator (zuletzt konsolidiert)
- [ ] **MEM-03**: Master-Detail Layout: Projektliste links, MEMORY.md Inhalt rechts als Vorschau
- [ ] **MEM-04**: Quick Action: rem-sleep im Terminal triggern fuer ausgewaehltes Projekt
- [ ] **MEM-05**: Quick Action: Memory-File im Editor oeffnen
- [ ] **MEM-06**: Projekte ohne Memory werden separat aufgelistet mit "rem-sleep starten" Action
- [ ] **MEM-07**: NavigationRail nutzt Enum-basierte Tab-Selektion statt Integer-Indices

## Future Requirements

### Deferred

- **IMP-F01**: Drag-and-Drop Import von Ordnern ins Dashboard
- **IMP-F02**: Batch-Import mehrerer Ordner gleichzeitig
- **MEM-F01**: Suche und Diff in Memory-Files
- **MEM-F02**: Memory-Editing direkt im Dashboard

## Out of Scope

| Feature | Reason |
|---------|--------|
| Memory-Editing im Dashboard | Read-only by Design — Editing gehoert in den Editor |
| Rekursives Folder-Scanning beim Import | Ueberkomplex, User soll explizit waehlen |
| Full Markdown Renderer fuer kurze Beschreibungen | Overkill — leichtgewichtiges TextSpan Parsing reicht |
| Drag-and-Drop Import | Kann spaeter ohne Architektur-Aenderungen ergaenzt werden |
| Batch Folder Import | Single-Folder Import reicht fuer MVP |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DPL-01 | Phase 19 | Pending |
| DPL-02 | Phase 19 | Pending |
| DPL-03 | Phase 19 | Pending |
| DPL-04 | Phase 19 | Pending |
| IMP-01 | Phase 20 | Pending |
| IMP-02 | Phase 20 | Pending |
| IMP-03 | Phase 20 | Pending |
| IMP-04 | Phase 20 | Pending |
| IMP-05 | Phase 20 | Pending |
| IMP-06 | Phase 20 | Pending |
| IMP-07 | Phase 20 | Pending |
| MEM-01 | Phase 21 | Pending |
| MEM-02 | Phase 21 | Pending |
| MEM-03 | Phase 21 | Pending |
| MEM-04 | Phase 21 | Pending |
| MEM-05 | Phase 21 | Pending |
| MEM-06 | Phase 21 | Pending |
| MEM-07 | Phase 21 | Pending |

**Coverage:**
- v1.5 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-05*
*Last updated: 2026-03-05 after roadmap creation*
