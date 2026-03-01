<!-- notion: https://www.notion.so/30af1cbe281e807e8484d8c1f11a1944 -->
# Pro Orc — Project Orchestration Dashboard

## What This Is

Native macOS Flutter-App als persoenliches Projekt-Management Dashboard. Scannt automatisch Projektordner, zeigt GSD-Status und Fortschritt pro Projekt, listet installierte Claude Code Tools auf, und bietet Quick Actions zum Oeffnen in Terminal/Finder/Notion/GitHub. Neue Projekte koennen direkt aus dem Dashboard erstellt werden — mit konfigurierbaren Toggles fuer git init, GSD skeleton, CLAUDE.md, .gitignore und Notion-Seiten-Erstellung via Claude MCP. Menubar-Icon + Hauptfenster, Echtzeit File-Watching via dart:io/watcher. Nur lokal, kein Netzwerk, kein Auth — ein Single-User Power-Dashboard.

## Core Value

Auf einen Blick sehen, wo jedes Projekt steht, was der naechste Schritt ist, und welche Tools zur Verfuegung stehen — ohne Terminal-Hopping oder Notion-Suche.

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
- ✓ Memory-Status-Erkennung pro Projekt (Existenz + mtime von MEMORY.md) — v1.2
- ✓ Brain+zzz Memory Indicator auf Project Cards (konsolidiert/nicht vorhanden/stale) — v1.2
- ✓ Quick Action: rem-sleep im Terminal triggern via osascript — v1.2
- ✓ Add+ Karte im Code- und Research-Tab Grid mit Ghost-Style und Hover-Animation — v1.3
- ✓ Erstellungs-Dialog mit Code/Research Tab-Switcher, Toggles, kebab-case Name und Pfad-Vorschau — v1.3
- ✓ Projekt-Erstellung: Ordner + git init + GSD skeleton + CLAUDE.md + .gitignore — v1.3
- ✓ Post-Creation Actions: Terminal oeffnen, rem-sleep ausfuehren, Projekt erscheint automatisch im Tab — v1.3
- ✓ Notion-Seiten-Erstellung via Claude MCP (kein eigener API Key noetig) — v1.3
- ✓ Rechtsklick-Kontextmenue "Projekt loeschen" auf Code- und Research-Cards — v1.4
- ✓ Bestaetigungsdialog mit Projektname-Eingabe (GitHub-Style) vor permanentem Loeschen — v1.4
- ✓ Permanentes Loeschen (rm -rf) mit automatischem Dashboard-Refresh — v1.4
- ✓ Erkennung externer Ressourcen (Notion, GitHub, Figma, Claude Memory, URLs) im Loeschdialog — v1.4
- ✓ Schrittweise Einzelabfrage pro erkannter Ressource mit Cleanup-Hinweisen — v1.4

### Active

(Keine — bereit fuer naechsten Milestone)

### Out of Scope

- Multi-device / Netzwerk — nur localhost
- User Accounts / Auth — Single User
- Manuelle Projektverwaltung — Auto-scan only
- Projekt-Editing in UI — Read-only Dashboard
- Notifications — Live updates in open tab reichen
- Plugin System — Over-engineering
- App Store Distribution — Sandbox-Anforderungen zu restriktiv fuer Filesystem-Zugriff
- Light Mode — n3urala1 Theme ist intentional dark-only
- Auto-Update — Single-Developer Tool, `git pull && flutter build macos` reicht
- Cloud Sync — Nur lokaler Filesystem-Zugriff, kein Remote
- Notion API Read/Write — Nur Seiten-Erstellung via Claude MCP, kein vollstaendiger Sync

## Context

- v1.0 shipped as Next.js web app: 3,120 LOC TypeScript/TSX/CSS, 97 files (2026-02-19)
- v1.1 shipped as native macOS Flutter app: 8,931 LOC Dart, 164 files (2026-02-23)
- v1.2 shipped Memory Indicator: +459 LOC Dart, 20 files changed (2026-02-24)
- v1.3 shipped Project Creator: +1,320 LOC Dart, 6 files changed (2026-02-26)
- v1.4 shipped Projekt-Loeschfunktion: +1,931 LOC Dart, 17 files changed (2026-02-27)
- v1.0 reference implementation in `pro-orc/` (Next.js) — superseded by Flutter rewrite
- Flutter app in `pro_orc/` directory — ~12,400 LOC Dart
- Dashboard discovers 22+ projects across code/ and research/ directories
- Tech stack: Flutter 3.41.1 + Dart 3.x, Riverpod 3.x, Drift SQLite v2, tray_manager 0.5.2, window_manager 0.5.1
- n3urala1 dark theme: OKLCH→sRGB tokens, cyan primary, fuchsia accent, glassmorphism, animated orbs
- Distribution: DMG installer via create-dmg, Homebrew cask `mellow-rob/tap/pro-orc`
- Claude memory detection via multi-strategy path matching (exact + fuzzy with length constraint)
- Known tech debt: withOpacity() in launch_dialog.dart:12, ~/.zshrc Flutter PATH

## Constraints

- **Tech Stack**: Flutter 3.x + Dart 3.x, macOS target only
- **Deployment**: Lokale macOS App (.app Bundle via DMG), kein App Store
- **Design**: n3urala1 Dark Mode Theme, kein Toggle
- **Datenquelle**: Filesystem + Git via dart:io / git CLI, Drift SQLite for config
- **Live Updates**: watcher package + Riverpod invalidation
- **Notion**: Seiten-Erstellung via Claude MCP, ausgehende Links via url_launcher

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Notion-Link als `<!-- notion: URL -->` in PROJECT.md | Einfachste Integration, keine API noetig, leicht parsebar | ✓ Good — works reliably |
| Filesystem + Git als Datenquelle | Kein DB-Setup, Daten sind bereits da | ✓ Good — zero setup |
| Card Grid Layout | Bessere Uebersicht als Liste/Kanban fuer <50 Projekte | ✓ Good — scales to 22+ projects |
| Auto-Erkennung Claude Tools | Kein manuelles Pflegen noetig | ✓ Good — discovers all tools from ~/.claude/ |
| Terminal.app fuer "Open in Terminal" | User-Praeferenz, via `open -a Terminal` | ✓ Good |
| n3urala1 OKLCH dark theme | Cyan primary, fuchsia accent, glassmorphism | ✓ Good — distinctive aesthetic |
| Flutter macOS Rewrite statt inkrementelle Web-Features | Native Experience, Menubar, Performance; Flutter als Zukunftsbasis | ✓ Good — 10.5k LOC Dart, native menubar, ~1s live updates |
| Riverpod 3.x + FutureProvider + ref.listen | Watcher-driven invalidation, stateless reactive pattern | ✓ Good — clean separation |
| Drift SQLite for config/settings | Typed schema, migrations, in-memory testing | ✓ Good — enables per-project settings + projectType persistence |
| runInShell: true on all Process.run | macOS GUI apps don't inherit Homebrew PATH | ✓ Good — essential for git/flutter CLI access |
| watcher package + StreamController.broadcast | Debounce, keepAlive, permanent internal subscription | ✓ Good — solves DirectoryWatcher.ready hang |
| Real temp git repos in tests (no mocking) | TDD with actual filesystem, mirrors production | ✓ Good — catches real integration issues |
| DMG + Homebrew cask distribution | create-dmg builds installer, cask formula for `brew install` | ✓ Good — professional distribution |
| Sync file ops for memory check | Not hot path, per-project check, simpler code | ✓ Good — no async overhead |
| Multi-strategy memory path matching | Claude encodes paths inconsistently (/ and _ both become -) | ✓ Good — handles all edge cases |
| Brain+zzz icon for memory indicator | User preferred over bookMarked, more intuitive for "sleeping memory" | ✓ Good — clear visual metaphor |
| osascript Terminal automation for rem-sleep | `tell Terminal to do script "cd X && claude /rem-sleep"` | ✓ Good — one-click execution |
| Watch ~/.claude/projects/ for memory changes | Real-time updates when rem-sleep runs in another terminal | ✓ Good — instant feedback |
| Ghost Add+ Card (reduced alpha, no label) | Clean minimal look, visually distinct from project cards | ✓ Good — intuitive "add more" affordance |
| Dialog pops with action flags, tabs execute | Avoids mounted/lifecycle issues in dialog context | ✓ Good — reliable post-creation actions |
| DB projectType persistence for new projects | Bypasses _inferType heuristic for empty directories | ✓ Good — correct tab classification immediately |
| osascript without runInShell for Terminal commands | Reliable quoting for complex shell commands with special chars | ✓ Good — handles German text in prompts |
| Notion via Claude MCP statt eigener API Key | Claude hat bereits MCP-Verbindung; kein Key-Management noetig | ✓ Good — zero-config Notion integration |
| Top-level deleteProject function (no class) | Matches memory_reader/git_reader pattern | ✓ Good — consistent service pattern |
| DeleteProjectDialog owns deletion side effects | Card is thin showDialog caller; dialog calls deleteProject + invalidate | ✓ Good — clear ownership |
| GitHub-style name confirmation | User types exact project name before delete button enables | ✓ Good — prevents accidental deletion |
| Resource checkboxes unchecked by default | User must explicitly opt-in per CLN-05; no auto-deletion | ✓ Good — safe by default |
| Post-deletion summary replaces dialog body in-place | _showSummary flag avoids push/pop navigation complexity | ✓ Good — simple state toggle |
| encodeProjectPath reuse for Claude Memory detection | Exact-path only, no fuzzy scan needed for existence check | ✓ Good — simpler and sufficient |

---
*Last updated: 2026-03-01 after v1.4 Projekt-Loeschfunktion milestone*
