# Pro Orc — Project Orchestration Dashboard

## What This Is

Lokale Next.js Web-App als persönliches Projekt-Management Dashboard. Scannt automatisch Projektordner (`~/project_orchestration/code/` und `~/project_orchestration/project research/`), zeigt GSD-Status und Fortschritt pro Projekt, listet installierte Claude Code Tools auf, und bietet Quick Actions zum Öffnen in Terminal/Finder/Notion. Nur localhost, kein Netzwerk, kein Auth — ein Single-User Power-Dashboard.

## Core Value

Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Card-Grid Dashboard mit GSD Status, Phase Progress, Next Step, Last Activity
- [ ] Auto-Scan von code/ und project research/ mit Typ-Erkennung
- [ ] Live Updates via chokidar Singleton Watcher + SSE
- [ ] Git Integration (letzter Commit, Timestamp, concurrent + timeout)
- [ ] Quick Actions: Open in Terminal.app, Finder, Notion
- [ ] Research-Projekte als eigenes Card-Layout (keine Git-Metriken)
- [ ] Claude Tools Inventory: Skills, MCP Server, Plugins mit Name, Typ, Beschreibung
- [ ] Dark Mode first, localhost only, keine DB

### Out of Scope

- Multi-device / Netzwerk — nur localhost
- User Accounts / Auth — Single User
- Datenbank — Filesystem IS the database
- Manuelle Projektverwaltung — Auto-scan only
- Projekt-Editing in UI — Read-only Dashboard
- Notifications — Live updates in open tab reichen
- Plugin System — Over-engineering
- Full-text Search — Client-side Filter reicht für <50 Projekte
- Light Mode / Theme Toggle — v2
- GSD-Befehle aus der App auslösen — v2
- Inline Preview von PROJECT.md / REQUIREMENTS.md — v2
- Notion API Integration (Read/Write) — v2

## Context

- Beide Scan-Pfade existieren bereits mit Projekten
- Projekte verwenden das GSD-Workflow-System mit `.planning/` Directories
- `.planning/STATE.md`, `ROADMAP.md`, `PROJECT.md` sind die primären Datenquellen
- Terminal-Integration via macOS Terminal.app (nicht iTerm/Warp)
- Notion URL Konvention: Vorschlag — dediziertes `<!-- notion: URL -->` HTML-Comment im Header von PROJECT.md, leicht parsebar ohne Frontmatter-Dependency
- Claude Tools leben unter `~/.claude/` — Skills, MCP Server Config, Plugins jeweils mit Name, Typ und Beschreibung anzeigen
- Pfade immer via `os.homedir()` aufgelöst, nie hardcoded

## Constraints

- **Tech Stack**: Next.js 15.2 + React 19 + TypeScript + Tailwind CSS v4.0 + shadcn/ui + lucide-react
- **Deployment**: Nur localhost:3000
- **Design**: Dark Mode first, kein Toggle in v1
- **Datenquelle**: Filesystem + Git via simple-git (async), keine Datenbank
- **Live Updates**: chokidar (Singleton via instrumentation.ts) + SSE (ReadableStream Route Handler)
- **Notion**: Nur ausgehende Links in v1 (kein API-Zugriff)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Notion-Link als `<!-- notion: URL -->` in PROJECT.md | Einfachste Integration, keine API nötig, leicht parsebar | — Pending |
| Filesystem + Git als Datenquelle | Kein DB-Setup, Daten sind bereits da | — Pending |
| Card Grid Layout | Bessere Übersicht als Liste/Kanban für <50 Projekte | — Pending |
| chokidar + SSE für Live Updates | Singleton Watcher, kein Polling, performant | — Pending |
| Auto-Erkennung Claude Tools | Kein manuelles Pflegen nötig | — Pending |
| Terminal.app für "Open in Terminal" | User-Präferenz, via `open -a Terminal` | — Pending |

---
*Last updated: 2026-02-17 after initialization*
