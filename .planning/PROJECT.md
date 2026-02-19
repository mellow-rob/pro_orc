<!-- notion: https://www.notion.so/30af1cbe281e807e8484d8c1f11a1944 -->
# Pro Orc — Project Orchestration Dashboard

## What This Is

Lokale Next.js Web-App als persönliches Projekt-Management Dashboard. Scannt automatisch Projektordner (`~/project_orchestration/code/` und `~/project_orchestration/project research/`), zeigt GSD-Status und Fortschritt pro Projekt, listet installierte Claude Code Tools auf, und bietet Quick Actions zum Öffnen in Terminal/Finder/Notion. Echtzeit-Updates via chokidar + SSE. Nur localhost, kein Netzwerk, kein Auth — ein Single-User Power-Dashboard.

## Core Value

Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.

## Requirements

### Validated

- ✓ Card-Grid Dashboard mit GSD Status, Phase Progress, Next Step, Last Activity — v1.0
- ✓ Auto-Scan von code/ und project research/ mit Typ-Erkennung — v1.0
- ✓ Live Updates via chokidar Singleton Watcher + SSE — v1.0
- ✓ Git Integration (letzter Commit, Timestamp, Message, concurrent + timeout) — v1.0
- ✓ Quick Actions: Open in Terminal.app, Finder, Notion — v1.0
- ✓ Research-Projekte als eigenes Card-Layout (keine Git-Metriken) — v1.0
- ✓ Claude Tools Inventory: Skills, MCP Server, Plugins mit Name, Typ, Beschreibung — v1.0
- ✓ Dark Mode first, localhost only, keine DB — v1.0

### Active

(Next milestone requirements defined via /gsd:new-milestone)

### Out of Scope

- Multi-device / Netzwerk — nur localhost
- User Accounts / Auth — Single User
- Datenbank — Filesystem IS the database
- Manuelle Projektverwaltung — Auto-scan only
- Projekt-Editing in UI — Read-only Dashboard
- Notifications — Live updates in open tab reichen
- Plugin System — Over-engineering
- Full-text Search — Client-side Filter reicht für <50 Projekte

## Context

- v1.0 shipped: 3,120 LOC TypeScript/TSX/CSS, 97 files
- Tech stack: Next.js 16.1.6, React 19, TypeScript 5, Tailwind CSS v4, shadcn/ui, chokidar v3, simple-git
- Dashboard discovers 22+ projects across code/ and research/ directories
- n3urala1 dark theme: OKLCH colors, cyan primary, fuchsia accent, glassmorphism
- Live updates circuit: chokidar → debounce → SSE → EventSource → re-fetch → card re-render
- Tools panel: auto-discovers skills, MCP servers, plugins from ~/.claude/
- Known tech debt: openNotionPage dead code, unused SSE event types (project:added/removed), dead type fields (branch/isDirty)

## Constraints

- **Tech Stack**: Next.js 16.1.6 + React 19 + TypeScript 5 + Tailwind CSS v4.0 + shadcn/ui + lucide-react
- **Deployment**: Nur localhost:3000
- **Design**: Dark Mode first, kein Toggle in v1
- **Datenquelle**: Filesystem + Git via simple-git (async), keine Datenbank
- **Live Updates**: chokidar v3 (Singleton via instrumentation.ts) + SSE (ReadableStream Route Handler)
- **Notion**: Nur ausgehende Links (kein API-Zugriff)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Notion-Link als `<!-- notion: URL -->` in PROJECT.md | Einfachste Integration, keine API nötig, leicht parsebar | ✓ Good — works reliably |
| Filesystem + Git als Datenquelle | Kein DB-Setup, Daten sind bereits da | ✓ Good — zero setup |
| Card Grid Layout | Bessere Übersicht als Liste/Kanban für <50 Projekte | ✓ Good — scales to 22+ projects |
| chokidar v3 + SSE für Live Updates | Singleton Watcher, kein Polling, performant; v3 statt v4 wg. ESM bundling | ✓ Good — ~1s update latency |
| Auto-Erkennung Claude Tools | Kein manuelles Pflegen nötig | ✓ Good — discovers all tools from ~/.claude/ |
| Terminal.app für "Open in Terminal" | User-Präferenz, via `open -a Terminal` | ✓ Good |
| Notion links via `<a href>` statt Server Action | Simpler, kein JS nötig | ✓ Good — openNotionPage server action removed as dead code |
| GsdStatus als open string union `(string & {})` | Autocomplete ohne Rigidität | ✓ Good — handles unknown statuses |
| n3urala1 OKLCH dark theme | Cyan primary, fuchsia accent, glassmorphism | ✓ Good — distinctive aesthetic |
| SSE signal-only pattern | Events carry `{ type, projectId }`, browser re-fetches | ✓ Good — simple, no stale data |

---
*Last updated: 2026-02-19 after v1.0 milestone*
