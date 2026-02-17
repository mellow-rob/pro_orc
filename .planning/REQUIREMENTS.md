# Requirements: Pro Orc

**Defined:** 2026-02-17
**Core Value:** Auf einen Blick sehen, wo jedes Projekt steht, was der nächste Schritt ist, und welche Tools zur Verfügung stehen — ohne Terminal-Hopping oder Notion-Suche.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Dashboard

- [ ] **DASH-01**: User sees a card-grid layout showing all discovered projects
- [ ] **DASH-02**: Each project card displays project name and GSD status badge
- [ ] **DASH-03**: Each project card shows current GSD phase and progress indicator (e.g. "Phase 3/5")
- [ ] **DASH-04**: Each project card shows last-activity timestamp from git log
- [ ] **DASH-05**: Each project card shows next step extracted from STATE.md / ROADMAP.md
- [ ] **DASH-06**: Dashboard uses dark mode design (dark-first, no toggle in v1)
- [ ] **DASH-07**: Each project card shows roadmap progress bar (completed / total phases)
- [ ] **DASH-08**: Projects inactive for 30+ days are visually marked as stale

### Filesystem & Scanning

- [ ] **SCAN-01**: App auto-scans `~/project_orchestration/code/` for projects
- [ ] **SCAN-02**: App auto-scans `~/project_orchestration/project research/` for projects
- [ ] **SCAN-03**: App automatically detects project type (code vs research)
- [ ] **SCAN-04**: App parses `.planning/STATE.md` to extract current phase and next step
- [ ] **SCAN-05**: App parses `.planning/ROADMAP.md` to extract phase structure and progress
- [ ] **SCAN-06**: App parses `.planning/PROJECT.md` to extract project name and Notion URL
- [ ] **SCAN-07**: App handles missing `.planning/` directory gracefully (no crash, shows "no GSD data")
- [ ] **SCAN-08**: App handles malformed or mid-save files gracefully (no crash, uses last good state)

### Live Updates

- [ ] **LIVE-01**: chokidar filesystem watcher monitors `.planning/` changes across all projects
- [ ] **LIVE-02**: Watcher runs as singleton (via `instrumentation.ts` on `globalThis`, not per-request)
- [ ] **LIVE-03**: Watcher excludes `node_modules/`, `.git/`, `.next/`
- [ ] **LIVE-04**: SSE push delivers change events via ReadableStream route handler
- [ ] **LIVE-05**: Affected project card updates without full page reload
- [ ] **LIVE-06**: Watcher events are debounced (300ms)

### Git Integration

- [ ] **GIT-01**: App shows last commit timestamp per project (async, non-blocking)
- [ ] **GIT-02**: App shows last commit message per project
- [ ] **GIT-03**: Git calls run concurrently via Promise.allSettled
- [ ] **GIT-04**: Git calls have explicit 5s timeout
- [ ] **GIT-05**: Non-git directories are handled gracefully (no error, no git metrics shown)

### Actions

- [ ] **ACT-01**: User can click "Open in Terminal" to open project folder in Terminal.app
- [ ] **ACT-02**: User can click "Open in Finder" to open project folder in Finder
- [ ] **ACT-03**: User can click "Open Notion Page" for research projects with Notion URL
- [ ] **ACT-04**: Notion URL is extracted from `<!-- notion: URL -->` convention in PROJECT.md

### Research Projects

- [ ] **RSRCH-01**: Research projects display in a distinct card layout (no git metrics)
- [ ] **RSRCH-02**: Research card shows project name, GSD status, and direct Notion page link
- [ ] **RSRCH-03**: Research cards do not show git-based timestamps or commit info

### Claude Tools Inventory

- [ ] **TOOL-01**: App auto-scans `~/.claude/` for installed skills (name, type, description)
- [ ] **TOOL-02**: App auto-scans for configured MCP servers (name, type, description)
- [ ] **TOOL-03**: App auto-scans for installed plugins (name, type, description)
- [ ] **TOOL-04**: Tools are displayed in a dedicated panel/section in the dashboard

### Infrastructure

- [ ] **INFRA-01**: App binds to localhost:3000 only (no network binding)
- [ ] **INFRA-02**: No authentication required
- [ ] **INFRA-03**: No database — filesystem + git are the only data sources
- [ ] **INFRA-04**: All paths resolved via `os.homedir()` (never hardcoded)

## v2 Requirements

### Extended Features

- **EXT-01**: GSD-Befehle aus der App auslösen
- **EXT-02**: Light Mode / Theme Toggle
- **EXT-03**: Inline Preview von PROJECT.md / REQUIREMENTS.md
- **EXT-04**: Notion API Integration (Read/Write)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-device / Netzwerk | Nur localhost |
| User Accounts / Auth | Single User |
| Datenbank | Filesystem IS the database |
| Manuelle Projektverwaltung | Auto-scan only |
| Projekt-Editing in UI | Read-only Dashboard |
| Notifications | Live updates in open tab reichen |
| Plugin System | Over-engineering |
| Full-text Search | Client-side Filter reicht für <50 Projekte |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Pending |
| INFRA-04 | Phase 1 | Pending |
| DASH-06 | Phase 1 | Pending |
| SCAN-01 | Phase 2 | Pending |
| SCAN-02 | Phase 2 | Pending |
| SCAN-03 | Phase 2 | Pending |
| SCAN-04 | Phase 2 | Pending |
| SCAN-05 | Phase 2 | Pending |
| SCAN-06 | Phase 2 | Pending |
| SCAN-07 | Phase 2 | Pending |
| SCAN-08 | Phase 2 | Pending |
| GIT-01 | Phase 2 | Pending |
| GIT-02 | Phase 2 | Pending |
| GIT-03 | Phase 2 | Pending |
| GIT-04 | Phase 2 | Pending |
| GIT-05 | Phase 2 | Pending |
| DASH-01 | Phase 3 | Pending |
| DASH-02 | Phase 3 | Pending |
| DASH-03 | Phase 3 | Pending |
| DASH-04 | Phase 3 | Pending |
| DASH-05 | Phase 3 | Pending |
| DASH-07 | Phase 3 | Pending |
| DASH-08 | Phase 3 | Pending |
| ACT-01 | Phase 3 | Pending |
| ACT-02 | Phase 3 | Pending |
| ACT-03 | Phase 3 | Pending |
| ACT-04 | Phase 3 | Pending |
| RSRCH-01 | Phase 3 | Pending |
| RSRCH-02 | Phase 3 | Pending |
| RSRCH-03 | Phase 3 | Pending |
| LIVE-01 | Phase 4 | Pending |
| LIVE-02 | Phase 4 | Pending |
| LIVE-03 | Phase 4 | Pending |
| LIVE-04 | Phase 4 | Pending |
| LIVE-05 | Phase 4 | Pending |
| LIVE-06 | Phase 4 | Pending |
| TOOL-01 | Phase 5 | Pending |
| TOOL-02 | Phase 5 | Pending |
| TOOL-03 | Phase 5 | Pending |
| TOOL-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 42 total
- Mapped to phases: 42
- Unmapped: 0

---
*Requirements defined: 2026-02-17*
*Last updated: 2026-02-17 after roadmap creation — traceability complete*
