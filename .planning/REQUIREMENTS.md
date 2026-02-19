# Requirements: Pro Orc v1.1 — Flutter macOS Rewrite

**Defined:** 2026-02-19
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v1.1 Requirements

Requirements for Flutter macOS rewrite with full v1.0 feature parity + native macOS capabilities.

### Native macOS

- [ ] **NAT-01**: App läuft als native macOS .app mit Menubar-Icon (kein Dock-Icon)
- [ ] **NAT-02**: Klick auf Menubar-Icon zeigt/versteckt das Hauptfenster
- [ ] **NAT-03**: Fensterposition und -größe werden zwischen Sessions persistent gespeichert
- [ ] **NAT-04**: App Sandbox deaktiviert für vollen Filesystem + Subprocess-Zugriff

### Scanning & Parsing

- [ ] **SCAN-01**: Dart-natives Scanning von `~/project_orchestration/code/` und `~/project_orchestration/project research/`
- [ ] **SCAN-02**: Projekt-Typ-Erkennung (Code vs Research) anhand Verzeichnisstruktur
- [ ] **SCAN-03**: GSD-Parser liest STATE.md, ROADMAP.md, PROJECT.md — extrahiert Status, Phase, Progress, Next Step
- [ ] **SCAN-04**: Notion-URL-Extraktion aus `<!-- notion: URL -->` Kommentar in PROJECT.md
- [ ] **SCAN-05**: Beschreibung aus PROJECT.md oder CLAUDE.md extrahieren

### Git Integration

- [ ] **GIT-01**: Letzter Commit (Message, Hash, Timestamp) via `Process.run('git', ...)`
- [ ] **GIT-02**: Concurrent git-Calls mit Timeout (5s) und Future.wait-Chunking
- [ ] **GIT-03**: GitHub-URL aus git remote extrahieren

### Live Updates

- [ ] **LIVE-01**: File-Watching via `watcher` Package mit Debounce (350ms)
- [ ] **LIVE-02**: StreamController.broadcast() → StreamBuilder für reaktive Card-Updates
- [ ] **LIVE-03**: Cards aktualisieren sich automatisch bei Filesystem-Änderungen

### Dashboard UI

- [ ] **UI-01**: Card-Grid Layout mit responsive Spaltenanzahl
- [ ] **UI-02**: Code-Project-Card zeigt: Name, GSD-Status, Phase-Progress, Next Step, Git-Info, Stale-Indikator
- [ ] **UI-03**: Research-Project-Card zeigt: Name, Beschreibung (ohne Git-Metriken)
- [ ] **UI-04**: Tab-Navigation: Code / Research / Claude Tools
- [ ] **UI-05**: n3urala1 Dark Theme (OKLCH→sRGB konvertiert, Cyan/Fuchsia, Glassmorphism)
- [ ] **UI-06**: Private/Visible Toggle pro Card (In-Memory)

### Quick Actions

- [ ] **ACT-01**: Open in Terminal.app via `Process.run('open', ['-a', 'Terminal', path])`
- [ ] **ACT-02**: Open in Finder via `Process.run('open', [path])`
- [ ] **ACT-03**: Open GitHub URL im Browser via url_launcher
- [ ] **ACT-04**: Open Notion URL im Browser via url_launcher

### Claude Tools

- [ ] **TOOL-01**: Auto-Discovery von Skills aus `~/.claude/`
- [ ] **TOOL-02**: Auto-Discovery von MCP Servers aus `~/.claude/`
- [ ] **TOOL-03**: Auto-Discovery von Plugins aus `~/.claude/`
- [ ] **TOOL-04**: Anzeige mit Name, Typ, Beschreibung pro Tool

## v1.2 Requirements

Deferred to future release. Tracked but not in current roadmap.

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
| App Store Distribution | Sandbox-Anforderungen zu restriktiv für Filesystem-Zugriff |
| Light Mode | n3urala1 Theme ist intentional dark-only |
| SSE / HTTP Server | Flutter-App braucht keinen Server — StreamController reicht |
| Multi-Window | Kein Detail-View in v1.0, nicht beim Port einführen |
| WebView für READMEs | +30MB Binary-Size, nicht nötig |
| Auto-Update | Single-Developer Tool, `git pull && flutter build macos` reicht |
| Cloud Sync | Nur lokaler Filesystem-Zugriff, kein Remote |
| Notion API Read/Write | Nur ausgehende Links, kein API-Zugriff |
| Multi-Terminal Support | Terminal.app only, wie v1.0 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAT-01 | — | Pending |
| NAT-02 | — | Pending |
| NAT-03 | — | Pending |
| NAT-04 | — | Pending |
| SCAN-01 | — | Pending |
| SCAN-02 | — | Pending |
| SCAN-03 | — | Pending |
| SCAN-04 | — | Pending |
| SCAN-05 | — | Pending |
| GIT-01 | — | Pending |
| GIT-02 | — | Pending |
| GIT-03 | — | Pending |
| LIVE-01 | — | Pending |
| LIVE-02 | — | Pending |
| LIVE-03 | — | Pending |
| UI-01 | — | Pending |
| UI-02 | — | Pending |
| UI-03 | — | Pending |
| UI-04 | — | Pending |
| UI-05 | — | Pending |
| UI-06 | — | Pending |
| ACT-01 | — | Pending |
| ACT-02 | — | Pending |
| ACT-03 | — | Pending |
| ACT-04 | — | Pending |
| TOOL-01 | — | Pending |
| TOOL-02 | — | Pending |
| TOOL-03 | — | Pending |
| TOOL-04 | — | Pending |

**Coverage:**
- v1.1 requirements: 29 total
- Mapped to phases: 0
- Unmapped: 29 ⚠️

---
*Requirements defined: 2026-02-19*
*Last updated: 2026-02-19 after initial definition*
