# Requirements: Pro Orc

**Defined:** 2026-03-06
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der naechste Schritt ist, und welche Tools zur Verfuegung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v2.0 Requirements

Requirements for Open Source Public Release. Each maps to roadmap phases.

### Claude-Button

- [ ] **CLB-01**: User kann auf jeder Projektkarte einen prominenten Claude-Button klicken der eine Claude Code Session im Terminal im Projektverzeichnis startet
- [ ] **CLB-02**: Claude-Button ist visuell hervorgehoben (Cyan, groesser) und als primaere Action auf der Karte erkennbar
- [ ] **CLB-03**: Bisheriger Terminal-Button wird durch Claude-Button ersetzt; Terminal-Zugang bleibt ueber Kontextmenue oder sekundaere Action erreichbar

### Skill/Plugin Browser

- [ ] **SPB-01**: User sieht pro Projekt welche Skills und Plugins aktiv/installiert sind
- [ ] **SPB-02**: User kann per Quick Action ein Skill/Plugin im Editor oeffnen oder Docs anzeigen
- [ ] **SPB-03**: Browser zeigt Metadaten (Autor, installiert am, zuletzt aktualisiert) pro Plugin

### Onboarding

- [ ] **ONB-01**: Beim ersten Start erkennt Pro Orc ob Claude Code CLI installiert ist und zeigt Setup-Hilfe falls nicht
- [ ] **ONB-02**: Setup-Wizard fuehrt durch Ersteinrichtung: Claude Code Check, Scan-Verzeichnisse konfigurieren, ersten Projekt-Import
- [ ] **ONB-03**: Wizard ist ueberspringbar und kann spaeter ueber Settings erneut gestartet werden

### Open Source Polish

- [ ] **OSS-01**: GitHub README mit Feature-Beschreibung, Screenshots, Installationsanleitung (Homebrew + DMG) und Quick-Start Guide
- [ ] **OSS-02**: LICENSE-Datei (MIT oder Apache 2.0) und CONTRIBUTING.md mit Contribution Guidelines
- [ ] **OSS-03**: Repo-Audit: hardcoded Pfade entfernen, Secrets in Git-History pruefen, .gitignore aufraeumen
- [ ] **OSS-04**: GitHub Issue Templates und Release Notes Template

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Settings GUI

- **SET-01**: Grafische Oberflaeche fuer ~/.claude/settings.json (Modell, Tools, Plugins)
- **SET-02**: MCP Server Konfiguration anzeigen und editieren
- **SET-03**: Per-Projekt Claude Settings anzeigen

### Advanced Features

- **ADV-01**: Embedded Terminal in Pro Orc (kein separates Terminal.app)
- **ADV-02**: Claude Code Session Output Streaming in der App
- **ADV-03**: Skill/Plugin Installation direkt aus dem Browser

## Out of Scope

| Feature | Reason |
|---------|--------|
| Embedded Terminal / Chat UI | Architektur-Komplexitaet, Terminal bleibt Arbeitsumgebung |
| Multi-User / Cloud Sync | Single-User Tool, nur localhost |
| Auto-Update Mechanismus | git pull && flutter build reicht |
| Light Mode | n3urala1 Theme ist intentional dark-only |
| App Store Distribution | Sandbox-Anforderungen zu restriktiv |
| Settings GUI | Instabiles Schema, Race Conditions, geringer Nutzen fuer Zielgruppe |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLB-01 | Phase 22 | Pending |
| CLB-02 | Phase 22 | Pending |
| CLB-03 | Phase 22 | Pending |
| SPB-01 | Phase 23 | Pending |
| SPB-02 | Phase 23 | Pending |
| SPB-03 | Phase 23 | Pending |
| ONB-01 | Phase 24 | Pending |
| ONB-02 | Phase 24 | Pending |
| ONB-03 | Phase 24 | Pending |
| OSS-01 | Phase 25 | Pending |
| OSS-02 | Phase 25 | Pending |
| OSS-03 | Phase 25 | Pending |
| OSS-04 | Phase 25 | Pending |

**Coverage:**
- v2.0 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-06*
*Last updated: 2026-03-06 after initial definition*
