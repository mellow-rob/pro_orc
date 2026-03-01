# Milestones

## v1.0 MVP (Shipped: 2026-02-19)

**Phases completed:** 5 phases, 12 plans
**Lines of code:** 3,120 TypeScript/TSX/CSS
**Files:** 97 files changed, 27,071 insertions
**Timeline:** 2026-02-17 to 2026-02-19

**Key accomplishments:**
1. Next.js 16 + Tailwind v4 + shadcn/ui foundation with n3urala1 dark theme (OKLCH colors, glassmorphism)
2. Defensive filesystem parser + git reader with 5s timeouts and concurrent Promise.allSettled
3. Auto-scanning dashboard discovering 22+ projects from code/ and research/ directories
4. Real-time live updates via chokidar singleton watcher + SSE push (cards update in ~1s without reload)
5. Claude Tools inventory panel auto-discovering Skills, MCP servers, and Plugins from ~/.claude/
6. All 42 requirements satisfied (GIT-02 display gap fixed via quick task)

---


## v1.1 Flutter macOS Rewrite (Shipped: 2026-02-24)

**Phases completed:** 6 phases, 18 plans
**Lines of code:** 8,931 Dart
**Files:** 164 files changed, 26,979 insertions
**Timeline:** 2026-02-19 to 2026-02-23

**Key accomplishments:**
1. Native macOS menubar app with tray icon, show/hide window, geometry persistence, sandbox disabled
2. Pure Dart data layer: Drift SQLite, GSD parser (multi-level fallback), git reader with 5s timeouts
3. Reactive file watching via watcher package + Riverpod provider chain — live card updates in ~1s
4. n3urala1 dark theme: OKLCH tokens, animated orb background, glassmorphism cards, NavigationRail
5. Card widgets with GSD status badges, progress bars, quick actions (Terminal, Finder, GitHub, Notion)
6. Claude Tools tab auto-discovering Skills, Plugins, and MCP servers from ~/.claude/

---


## v1.2 Memory Indicator (Shipped: 2026-02-24)

**Phases completed:** 2 phases, 3 plans, 6 tasks
**Files:** 20 files changed, 459 insertions
**Timeline:** 2026-02-24 (single day)

**Key accomplishments:**
1. TDD-developed MemoryReader service with Claude path encoding and multi-strategy fuzzy matching
2. MemoryReader integrated into ProjectScanner pipeline with nullable MemoryData field pattern
3. Brain+zzz memory indicator on all project cards with 3 visual states (gray/violet/amber)
4. Clickable rem-sleep trigger via osascript Terminal automation (`claude /rem-sleep`)
5. Real-time memory status updates via watcher on `~/.claude/projects/` directory
6. New app icon deployed across DMG installer, Finder, and Homebrew cask

---


## v1.3 Project Creator (Shipped: 2026-02-26)

**Phases completed:** 3 phases (14-16), 5 plans
**Lines added:** +1,320 LOC Dart (total: 10,485 LOC)
**Files modified:** 6 (in pro_orc/lib/)
**Timeline:** 2 days (2026-02-24 → 2026-02-26)

**Key accomplishments:**
1. Ghost Add+ Karte with glassmorphism hover animation in Code (cyan) and Research (fuchsia) grids
2. Erstellungs-Dialog with TabBar, name→kebab-case derivation, full path preview, and configurable toggles
3. ProjectCreatorService: pure Dart filesystem scaffolding (directory, git init, GSD skeleton, CLAUDE.md, .gitignore)
4. Post-creation actions: Terminal/rem-sleep via osascript, DB projectType persistence, auto-rescan via provider invalidation
5. Notion via Claude MCP: Claude Code launches in Terminal with German prompt to create Notion page and write URL to PROJECT.md

---


## v1.4 Projekt-Loeschfunktion (Shipped: 2026-03-01)

**Phases completed:** 2 phases (17-18), 4 plans, 7 tasks
**Files:** 17 files changed, 1,931 insertions
**Timeline:** 1 day (2026-02-27)

**Key accomplishments:**
1. Pure Dart deleteProject service (rm -rf via Directory.delete recursive) for permanent filesystem deletion
2. GitHub-style DeleteProjectDialog requiring exact project name match before enabling delete button
3. "Projekt loeschen" context menu entry on both Code and Research cards with divider separator
4. ExternalResource model and detectExternalResources service detecting Notion, GitHub, Figma, Claude Memory, and other URLs
5. Step-by-step resource checkboxes with post-deletion cleanup summary showing full URIs and German hint text

---

