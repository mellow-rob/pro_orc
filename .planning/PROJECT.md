<!-- notion: https://www.notion.so/30af1cbe281e807e8484d8c1f11a1944 -->
# Pro Orc — Project Orchestration Dashboard

## What This Is

Native macOS Flutter-App als persönliches Projekt-Management Dashboard. Scannt automatisch Projektordner (`~/project_orchestration/code/` und `~/project_orchestration/project research/`), zeigt GSD-Status und Fortschritt pro Projekt, listet installierte Claude Code Tools auf, und bietet Quick Actions zum Öffnen in Terminal/Finder/Notion. Menubar-Icon + Hauptfenster, Echtzeit File-Watching via dart:io. Nur lokal, kein Netzwerk, kein Auth — ein Single-User Power-Dashboard.

## Current Milestone: v1.1 Flutter macOS Rewrite

**Goal:** Kompletter Rewrite der Next.js Web-App als native macOS Flutter-Applikation mit voller v1.0 Feature-Parität.

**Target features:**
- Native macOS App mit Menubar-Icon + Hauptfenster
- Komplett Dart-nativ: Filesystem-Scanning, Git-Parsing, File-Watching über dart:io
- Volle Feature-Parität: Dashboard, Git-Status, GSD-Anzeige, Live-Updates, Tools-Panel, Quick Actions
- n3urala1 Dark Theme 1:1 (OKLCH Cyan/Fuchsia, Glassmorphism)
- Entwicklung auf `dev` Branch

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

- [ ] Native macOS Flutter App mit Menubar-Icon + Hauptfenster — v1.1
- [ ] Dart-natives Filesystem-Scanning (code/ + project research/) — v1.1
- [ ] Dart-natives Git-Reading (letzter Commit, Timestamp, Message) — v1.1
- [ ] Dart-natives File-Watching mit Live-Updates — v1.1
- [ ] GSD-Parser (STATE.md, ROADMAP.md, PROJECT.md) in Dart — v1.1
- [ ] Card-Grid Dashboard mit n3urala1 Theme in Flutter — v1.1
- [ ] Claude Tools Inventory in Flutter — v1.1
- [ ] Quick Actions: Terminal.app, Finder, GitHub, Notion — v1.1

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

- v1.0 shipped as Next.js web app: 3,120 LOC TypeScript/TSX/CSS, 97 files
- v1.1 rewrites to Flutter/Dart as native macOS app
- v1.0 reference implementation in `pro-orc/` (Next.js) — use as feature/logic reference
- Dashboard discovers 22+ projects across code/ and research/ directories
- n3urala1 dark theme: OKLCH colors, cyan primary, fuchsia accent, glassmorphism
- Flutter app lives in new directory (e.g. `pro-orc-flutter/` or `pro_orc/`)
- Menubar integration via macOS-specific Flutter packages (e.g. tray_manager, macos_window_utils)
- Git operations: dart process to call git CLI, or libgit2dart package
- File watching: dart:io FileSystemEntity.watch() or watcher package

## Constraints

- **Tech Stack**: Flutter 3.x + Dart 3.x, macOS target only (v1.1)
- **Deployment**: Lokale macOS App (.app Bundle), kein App Store
- **Design**: n3urala1 Dark Mode Theme, kein Toggle in v1.1
- **Datenquelle**: Filesystem + Git via dart:io / git CLI, keine Datenbank
- **Live Updates**: dart:io FileSystemEntity.watch() oder watcher package
- **Notion**: Nur ausgehende Links (url_launcher)
- **Branch**: Entwicklung auf `dev` Branch

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

| Flutter macOS Rewrite statt inkrementelle Web-Features | Native Experience, Menubar, Performance; Flutter als Zukunftsbasis | — Pending |

---
*Last updated: 2026-02-19 after v1.1 milestone start*
