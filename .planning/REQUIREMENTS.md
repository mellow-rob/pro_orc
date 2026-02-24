# Requirements: Pro Orc v1.2 — Memory Indicator

**Defined:** 2026-02-24
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v1.2 Requirements

Requirements for rem-sleep Memory Indicator feature on project cards.

### Memory Detection

- [ ] **MEM-01**: Scanner erkennt pro Projekt ob `~/.claude/projects/[encoded-path]/memory/MEMORY.md` existiert
- [ ] **MEM-02**: Scanner liest mtime der MEMORY.md und stellt sie als "letzte Konsolidierung" bereit
- [ ] **MEM-03**: Pfad-Encoding wandelt Projektpfad in Claude-Projektverzeichnis-Format um (`/Users/rob/code/foo` → `-Users-rob-code-foo`)

### Memory UI

- [ ] **MUI-01**: Sleeping-Book-Icon auf Code- und Research-Cards zeigt Memory-Status (konsolidiert / nicht vorhanden)
- [ ] **MUI-02**: Icon zeigt visuell ob Memory stale ist (z.B. älter als 7 Tage)
- [ ] **MUI-03**: Tooltip auf Icon zeigt "Letzte Konsolidierung: [Datum]" oder "Keine Memory vorhanden"

### Memory Actions

- [ ] **MACT-01**: Quick Action öffnet Terminal mit `claude` im Projektverzeichnis zum rem-sleep Triggern

## Future Requirements

Deferred to later releases.

### Native Enhancements

- **NAT-05**: Global Keyboard Shortcut (Cmd+Shift+P) zum Einblenden
- **NAT-06**: macOS Notifications für stale Projects
- **NAT-07**: macOS native App-Menü (File/Edit/View)

### UI Enhancements

- **UI-07**: Inline Markdown-Rendering für Projekt-Beschreibungen
- **UI-08**: Search/Filter über Projekte
- **UI-09**: Dock Badge mit Anzahl stale/aktiver Projekte

## Out of Scope

| Feature | Reason |
|---------|--------|
| Memory-Datei editieren in UI | Read-only Dashboard Prinzip |
| Automatisches rem-sleep Scheduling | Gehört in Claude Code Hooks, nicht in Dashboard |
| Memory-Inhalt anzeigen/durchsuchen | Zu komplex für v1.2, evtl. späterer Milestone |
| Daily-Files (YYYY-MM-DD.md) tracken | Werden in aktuellem Setup nicht genutzt |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MEM-01 | Phase 12 | Pending |
| MEM-02 | Phase 12 | Pending |
| MEM-03 | Phase 12 | Pending |
| MUI-01 | Phase 13 | Pending |
| MUI-02 | Phase 13 | Pending |
| MUI-03 | Phase 13 | Pending |
| MACT-01 | Phase 13 | Pending |

**Coverage:**
- v1.2 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0

---
*Requirements defined: 2026-02-24*
*Last updated: 2026-02-24 after roadmap creation*
