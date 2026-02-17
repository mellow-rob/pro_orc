# Feature Landscape

**Domain:** Local developer dashboard / project orchestration tool
**Researched:** 2026-02-17
**Confidence:** MEDIUM (training knowledge + project context; web search unavailable in this session)

---

## Table Stakes

Features users expect in any developer dashboard. Missing = product feels broken or useless.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Project list / card grid | Entry point to all projects; without it there's nothing to show | Low | Grid preferred over list for <50 items — scanning is faster |
| Project status at a glance | Core purpose of a dashboard; if you have to click into each project it's not a dashboard | Low | GSD phase + next step shown on card face |
| Last activity indicator | Developers want to know "what was touched recently" without opening a terminal | Low | Git last commit timestamp; fallback to file mtime for non-git projects |
| Auto-discovery of projects | Manual registration is a maintenance burden that breaks trust | Medium | Walk two scan paths; no config per project needed |
| Filesystem-as-source-of-truth | Dev tools that require a separate DB feel heavy and fragile | Medium | .planning/ STATE.md / ROADMAP.md are the authoritative records |
| Live / real-time updates | A dashboard that requires F5 to refresh feels 10 years old | Medium | SSE + chokidar; without this the data is stale the moment you start a phase |
| Git integration | Every serious project has git; showing branch + last commit is zero-surprise | Medium | Last commit message, SHA, relative timestamp — not a full git log |
| Dark mode | Developer tool default; a bright white dashboard on a dark terminal setup is jarring | Low | First-class, not a toggle — just build dark |
| Responsive within the browser | Even localhost-only, the window may be resized; cards must reflow | Low | CSS grid with min-width columns handles this automatically |
| Fast initial load | If it takes >2s to show content, users stop opening it | Medium | No DB round-trips; filesystem reads at startup are the bottleneck |

---

## Differentiators

Features that make Pro Orc genuinely useful beyond "another project list". Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| GSD workflow phase display | Shows exactly where each project is in a defined workflow (Research → Plan → Build → Ship) — not just "in progress" | Medium | Reads .planning/STATE.md; maps phase names to visual indicators |
| Next step per project | Surfaces the literal next action, eliminating "what was I doing?" on project switch | Medium | Parsed from ROADMAP.md or STATE.md; reduces context-switch cost dramatically |
| Dual-card-type rendering | Code projects (git metrics) vs Research projects (no git, different metadata) look and behave differently | Medium | Research folder gets its own card layout without git noise |
| Claude Tools inventory | Unique to this workflow: surfaces which AI tools (Skills, MCP servers, Plugins) are available in the current environment | Medium | Reads ~/.claude/ directory; no other developer dashboard does this |
| MCP server / plugin type tagging | Shows not just that a tool exists, but what kind it is and what it does — instantly actionable | Low | Name + type + description displayed; derived from config files |
| Quick action: Open in Terminal | Eliminates "cd ~/path/to/project" — the most common friction in project switching | Low | macOS `open -a Terminal [path]`; feels instant |
| Quick action: Open in Finder | Faster than Spotlight for known project locations; useful for non-code assets | Low | `open [path]`; trivial to implement but frequently appreciated |
| Quick action: Open in Notion | Bridges local state with external notes/docs in one click | Low | Parses `<!-- notion: URL -->` comment from PROJECT.md header |
| Notion URL auto-discovery | No manual URL config per project — the URL lives in the project file itself | Low | Regex parse of HTML comment; low implementation cost, high trust |
| Phase progress bar / indicator | Visual percentage of roadmap milestones completed communicates progress faster than text | Medium | Count completed phases in ROADMAP.md; simple checkbox counting |
| chokidar singleton watcher | SSE without polling; zero CPU when nothing changes | Medium | instrumentation.ts singleton prevents duplicate watchers on hot reload |

---

## Anti-Features

Features to explicitly NOT build in v1. Each one is a scope trap.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-device / network access | Adds auth, CORS, TLS — none of which are useful for a single-user local tool | Stay on localhost:3000; the constraint is a feature |
| User accounts / authentication | Zero users beyond the machine owner; auth adds complexity with no payoff | No auth. Period. |
| Database (PostgreSQL, SQLite, etc.) | The filesystem IS the database; adding a DB creates sync problems, migration risk, and setup overhead | Read .planning/ files directly; git provides history |
| Manual project registration | Forces ongoing maintenance; breaks "just works" experience | Auto-scan only; directories are the config |
| Project editing in the UI | Pro Orc is a read window, not an editor; editing belongs in the IDE | Read-only everywhere; link out to Finder/Terminal for editing |
| Push notifications / alerts | No persistent background process warranted for a single-user dashboard | SSE in the open tab is sufficient; don't add complexity |
| Plugin / extension system | Over-engineering for a personal tool with known, stable feature scope | Hard-code the features; plugin systems require API design, versioning, docs |
| Full-text search across project files | Overkill for <50 projects; Spotlight already does this better | Client-side filter by project name is sufficient for this scale |
| Light mode / theme toggle | Doubles CSS surface area in v1 for near-zero gain in a developer tool | Dark mode only; add toggle in v2 if requested |
| Triggering GSD commands from the UI | Adds shell execution, error handling, output display — a separate feature set | Link out to Terminal; GSD commands stay in the terminal workflow |
| Inline PROJECT.md / REQUIREMENTS.md preview | Markdown rendering adds deps (remark/rehype) and UI real estate for data already surfaced on the card | Surface key fields on card; link to Finder for full file |
| Notion API read/write | Requires OAuth, token management, rate limiting — for a localhost tool this is disproportionate | Outbound link only; Notion manages its own data |
| iTerm / Warp / Ghostty terminal support | Multiple terminal targets require detection logic and edge case handling | Terminal.app only via `open -a Terminal`; user-switchable in v2 |

---

## Feature Dependencies

```
Auto-scan (path walk)
  → Project card rendering (needs discovered projects)
    → GSD phase display (needs .planning/STATE.md per project)
    → Next step display (needs .planning/ROADMAP.md or STATE.md)
    → Git last activity (needs git repo detection + simple-git call)
    → Notion link extraction (needs PROJECT.md parse per project)
    → Quick actions (needs resolved project path)
      → Open in Terminal (path)
      → Open in Finder (path)
      → Open in Notion (URL from PROJECT.md)

chokidar singleton watcher (instrumentation.ts)
  → SSE route handler (ReadableStream)
    → Live card updates in browser (EventSource in client)

Claude Tools inventory
  → ~/.claude/ directory scan
    → Skills display (name, description)
    → MCP server display (name, type, description)
    → Plugin display (name, type, description)

Research project card type
  → Auto-scan (needs "project research/" path separate from "code/")
  → Separate card layout (no git section, different metadata shown)
```

---

## MVP Recommendation

**Prioritize — must ship to have a working dashboard:**

1. Auto-scan both directories (code/ and project research/)
2. Card grid with project name, GSD phase, next step, last activity
3. Git integration (last commit + timestamp, with concurrent limits + timeout)
4. Live updates via chokidar + SSE
5. Research project card variant (no git metrics)
6. Quick actions: Terminal, Finder, Notion link extraction

**Prioritize — adds immediate daily-use value at low cost:**

7. Claude Tools inventory (Skills, MCP servers, Plugins)
8. Phase progress indicator (checkbox counting in ROADMAP.md)

**Defer to v2 (do not include in v1 scope):**

- Light mode toggle
- Inline markdown preview
- Notion API integration (read/write)
- Triggering GSD commands from UI
- Multi-terminal support
- Any editing capability in the UI

---

## Comparable Tools in the Ecosystem

These tools inform what "table stakes" means for developer dashboards. Pro Orc is deliberately narrower and more opinionated.

| Tool | What it does well | Why Pro Orc doesn't copy it |
|------|-------------------|----------------------------|
| Portainer | Container/service status dashboard | Oriented around running processes, not project files |
| LinearB / Waydev | Git analytics for teams | Cloud, multi-user, no local filesystem awareness |
| Backstage (Spotify) | Internal developer portal | Massive setup cost, plugin-oriented, team-scale problem |
| Raycast / Alfred | Launcher + project switcher | No dashboard view, no GSD-awareness, no live updates |
| VS Code "Remote Repositories" | Browse project files | IDE, not a status dashboard |
| custom tmux dashboards | Terminal-native project switching | No visual progress, no phase awareness, no web UI |

Pro Orc's differentiation: **GSD workflow-awareness + Claude tool inventory + localhost-first simplicity**. No comparable tool combines these three.

---

## Sources

- Project context: `/Users/rob/project_orchestration/.planning/PROJECT.md` (HIGH confidence — primary source)
- Domain knowledge: Developer tooling ecosystem (MEDIUM confidence — training data, 2025 cutoff)
- Comparable tools section: Training data on ecosystem tools (MEDIUM confidence)
- Note: Web search was unavailable in this session; ecosystem claims should be treated as MEDIUM confidence and validated against current tooling landscape
