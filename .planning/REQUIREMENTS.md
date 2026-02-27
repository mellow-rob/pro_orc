# Requirements: Pro Orc

**Defined:** 2026-02-27
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der naechste Schritt ist, und welche Tools zur Verfuegung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v1.4 Requirements

Requirements fuer Milestone v1.4 Projekt-Loeschfunktion. Jedes Requirement mapped auf eine Roadmap-Phase.

### Loeschen

- [ ] **DEL-01**: User kann "Projekt loeschen" im Rechtsklick-Kontextmenue auf Code-Cards waehlen
- [ ] **DEL-02**: User kann "Projekt loeschen" im Rechtsklick-Kontextmenue auf Research-Cards waehlen
- [ ] **DEL-03**: User muss Projektnamen eintippen zur Bestaetigung (GitHub-Style)
- [ ] **DEL-04**: Projekt-Ordner wird permanent vom Filesystem geloescht (rm -rf)
- [ ] **DEL-05**: Dashboard aktualisiert sich automatisch nach dem Loeschen (Provider-Invalidation)

### Cleanup

- [ ] **CLN-01**: Dialog erkennt verlinkte Notion-Seite (aus `<!-- notion: URL -->` in PROJECT.md) und fragt ob sie geloescht werden soll
- [ ] **CLN-02**: Dialog erkennt GitHub Remote (aus `git remote -v`) und fragt ob das Repo geloescht werden soll
- [ ] **CLN-03**: Dialog erkennt Figma und andere externe Ressourcen-Links aus Projektdateien
- [ ] **CLN-04**: Dialog erkennt MCP-Server- und Plugin-erstellte Daten (z.B. Claude Memory in ~/.claude/projects/, Firebase, Vercel, etc.) und fragt schrittweise ob diese geloescht werden sollen
- [ ] **CLN-05**: Alle erkannten Ressourcen werden schrittweise einzeln abgefragt (Ja/Nein pro Ressource)

## Future Requirements

Keine — v1.4 ist fokussiert auf Loeschfunktion.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Papierkorb / Undo | Bestaetigungsdialog mit Name-Eingabe ist ausreichender Schutz |
| Batch-Loeschen mehrerer Projekte | Over-engineering, einzeln loeschen reicht |
| Automatisches Loeschen externer Ressourcen ohne Abfrage | Zu gefaehrlich, schrittweise Abfrage ist Pflicht |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEL-01 | — | Pending |
| DEL-02 | — | Pending |
| DEL-03 | — | Pending |
| DEL-04 | — | Pending |
| DEL-05 | — | Pending |
| CLN-01 | — | Pending |
| CLN-02 | — | Pending |
| CLN-03 | — | Pending |
| CLN-04 | — | Pending |
| CLN-05 | — | Pending |

**Coverage:**
- v1.4 requirements: 10 total
- Mapped to phases: 0
- Unmapped: 10 ⚠️

---
*Requirements defined: 2026-02-27*
*Last updated: 2026-02-27 after initial definition*
