<!-- notion: https://www.notion.so/30af1cbe281e807e8484d8c1f11a1944 -->
# Pro Orc — Project Orchestration Dashboard

## What This Is

Native macOS Flutter-App als persönliches Projekt-Management Dashboard. Scannt automatisch Projektordner (`~/project_orchestration/code/` und `~/project_orchestration/project research/`), zeigt GSD-Status und Fortschritt pro Projekt, listet installierte Claude Code Tools auf, und bietet Quick Actions zum Öffnen in Terminal/Finder/Notion/GitHub. Menubar-Icon + Hauptfenster, Echtzeit File-Watching via dart:io/watcher. Nur lokal, kein Netzwerk, kein Auth — ein Single-User Power-Dashboard.

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
- ✓ Native macOS Flutter App mit Menubar-Icon + Hauptfenster — v1.1
- ✓ Dart-natives Filesystem-Scanning (code/ + project research/) — v1.1
- ✓ Dart-natives Git-Reading (letzter Commit, Timestamp, Message) — v1.1
- ✓ Dart-natives File-Watching mit Live-Updates — v1.1
- ✓ GSD-Parser (STATE.md, ROADMAP.md, PROJECT.md) in Dart — v1.1
- ✓ Card-Grid Dashboard mit n3urala1 Theme in Flutter — v1.1
- ✓ Claude Tools Inventory in Flutter — v1.1
- ✓ Quick Actions: Terminal.app, Finder, GitHub, Notion — v1.1

### Active

(None — plan next milestone with `/gsd:new-milestone`)

### Out of Scope

- Multi-device / Netzwerk — nur localhost
- User Accounts / Auth — Single User
- Manuelle Projektverwaltung — Auto-scan only
- Projekt-Editing in UI — Read-only Dashboard
- Notifications — Live updates in open tab reichen
- Plugin System — Over-engineering
- App Store Distribution — Sandbox-Anforderungen zu restriktiv für Filesystem-Zugriff
- Light Mode — n3urala1 Theme ist intentional dark-only
- Auto-Update — Single-Developer Tool, `git pull && flutter build macos` reicht
- Cloud Sync — Nur lokaler Filesystem-Zugriff, kein Remote
- Notion API Read/Write — Nur ausgehende Links, kein API-Zugriff

## Context

- v1.0 shipped as Next.js web app: 3,120 LOC TypeScript/TSX/CSS, 97 files (2026-02-19)
- v1.1 shipped as native macOS Flutter app: 8,931 LOC Dart, 164 files (2026-02-24)
- v1.0 reference implementation in `pro-orc/` (Next.js) — superseded by Flutter rewrite
- Flutter app in `pro_orc/` directory
- Dashboard discovers 22+ projects across code/ and research/ directories
- Tech stack: Flutter 3.41.1 + Dart 3.x, Riverpod 3.x, Drift SQLite v2, tray_manager 0.5.2, window_manager 0.5.1
- n3urala1 dark theme: OKLCH→sRGB tokens, cyan primary, fuchsia accent, glassmorphism, animated orbs
- Distribution: DMG installer via create-dmg, Homebrew cask `robdewit/pro-orc/pro-orc`
- Known tech debt: withOpacity() in launch_dialog.dart:12, ~/.zshrc Flutter PATH

## Constraints

- **Tech Stack**: Flutter 3.x + Dart 3.x, macOS target only
- **Deployment**: Lokale macOS App (.app Bundle via DMG), kein App Store
- **Design**: n3urala1 Dark Mode Theme, kein Toggle
- **Datenquelle**: Filesystem + Git via dart:io / git CLI, Drift SQLite for config
- **Live Updates**: watcher package + Riverpod invalidation
- **Notion**: Nur ausgehende Links (url_launcher)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Notion-Link als `<!-- notion: URL -->` in PROJECT.md | Einfachste Integration, keine API nötig, leicht parsebar | ✓ Good — works reliably |
| Filesystem + Git als Datenquelle | Kein DB-Setup, Daten sind bereits da | ✓ Good — zero setup |
| Card Grid Layout | Bessere Übersicht als Liste/Kanban für <50 Projekte | ✓ Good — scales to 22+ projects |
| Auto-Erkennung Claude Tools | Kein manuelles Pflegen nötig | ✓ Good — discovers all tools from ~/.claude/ |
| Terminal.app für "Open in Terminal" | User-Präferenz, via `open -a Terminal` | ✓ Good |
| n3urala1 OKLCH dark theme | Cyan primary, fuchsia accent, glassmorphism | ✓ Good — distinctive aesthetic |
| Flutter macOS Rewrite statt inkrementelle Web-Features | Native Experience, Menubar, Performance; Flutter als Zukunftsbasis | ✓ Good — 8.9k LOC Dart, native menubar, ~1s live updates |
| Riverpod 3.x + FutureProvider + ref.listen | Watcher-driven invalidation, stateless reactive pattern | ✓ Good — clean separation |
| Drift SQLite for config/settings | Typed schema, migrations, in-memory testing | ✓ Good — enables per-project settings |
| runInShell: true on all Process.run | macOS GUI apps don't inherit Homebrew PATH | ✓ Good — essential for git/flutter CLI access |
| watcher package + StreamController.broadcast | Debounce, keepAlive, permanent internal subscription | ✓ Good — solves DirectoryWatcher.ready hang |
| Real temp git repos in tests (no mocking) | TDD with actual filesystem, mirrors production | ✓ Good — catches real integration issues |
| DMG + Homebrew cask distribution | create-dmg builds installer, cask formula for `brew install` | ✓ Good — professional distribution |

---
*Last updated: 2026-02-24 after v1.1 milestone complete*
