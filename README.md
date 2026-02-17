# Pro Orc — Project Orchestration Dashboard

Local Next.js dashboard that scans `~/project_orchestration/` and displays all projects at a glance — GSD status, phase progress, git activity, and quick actions.

## What it does

- **Auto-scans** `code/` and `project research/` subdirectories
- **Parses GSD data** from `.planning/` files (STATE.md, ROADMAP.md, PROJECT.md)
- **Reads git history** for code projects (last commit, branch, dirty state, GitHub URL)
- **Extracts descriptions** from PROJECT.md or CLAUDE.md
- **Links to Notion** via `<!-- notion: URL -->` comments in PROJECT.md
- **Quick actions**: Open in Terminal, Finder, GitHub, Notion

## Stack

- **Next.js 16** (App Router, Turbopack)
- **Tailwind CSS v4** (OKLCH colors, dark mode)
- **shadcn/ui** (Card, Badge, Button, Progress, Tabs)
- **simple-git** for git data extraction
- **chokidar** for filesystem watching (planned)

## Getting started

```bash
cd pro-orc
npm install
npm run dev
```

Open [localhost:3000](http://localhost:3000).

## Project structure

```
.planning/          # GSD workflow files (roadmap, state, phases)
pro-orc/            # Next.js application
├── app/            # App Router pages & API routes
├── components/     # UI components (cards, tabs, badges)
├── hooks/          # Client-side hooks (usePrivateProjects)
├── lib/            # Server-side logic (scanner, parser, git-reader)
└── public/         # Static assets
```

## Branching

| Branch | Purpose |
|--------|---------|
| `main` | Stable, working state. All GSD phases merge here. |
| `dev` | Integration branch for in-progress work. |
| `feature/<name>` | Feature branches off `dev` for new capabilities. |
| `fix/<name>` | Bugfix branches off `main` for hotfixes. |

**Flow:** `feature/*` → `dev` → `main`

## GSD Workflow

This project uses the [GSD (Get Shit Done)](https://github.com/coleam00/get-shit-done) framework for planning and execution. Phase artifacts live in `.planning/`.

## License

Private project — not licensed for distribution.
