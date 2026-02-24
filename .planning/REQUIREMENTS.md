# Requirements: Pro Orc v1.3 — Project Creator

**Defined:** 2026-02-24
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v1.3 Requirements

Neue Projekte direkt aus Pro Orc erstellen mit Add+ Karte, Erstellungs-Dialog und optionaler Notion Integration.

### Add Card

- [ ] **ADD-01**: Add+ Karte erscheint als letzte Karte im Code-Tab Grid
- [ ] **ADD-02**: Add+ Karte erscheint als letzte Karte im Research-Tab Grid
- [ ] **ADD-03**: Klick auf Add+ oeffnet Erstellungs-Dialog mit Tab-Switcher (Code/Research)
- [ ] **ADD-04**: Tab-Switcher ist vorausgewaehlt basierend auf dem Tab von dem Add+ gedrueckt wurde

### Dialog

- [ ] **DLG-01**: Textfeld fuer Projektname (wird Ordnername)
- [ ] **DLG-02**: Code-Tab: Toggle fuer Git Repository initialisieren (default: on)
- [ ] **DLG-03**: Code-Tab: Toggle fuer GSD Skeleton anlegen (.planning/PROJECT.md) (default: off)
- [ ] **DLG-04**: Research-Tab: Toggle fuer Notion-Seite erstellen (default: on)
- [ ] **DLG-05**: Beide Tabs: Toggle fuer rem-sleep nach Erstellung ausfuehren (default: off)
- [ ] **DLG-06**: Beide Tabs: Toggle fuer Terminal im Projektordner oeffnen (default: on)
- [ ] **DLG-07**: Code-Tab: Toggle fuer CLAUDE.md erstellen mit Starter-Template (default: on)
- [ ] **DLG-08**: Code-Tab: Dropdown fuer .gitignore Template (Flutter / Node.js / Python / None, default: None)

### Project Creation

- [ ] **CRE-01**: Ordner im ersten passenden Scan-Directory anlegen (code/ fuer Code, research/ fuer Research)
- [ ] **CRE-02**: Git Repository initialisieren wenn Toggle aktiv (`git init`)
- [ ] **CRE-03**: GSD Skeleton anlegen wenn Toggle aktiv (`.planning/PROJECT.md` mit Name)
- [ ] **CRE-04**: Terminal im neuen Projektordner oeffnen wenn Toggle aktiv
- [ ] **CRE-05**: rem-sleep im neuen Projektordner ausfuehren wenn Toggle aktiv (via osascript)
- [ ] **CRE-06**: CLAUDE.md mit Projektname und Platzhalter-Sektionen anlegen wenn Toggle aktiv
- [ ] **CRE-07**: .gitignore aus gewaehltem Template anlegen wenn nicht "None"

### Notion Integration

- [ ] **NOT-01**: Notion API Key in Settings konfigurierbar (verschluesselt gespeichert)
- [ ] **NOT-02**: Notion Parent Page/Database ID in Settings konfigurierbar
- [ ] **NOT-03**: Neue Notion-Seite erstellen mit Projektname als Titel
- [ ] **NOT-04**: Notion-URL als `<!-- notion: URL -->` in PROJECT.md des neuen Projekts schreiben

## Future Requirements

Deferred to later releases.

### UI Enhancements

- **UI-07**: Inline Markdown-Rendering fuer Projekt-Beschreibungen
- **UI-08**: Search/Filter ueber Projekte
- **UI-09**: Dock Badge mit Anzahl stale/aktiver Projekte

### Native Enhancements

- **NAT-05**: Global Keyboard Shortcut (Cmd+Shift+P) zum Einblenden
- **NAT-06**: macOS Notifications fuer stale Projects
- **NAT-07**: macOS native App-Menue (File/Edit/View)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Notion API Read/Sync | Nur Seiten-Erstellung, kein vollstaendiger Sync |
| Projekt-Templates mit vollem Scaffolding | Zu komplex, .gitignore + CLAUDE.md reichen fuer v1.3 |
| Projekt-Editing in Dialog nach Erstellung | Read-only Dashboard Prinzip bleibt |
| MCP Server Vorkonfiguration pro Projekt | Zu individuell fuer generischen Dialog |
| Claude Hooks Vorkonfiguration | Zu projektspezifisch |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADD-01 | Phase 15 | Pending |
| ADD-02 | Phase 15 | Pending |
| ADD-03 | Phase 15 | Pending |
| ADD-04 | Phase 15 | Pending |
| DLG-01 | Phase 15 | Pending |
| DLG-02 | Phase 15 | Pending |
| DLG-03 | Phase 15 | Pending |
| DLG-04 | Phase 15 | Pending |
| DLG-05 | Phase 15 | Pending |
| DLG-06 | Phase 15 | Pending |
| DLG-07 | Phase 15 | Pending |
| DLG-08 | Phase 15 | Pending |
| CRE-01 | Phase 16 | Pending |
| CRE-02 | Phase 16 | Pending |
| CRE-03 | Phase 16 | Pending |
| CRE-04 | Phase 16 | Pending |
| CRE-05 | Phase 16 | Pending |
| CRE-06 | Phase 16 | Pending |
| CRE-07 | Phase 16 | Pending |
| NOT-01 | Phase 14 | Pending |
| NOT-02 | Phase 14 | Pending |
| NOT-03 | Phase 17 | Pending |
| NOT-04 | Phase 17 | Pending |

**Coverage:**
- v1.3 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-02-24*
*Last updated: 2026-02-24 after roadmap creation (v1.3 phases 14-17)*
