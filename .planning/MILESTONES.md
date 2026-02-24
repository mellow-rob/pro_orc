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

