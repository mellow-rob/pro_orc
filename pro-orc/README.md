# Pro Orc — Next.js Application

The dashboard application for Project Orchestration.

## Development

```bash
npm install
npm run dev
```

Open [localhost:3000](http://localhost:3000).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server (Turbopack) |
| `npm run build` | Production build |
| `npm run start` | Start production server |
| `npm run lint` | ESLint |
| `npm run test` | Vitest tests |

## Architecture

```
app/
├── page.tsx              # Dashboard page (SSR)
├── layout.tsx            # Root layout
├── globals.css           # Tailwind + n3urala1 theme
├── actions.ts            # Server Actions (open Terminal/Finder)
└── api/
    ├── projects/[id]/    # Single project endpoint
    └── events/           # SSE endpoint for live updates

components/
├── codeProjectCard.tsx   # Card for code projects (git, GSD status)
├── researchProjectCard.tsx # Card for research projects
├── projectTabs.tsx       # Code / Research / Tools tab switching
├── toolsPanel.tsx        # Claude tools inventory
├── statusBadge.tsx       # GSD status badge
└── ui/                   # shadcn/ui primitives

hooks/
├── usePrivateProjects.ts # Client-side project filtering
└── useProjectEvents.ts   # SSE EventSource hook

lib/
├── scanner.ts            # Filesystem project discovery
├── parser.ts             # GSD/PROJECT.md parser
├── git-reader.ts         # Git metadata extraction (simple-git)
├── watcher.ts            # chokidar singleton watcher
├── tools-scanner.ts      # Claude tools discovery (~/.claude/)
├── paths.ts              # Base path configuration
├── types.ts              # TypeScript types
└── utils.ts              # Utility functions
```

## Stack

- Next.js 16 (App Router, Turbopack)
- React 19
- TypeScript 5
- Tailwind CSS v4 (OKLCH colors, dark mode)
- shadcn/ui
- simple-git
- chokidar v3 + SSE
- Vitest
