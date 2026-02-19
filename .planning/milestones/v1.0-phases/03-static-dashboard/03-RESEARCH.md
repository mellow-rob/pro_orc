# Phase 3: Static Dashboard - Research

**Researched:** 2026-02-17
**Domain:** Next.js 16 App Router — async Server Components, Route Handlers, Server Actions, React 19 Client Components, macOS system integration via `child_process.exec`
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DASH-01 | User sees a card-grid layout showing all discovered projects | Async Server Component calls `scanProjects()` directly; grid is CSS grid via Tailwind. No API round-trip needed for initial render. |
| DASH-02 | Each project card displays project name and GSD status badge | `BaseProject.name` + `BaseProject.gsdStatus` fields from Phase 2. shadcn `Badge` component, `variant="outline"` styled per status via `cn()`. |
| DASH-03 | Each project card shows current GSD phase and progress indicator (e.g. "Phase 3/5") | `BaseProject.currentPhase` string rendered as text. `phaseProgress` (0-100) drives shadcn `Progress` component. |
| DASH-04 | Each project card shows last-activity timestamp from git log | `CodeProject.lastCommitTimestamp` (ISO 8601 string from `git.log()`). Format with `Intl.RelativeTimeFormat` or `Date` in a client component or via Server Component string formatting. |
| DASH-05 | Each project card shows next step extracted from STATE.md / ROADMAP.md | `BaseProject.nextStep` string. Rendered as text, truncated if long. |
| DASH-07 | Each project card shows roadmap progress bar (completed / total phases) | Same `phaseProgress` field as DASH-03. shadcn `Progress` with `value={project.phaseProgress}`. |
| DASH-08 | Projects inactive for 30+ days are visually marked as stale | Compare `lastCommitTimestamp` to `Date.now()`. 30 days = 2,592,000,000 ms. If `Date.now() - new Date(ts).getTime() > 30 * 24 * 60 * 60 * 1000` → apply stale styling (amber badge or border). |
| ACT-01 | User can click "Open in Terminal" to open project folder in Terminal.app | Server Action calls `exec('open -a Terminal "${path}"')`. Button in client component calls the action. |
| ACT-02 | User can click "Open in Finder" to open project folder in Finder | Server Action calls `exec('open "${path}"')` — `open` with a directory defaults to Finder. |
| ACT-03 | User can click "Open Notion Page" for research projects with Notion URL | Server Action calls `exec('open "${url}"')` — `open` with a URL opens in default browser. OR: render as an `<a href>` since it's a plain URL. |
| ACT-04 | Notion URL is extracted from `<!-- notion: URL -->` convention in PROJECT.md | Already done in Phase 2 parser (`parseProject()` in `lib/parser.ts`). No new code needed — `project.notionUrl` is populated. |
| RSRCH-01 | Research projects display in a distinct card layout (no git metrics) | `isResearchProject(p)` type guard from `lib/types.ts`. Render `researchProjectCard.tsx` component instead of `codeProjectCard.tsx`. |
| RSRCH-02 | Research card shows project name, GSD status, and direct Notion page link | `ResearchProject.name`, `.gsdStatus`, `.notionUrl`. Notion link as `<a>` or Server Action. |
| RSRCH-03 | Research cards do not show git-based timestamps or commit info | `ResearchProject` has no git fields by design (Phase 1 types). Simply don't render those fields in the research card component. |
</phase_requirements>

---

## Summary

Phase 3 builds a static read-only dashboard at localhost:3000 using Next.js 16's async Server Component model. The page calls `scanProjects()` directly (no fetch to an API route) and passes `Project[]` data down to client components for interactivity. Two card variants — `codeProjectCard.tsx` and `researchProjectCard.tsx` — render the appropriate fields for each project type, discriminated by the `type` field and `isCodeProject`/`isResearchProject` type guards from Phase 2.

The "quick actions" (Open in Terminal, Open in Finder, Open Notion Page) require running macOS system commands — not possible from a browser. The correct pattern is a Next.js Server Action in a `lib/actions.ts` file. Client components call the action directly (no form submission needed for button clicks using `startTransition`). The macOS `open` command handles all three cases: `open -a Terminal` for Terminal, `open <path>` for Finder, and `open <url>` for the browser. `child_process.exec` is a Node.js built-in and does NOT require adding to `serverExternalPackages`.

The stale detection for DASH-08 is pure arithmetic: compare `lastCommitTimestamp` (ISO 8601 from git) to the current time. If the gap exceeds 30 days, apply a visual indicator — an amber "Stale" badge or amber border — via conditional CSS classes using `cn()`.

**Primary recommendation:** Page component is an async Server Component that calls `scanProjects()` directly. Card components are `'use client'` only if they need onClick handlers for actions. Use a thin Server Component → Client Component boundary: Server Component fetches data, passes serializable `Project` objects as props to client card components.

---

## Standard Stack

### Core (all already installed — no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Next.js App Router | 16.1.6 (installed) | Async Server Components, Server Actions, Route Handlers | Already configured; `serverExternalPackages` set for chokidar/simple-git |
| React | 19.2.3 (installed) | `'use client'` components, `useTransition`/`startTransition` for action calls | Already installed |
| `child_process` (Node built-in) | Node 20+ | Execute `open` commands for Terminal/Finder/browser | Built-in, no bundler config needed |
| shadcn/ui | 3.8.5 (installed) | Card, Badge, Button, Progress, Tooltip, Separator components | All already installed via Phase 1 |
| lucide-react | 0.572.0 (installed) | Icons: Terminal, Folder, ExternalLink, Clock, BookOpen, AlertCircle, Activity | Already installed; all needed icons confirmed present |
| `cn()` from `@/lib/utils` | installed | Conditional className composition | Already in `lib/utils.ts` |
| `isCodeProject`/`isResearchProject` | from `@/lib/types` | Type narrowing in card components | Already in `lib/types.ts` |

### Installed shadcn Components (from Phase 1)

All components are in `/pro-orc/components/ui/`:

| Component | File | Key Props |
|-----------|------|-----------|
| `Card`, `CardHeader`, `CardTitle`, `CardContent`, `CardFooter`, `CardAction`, `CardDescription` | `card.tsx` | `className` for overrides |
| `Badge` | `badge.tsx` | `variant`: `default`, `secondary`, `destructive`, `outline`, `ghost`, `link` |
| `Button` | `button.tsx` | `variant`: `default`, `outline`, `ghost`, `secondary`, `destructive`, `link`; `size`: `xs`, `sm`, `default`, `lg`, `icon` |
| `Progress` | `progress.tsx` | `value` (0-100) — **is `'use client'`** (uses Radix) |
| `Tooltip`, `TooltipProvider`, `TooltipTrigger`, `TooltipContent` | `tooltip.tsx` | `delayDuration` default 0 — **is `'use client'`** |
| `Separator` | `separator.tsx` | `orientation`: `horizontal` (default), `vertical` |

### Installed CSS Utilities (from Phase 1 globals.css)

| Class | Effect | Use For |
|-------|--------|---------|
| `glow-cyan` | `box-shadow: 0 0 20px oklch(0.715 0.143 212.34 / 0.15)` | Code project card hover |
| `glow-fuchsia` | `box-shadow: 0 0 20px oklch(0.70 0.22 320.08 / 0.15)` | Research project card hover |
| `bg-orb-cyan` | Blurred cyan orb | Background atmospheric effect (already in page.tsx) |
| `bg-orb-fuchsia` | Blurred fuchsia orb | Background atmospheric effect (already in page.tsx) |

### CSS Variables (active dark theme in globals.css)

| Variable | Value | Use |
|----------|-------|-----|
| `--background` | `oklch(0.11 0.02 264)` | Body background |
| `--card` | `oklch(0.18 0.015 264 / 0.6)` | Card background — glassmorphism, 60% opacity |
| `--primary` | `oklch(0.715 0.143 212.34)` = Cyan | Code project actions, progress bar, primary buttons |
| `--accent` | `oklch(0.70 0.22 320.08)` = Fuchsia | Research project highlights |
| `--muted-foreground` | `oklch(0.62 0.01 264)` | Secondary text, timestamps |
| `--border` | `oklch(1 0 0 / 0.05)` | Subtle card borders |

### No New Dependencies Needed

```bash
# Nothing to install — everything is already in package.json
```

---

## Architecture Patterns

### Recommended File Structure

```
pro-orc/
├── app/
│   ├── page.tsx                    # REPLACE: async Server Component, calls scanProjects() directly
│   ├── actions.ts                  # NEW: Server Actions for Terminal/Finder/browser open
│   ├── globals.css                 # UNCHANGED: dark theme, glow utilities
│   └── layout.tsx                  # UNCHANGED: Inter + JetBrains Mono, dark class
├── components/
│   ├── ui/                         # UNCHANGED: shadcn components
│   ├── codeProjectCard.tsx         # NEW: 'use client', renders CodeProject, calls actions
│   └── researchProjectCard.tsx     # NEW: 'use client', renders ResearchProject, Notion link
└── lib/
    ├── types.ts                    # UNCHANGED: Project, CodeProject, ResearchProject
    ├── scanner.ts                  # UNCHANGED: scanProjects()
    ├── parser.ts                   # UNCHANGED: parseGsdData()
    ├── git-reader.ts               # UNCHANGED: getGitData()
    └── paths.ts                    # UNCHANGED: PATHS, planningDir
```

**Note on camelCase convention (from Phase 1 CONTEXT.md):** All new files use camelCase — `codeProjectCard.tsx`, `researchProjectCard.tsx`, `actions.ts`.

### Pattern 1: Async Server Component Data Fetching (DASH-01)

**What:** `page.tsx` is an async Server Component. It calls `scanProjects()` directly — no fetch to an API route. Data never crosses the network. The server renders HTML with all project data baked in.

**Why direct import not API route:** This is a localhost app with no caching requirements. Direct function call is simpler, faster, and avoids the serialization/deserialization cycle. An API route (`/api/projects`) would be useful for Phase 4's live updates (SSE), but Phase 3 doesn't need it.

**When to use:** Any time a Server Component needs data from a server-only module.

```typescript
// app/page.tsx
import { scanProjects } from '@/lib/scanner'
import { isCodeProject, isResearchProject } from '@/lib/types'
import { CodeProjectCard } from '@/components/codeProjectCard'
import { ResearchProjectCard } from '@/components/researchProjectCard'

export default async function DashboardPage() {
  const projects = await scanProjects()

  const codeProjects = projects.filter(isCodeProject)
  const researchProjects = projects.filter(isResearchProject)

  return (
    <main className="relative min-h-screen overflow-hidden">
      {/* Atmospheric orbs already in Phase 1 placeholder — keep them */}
      <div aria-hidden="true" className="pointer-events-none absolute -top-40 -left-40 h-[600px] w-[600px] rounded-full bg-orb-cyan" />
      <div aria-hidden="true" className="pointer-events-none absolute -bottom-40 -right-40 h-[600px] w-[600px] rounded-full bg-orb-fuchsia" />

      <div className="relative z-10 p-8">
        {/* Header */}
        <header className="mb-8">
          <h1 className="font-sans text-3xl font-bold tracking-tighter text-foreground">
            Pro <span className="text-primary">Orc</span>
          </h1>
          <p className="mt-1 font-mono text-xs text-muted-foreground/60">
            {projects.length} projects — {codeProjects.length} code · {researchProjects.length} research
          </p>
        </header>

        {/* Card grid — responsive: 1 col mobile, 2 col md, 3 col lg */}
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {projects.map((project) =>
            isCodeProject(project)
              ? <CodeProjectCard key={project.id} project={project} />
              : <ResearchProjectCard key={project.id} project={project} />
          )}
        </div>
      </div>
    </main>
  )
}
```

### Pattern 2: Server Action for macOS System Commands (ACT-01, ACT-02, ACT-03)

**What:** Server Actions marked `'use server'` run on the server, where `child_process.exec` is available. Client components call them directly via `startTransition`.

**Critical insight:** `child_process` is a Node.js built-in module. It does NOT need to be added to `serverExternalPackages` in `next.config.ts`. `serverExternalPackages` is for npm packages with native binaries (like `chokidar`, `simple-git`, `fsevents`). Built-ins are always external.

**macOS `open` command behavior:**
- `open -a Terminal "/path/to/project"` — opens the path in a new Terminal.app window
- `open "/path/to/project"` — opens the path in Finder (default handler for directories)
- `open "https://notion.so/..."` — opens the URL in the default browser

**Security:** Path sanitization is essential. Never allow arbitrary user input to reach `exec`. Here, paths come from `project.path` which is constructed by `scanProjects()` from `PATHS.code` and `PATHS.research` — filesystem-derived, not user-submitted. Still, escape the path argument.

```typescript
// app/actions.ts
'use server'

import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

// ACT-01: Open project folder in Terminal.app
export async function openInTerminal(projectPath: string): Promise<void> {
  // Validate path is under expected base directories (defense in depth)
  if (!projectPath.startsWith('/Users/') || projectPath.includes('..')) {
    throw new Error('Invalid project path')
  }
  // Escape single quotes in path, wrap in single quotes for shell safety
  const safePath = projectPath.replace(/'/g, "'\\''")
  await execAsync(`open -a Terminal '${safePath}'`)
}

// ACT-02: Open project folder in Finder
export async function openInFinder(projectPath: string): Promise<void> {
  if (!projectPath.startsWith('/Users/') || projectPath.includes('..')) {
    throw new Error('Invalid project path')
  }
  const safePath = projectPath.replace(/'/g, "'\\''")
  await execAsync(`open '${safePath}'`)
}

// ACT-03: Open Notion URL in default browser
export async function openNotionPage(notionUrl: string): Promise<void> {
  // Validate it's a Notion URL
  if (!notionUrl.startsWith('https://') && !notionUrl.startsWith('http://')) {
    throw new Error('Invalid URL')
  }
  // open with -u flag to force URL interpretation
  const safeUrl = encodeURI(notionUrl)
  await execAsync(`open -u '${safeUrl}'`)
}
```

### Pattern 3: Client Component Card with Server Action Calls (ACT-01, ACT-02)

**What:** Card components are `'use client'` so they can handle button `onClick`. They receive a serializable `Project` object as a prop (serializable = plain object, no functions or class instances). They import Server Actions and call them inside `startTransition`.

**Why `startTransition`:** Server Actions return Promises. `startTransition` lets React keep the UI responsive while the action runs. Without it, the button freezes until the action completes (macOS `open` is fast, but it's good practice).

**Why not `useActionState` for buttons:** `useActionState` is for forms with state feedback. For fire-and-forget button clicks (open Terminal/Finder — no UI feedback needed), plain `startTransition` is sufficient.

```typescript
// components/codeProjectCard.tsx
'use client'

import { useTransition } from 'react'
import { Terminal, Folder, Clock, AlertCircle } from 'lucide-react'
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { openInTerminal, openInFinder } from '@/app/actions'
import type { CodeProject } from '@/lib/types'
import { cn } from '@/lib/utils'

interface CodeProjectCardProps {
  project: CodeProject
}

function isStale(timestamp?: string): boolean {
  if (!timestamp) return false
  const thirtyDays = 30 * 24 * 60 * 60 * 1000
  return Date.now() - new Date(timestamp).getTime() > thirtyDays
}

export function CodeProjectCard({ project }: CodeProjectCardProps) {
  const [isPending, startTransition] = useTransition()
  const stale = isStale(project.lastCommitTimestamp)

  return (
    <Card className={cn(
      'transition-shadow duration-200',
      stale ? 'border-amber-500/30 hover:glow-cyan' : 'hover:glow-cyan'
    )}>
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base">{project.name}</CardTitle>
          <div className="flex shrink-0 gap-1">
            {stale && (
              <Badge variant="outline" className="border-amber-500/50 text-amber-400 text-xs">
                Stale
              </Badge>
            )}
            {project.gsdStatus && (
              <StatusBadge status={project.gsdStatus} />
            )}
          </div>
        </div>
        {project.currentPhase && (
          <p className="font-mono text-xs text-muted-foreground">{project.currentPhase}</p>
        )}
      </CardHeader>

      <CardContent className="space-y-3">
        {project.phaseProgress !== undefined && (
          <div className="space-y-1">
            <div className="flex justify-between text-xs text-muted-foreground">
              <span>Progress</span>
              <span>{project.phaseProgress}%</span>
            </div>
            <Progress value={project.phaseProgress} className="h-1.5" />
          </div>
        )}

        {project.nextStep && (
          <p className="text-sm text-muted-foreground line-clamp-2">{project.nextStep}</p>
        )}

        {project.lastCommitTimestamp && (
          <div className="flex items-center gap-1.5 font-mono text-xs text-muted-foreground/60">
            <Clock className="size-3" />
            <span>{formatRelativeTime(project.lastCommitTimestamp)}</span>
          </div>
        )}
      </CardContent>

      <CardFooter className="gap-2">
        <Button
          variant="outline"
          size="sm"
          disabled={isPending}
          onClick={() => startTransition(() => openInTerminal(project.path))}
        >
          <Terminal className="size-3.5" />
          Terminal
        </Button>
        <Button
          variant="ghost"
          size="sm"
          disabled={isPending}
          onClick={() => startTransition(() => openInFinder(project.path))}
        >
          <Folder className="size-3.5" />
          Finder
        </Button>
      </CardFooter>
    </Card>
  )
}
```

### Pattern 4: Stale Detection (DASH-08)

**What:** Compare `lastCommitTimestamp` (ISO 8601 string from simple-git's `log.latest.date`) to current time.

**Important:** `git.log()` returns `date` as an ISO 8601 string. `new Date(isoString).getTime()` reliably parses it.

```typescript
// Stale = no commit in last 30 days
function isStale(lastCommitTimestamp?: string): boolean {
  if (!lastCommitTimestamp) return false  // No git data = not stale (don't penalize non-git projects)
  const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000
  return Date.now() - new Date(lastCommitTimestamp).getTime() > THIRTY_DAYS_MS
}
```

**Edge cases:**
- `lastCommitTimestamp` is `undefined` (non-git project or no commits) → not stale (return false)
- Invalid date string → `new Date(invalid).getTime()` returns `NaN`, `NaN > n` is `false` → safe
- Future timestamp (clock skew) → result is negative, `negative > THIRTY_DAYS` is false → safe

### Pattern 5: Research Project Card (RSRCH-01, RSRCH-02, RSRCH-03)

**What:** Distinct card for research projects. No git metrics displayed. Shows name, status, and Notion link. Notion link can be either a `<a href>` tag or a Server Action — prefer `<a href>` since it's a plain URL navigation.

```typescript
// components/researchProjectCard.tsx
'use client'

import { ExternalLink, BookOpen } from 'lucide-react'
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import type { ResearchProject } from '@/lib/types'
import { cn } from '@/lib/utils'

interface ResearchProjectCardProps {
  project: ResearchProject
}

export function ResearchProjectCard({ project }: ResearchProjectCardProps) {
  return (
    <Card className="border-accent/20 transition-shadow duration-200 hover:glow-fuchsia">
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-2">
            <BookOpen className="size-4 text-accent shrink-0" />
            <CardTitle className="text-base">{project.name}</CardTitle>
          </div>
          {project.gsdStatus && <StatusBadge status={project.gsdStatus} />}
        </div>
      </CardHeader>

      {project.nextStep && (
        <CardContent>
          <p className="text-sm text-muted-foreground line-clamp-2">{project.nextStep}</p>
        </CardContent>
      )}

      {project.notionUrl && (
        <CardFooter>
          <Button variant="outline" size="sm" asChild>
            <a href={project.notionUrl} target="_blank" rel="noopener noreferrer">
              <ExternalLink className="size-3.5" />
              Open Notion
            </a>
          </Button>
        </CardFooter>
      )}
    </Card>
  )
}
```

### Pattern 6: GSD Status Badge Styling

**What:** `gsdStatus` is a free-form string (`'building'`, `'done'`, `'paused'`, etc.). Map to colors using a lookup object.

```typescript
// Shared helper — can be in codeProjectCard.tsx or a shared statusBadge.tsx
const STATUS_STYLES: Record<string, string> = {
  building: 'border-primary/50 text-primary',
  done: 'border-green-500/50 text-green-400',
  paused: 'border-amber-500/50 text-amber-400',
  research: 'border-accent/50 text-accent',
  planning: 'border-blue-500/50 text-blue-400',
  archived: 'border-border text-muted-foreground',
}

function StatusBadge({ status }: { status: string }) {
  const style = STATUS_STYLES[status] ?? 'border-border text-muted-foreground'
  return (
    <Badge variant="outline" className={cn('text-xs capitalize', style)}>
      {status}
    </Badge>
  )
}
```

### Pattern 7: Timestamp Formatting (DASH-04)

**What:** Format `lastCommitTimestamp` (ISO 8601) as a relative time string ("2 days ago", "3 months ago"). Use `Intl.RelativeTimeFormat` — no library needed.

**Note:** `Intl.RelativeTimeFormat` is synchronous and can be used in both Server and Client Components. Use it in the card component (client side).

```typescript
function formatRelativeTime(isoTimestamp: string): string {
  const diff = Date.now() - new Date(isoTimestamp).getTime()
  const seconds = Math.floor(diff / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  const months = Math.floor(days / 30)
  const years = Math.floor(days / 365)

  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })

  if (years > 0) return rtf.format(-years, 'year')
  if (months > 0) return rtf.format(-months, 'month')
  if (days > 0) return rtf.format(-days, 'day')
  if (hours > 0) return rtf.format(-hours, 'hour')
  if (minutes > 0) return rtf.format(-minutes, 'minute')
  return 'just now'
}
```

### Anti-Patterns to Avoid

- **Fetching via `/api/projects` in the page component:** The page is a Server Component. It can import `scanProjects()` directly. An API route adds latency, serialization overhead, and complexity for no benefit in Phase 3.
- **Making card components Server Components when they need onClick:** Progress (shadcn) and Tooltip (shadcn) are already `'use client'`. Any component with `onClick` must be `'use client'`. Cards that use these components inherit the client boundary.
- **Passing Server Actions as props through multiple levels:** Server Actions can be imported directly in the `'use client'` component that calls them. No need to thread them through props (unless there's a specific reason).
- **Using `exec` synchronously (`execSync`):** Never use `execSync` in Next.js server code — blocks the event loop for all requests. Always use `promisify(exec)` or `execAsync`.
- **Trusting `project.path` without validation in Server Actions:** Even though paths come from the scanner (trusted), add a basic guard (`startsWith('/Users/')`, no `..`) in actions as defense in depth.
- **`backdrop-blur` on the Card for glassmorphism without a background:** The card's `--card` CSS variable is already set to `oklch(0.18 0.015 264 / 0.6)` — 60% opacity. `backdrop-filter: blur()` only works if the element has a non-opaque background. Add `backdrop-blur-sm` with `bg-card` and make sure there's something to blur behind the card (the orbs provide this).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Card UI layout | Custom div grid with custom styling | shadcn `Card` + `CardHeader`/`CardContent`/`CardFooter` | Already installed, handles the layout structure correctly with the dark theme variables |
| Progress bar | HTML `<div>` width percentage trick | shadcn `Progress` with `value` prop | Accessible, animated, uses `--primary` color automatically |
| Status badges | Custom span with hardcoded colors | shadcn `Badge` variant="outline" + `cn()` for color | Consistent with design system |
| Relative time | `date-fns` or `dayjs` | `Intl.RelativeTimeFormat` (built-in) | No dependency, works in all modern browsers, handles localization |
| Button styling | Custom button with hover states | shadcn `Button` variant="outline" / "ghost" | Already has correct dark theme hover states via `--accent` |
| Shell command execution | `child_process.spawn` with manual pipe handling | `promisify(exec)` from Node built-in | Simpler for one-shot commands; exec buffers output, no streaming needed |
| Icon rendering | SVG inline | `lucide-react` (already installed) | Tree-shakeable, TypeScript types, consistent sizing via `size-N` class |

**Key insight:** Every UI primitive is already installed via shadcn and lucide-react. The entire Phase 3 implementation is wiring existing pieces together, not building new primitives.

---

## Common Pitfalls

### Pitfall 1: `Progress` and `Tooltip` Are Client Components — Causes Hydration Issues

**What goes wrong:** `shadcn/ui`'s `Progress` component has `"use client"` at the top. Importing it into a Server Component file is fine — Next.js handles the boundary. But if you try to render a Server Component inside a `"use client"` component, you get an error. The card components are `"use client"` — they can only render other client components or plain HTML, not Server Components.

**Why it happens:** The Next.js Server/Client component boundary: once you cross into `"use client"`, everything rendered inside must also be a client component (or passed as `children` from a server parent).

**How to avoid:** Keep the full card as a `"use client"` component. Pass `project` data as props from the server page. This is the correct pattern for this use case.

**Warning signs:** "You cannot use a Server Component inside a Client Component's render" error in dev.

### Pitfall 2: `child_process` Added to `serverExternalPackages` Unnecessarily

**What goes wrong:** Some dev adds `'child_process'` to `serverExternalPackages` in `next.config.ts` because they see `simple-git` there. This is harmless but wrong — `child_process` is a Node.js built-in and is ALWAYS external (webpack/turbopack never bundles built-ins). The `serverExternalPackages` list is for npm packages with native `.node` files.

**Why it happens:** Cargo-culting the existing pattern from `next.config.ts`.

**How to avoid:** Never add Node built-ins (`fs`, `path`, `os`, `child_process`, `util`, `crypto`) to `serverExternalPackages`. Only npm packages with native binaries go there.

**Warning signs:** Next.js startup warning about unknown package in `serverExternalPackages`.

### Pitfall 3: Server Actions Called from `onClick` Without `startTransition`

**What goes wrong:** Calling a Server Action directly in `onClick` without `startTransition` works but causes the button to be unresponsive while the action runs. For macOS `open` commands this is fast (< 100ms), but it's still a blocking pattern.

**Why it happens:** Server Actions return `Promise<void>`. Without `startTransition`, React can't mark the update as non-urgent.

**How to avoid:** Always use `const [isPending, startTransition] = useTransition()` and call `startTransition(() => action(...))`. Use `disabled={isPending}` on the button to prevent double-clicks.

**Warning signs:** Button appears to "freeze" for a moment on click.

### Pitfall 4: `backdrop-blur` Glassmorphism Requires `bg-card` on the Card

**What goes wrong:** Adding `backdrop-blur-sm` to a card does nothing visible if the card doesn't have a partially transparent background color. The `bg-card` Tailwind utility maps to `--card: oklch(0.18 0.015 264 / 0.6)` — 60% opacity — which is the glassmorphism base. Without `bg-card`, the card is opaque and backdrop-blur has no effect.

**Why it happens:** The shadcn `Card` component already applies `bg-card` via its base classes. Adding `backdrop-blur-sm` as a className override is all that's needed.

**How to avoid:** Use `<Card className="backdrop-blur-sm hover:glow-cyan">` — the `bg-card` is already applied by the Card component's base class.

**Warning signs:** Cards look opaque/solid instead of semi-transparent.

### Pitfall 5: `scanProjects()` Is Slow When Many Projects Have Git Data

**What goes wrong:** `scanProjects()` runs git log concurrently across all code projects. With many projects (15+), the total time is bounded by the slowest git call (5s timeout). Initial page load could take up to 5 seconds in the worst case.

**Why it happens:** Phase 3 is "static" — it calls `scanProjects()` on every page request with no caching.

**How to avoid:** For Phase 3, this is acceptable — it's a dev tool on localhost. Document it as a known limitation. Phase 4 (live updates) will add caching or server-sent events to avoid blocking page load. Do NOT add `export const dynamic = 'force-static'` — that would cache data from build time, which is wrong for a dashboard that reflects live project state.

**Warning signs:** Page takes more than 1-2 seconds to load initially.

### Pitfall 6: `phaseProgress` Is `undefined`, Not Zero

**What goes wrong:** Rendering `<Progress value={project.phaseProgress} />` when `phaseProgress` is `undefined` passes `undefined` to the `value` prop. The shadcn `Progress` component uses `(value || 0)` internally, so it shows 0%. This is misleading — 0% implies "no progress" but the real state is "no data."

**Why it happens:** The parser returns `{}` (no `phaseProgress` field) when ROADMAP.md has no checkboxes. The field is `phaseProgress?: number` — optional.

**How to avoid:** Guard the Progress render: `{project.phaseProgress !== undefined && <Progress value={project.phaseProgress} />}`. The pattern `!= null` also works (catches both null and undefined).

**Warning signs:** Projects with no ROADMAP.md showing a 0% progress bar.

---

## Code Examples

Verified patterns from official sources and installed packages:

### Route Handler (for reference — Phase 3 does NOT need this, but Phase 4 will)

```typescript
// app/api/projects/route.ts (NOT needed for Phase 3 — shown for future reference)
// Source: vercel/next.js Context7 docs
import { scanProjects } from '@/lib/scanner'
import type { ProjectsResponse } from '@/lib/types'

export async function GET(): Promise<Response> {
  const projects = await scanProjects()
  const response: ProjectsResponse = {
    projects,
    scannedAt: new Date().toISOString(),
    totalCount: projects.length,
    codeCount: projects.filter(p => p.type === 'code').length,
    researchCount: projects.filter(p => p.type === 'research').length,
  }
  return Response.json(response)
}
```

### Server Action with `child_process.exec`

```typescript
// app/actions.ts
// Source: Node.js built-in child_process API + Next.js 'use server' directive
'use server'

import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

export async function openInTerminal(projectPath: string): Promise<void> {
  const safePath = projectPath.replace(/'/g, "'\\''")
  await execAsync(`open -a Terminal '${safePath}'`)
}
```

### Async Server Component calling scanProjects directly

```typescript
// app/page.tsx
// Source: Next.js App Router async component pattern (Context7 verified)
import { scanProjects } from '@/lib/scanner'

export default async function DashboardPage() {
  const projects = await scanProjects()  // Runs on the server, no fetch
  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
      {projects.map(p => /* ... */)}
    </div>
  )
}
```

### Client Component calling Server Action via `useTransition`

```typescript
// components/codeProjectCard.tsx
// Source: Next.js docs Server Actions + React 19 useTransition pattern
'use client'
import { useTransition } from 'react'
import { openInTerminal } from '@/app/actions'

export function CodeProjectCard({ project }: { project: CodeProject }) {
  const [isPending, startTransition] = useTransition()

  return (
    <button
      disabled={isPending}
      onClick={() => startTransition(() => openInTerminal(project.path))}
    >
      Open in Terminal
    </button>
  )
}
```

### shadcn Badge with custom color override

```typescript
// Source: badge.tsx uses CVA — className overrides via cn() are safe
// The shadcn Badge variant="outline" has border-border and text-foreground by default
// Override with specific color classes:
<Badge
  variant="outline"
  className="border-primary/50 text-primary text-xs"
>
  building
</Badge>
```

### shadcn Card with glassmorphism

```typescript
// Source: card.tsx + globals.css --card variable
// bg-card is already applied by Card's base class; add backdrop-blur-sm for effect
<Card className="backdrop-blur-sm hover:glow-cyan transition-shadow duration-200">
  <CardHeader>...</CardHeader>
  <CardContent>...</CardContent>
  <CardFooter>...</CardFooter>
</Card>
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `getServerSideProps` in pages/ for data fetching | `async` Server Component calls data function directly | Next.js 13+ (App Router) | Simpler, no prop drilling, no `context` needed |
| `useEffect` + fetch for client-side data | Server Component passes data as props, no client fetch | React 18+/Next.js 13+ | No loading spinner on initial render, SEO-friendly |
| `child_process.exec` callback style | `promisify(exec)` → async/await | Node.js 8+ (util.promisify) | Standard async pattern, no callback nesting |
| `form` + `action` for Server Actions | `startTransition(() => serverAction())` from onClick | React 19 + Next.js 14+ | Buttons don't need form wrappers; `useTransition` gives isPending state |
| `date-fns` for relative time | `Intl.RelativeTimeFormat` (Web Platform) | Widely supported 2020+ | Zero dependency, handles localization |

**Deprecated/outdated in this context:**
- `pages/index.tsx` with `getServerSideProps`: This project uses App Router exclusively.
- `axios` or `fetch` in Server Components for local data: Direct function import is always better for local data.
- `useEffect(() => { fetch('/api/projects') })` in page component: Server Components make this pattern obsolete for initial data.

---

## Open Questions

1. **Should `StatusBadge` be a shared component or duplicated?**
   - What we know: Both `codeProjectCard.tsx` and `researchProjectCard.tsx` need `StatusBadge`. Duplicating it is 10 lines of code.
   - What's unclear: Whether to create `components/statusBadge.tsx` (adds a file) or inline it in each card (duplication).
   - Recommendation: Create `components/statusBadge.tsx` — the camelCase convention supports it and it avoids duplication. Only ~15 lines. Flag for planner.

2. **Notion URL handling: `<a href>` vs Server Action**
   - What we know: ACT-03 says "opens the parsed Notion URL in the browser." A plain `<a href target="_blank">` does this without a server round-trip.
   - What's unclear: Whether the requirements intend Server Action (consistent with ACT-01/ACT-02) or a plain link (simpler).
   - Recommendation: Use `<a href>` with `target="_blank" rel="noopener noreferrer"`. It's simpler, works without JavaScript, and opens in the browser exactly as required. Server Action adds complexity with no benefit for URL opening.

3. **Should Phase 3 include `/api/projects` Route Handler?**
   - What we know: Phase 3 requirements don't mention an API route. The `ProjectsResponse` type in `lib/types.ts` implies one is planned. Phase 4 (live updates) will likely need it for SSE.
   - What's unclear: Whether building it now in Phase 3 is worthwhile (adds ~15 lines, no risk).
   - Recommendation: Do NOT build the Route Handler in Phase 3. Keep scope tight. Phase 4 will build it as part of the live-update architecture. Flag for planner.

4. **Phase 2 TypeScript gap: `beforeAll` not imported in `scanner.test.ts`**
   - What we know: Phase 2 VERIFICATION.md documented a gap: `scanner.test.ts` uses `beforeAll` as a global without import; `tsconfig.json` doesn't include `vitest/globals`. All 42 tests pass at runtime.
   - Recommendation: Phase 3's first plan should fix this one-line issue (add `beforeAll` to the vitest import on line 1 of `scanner.test.ts`) before adding new code. It's a pre-existing gap not a Phase 3 task per se, but clean state is important.

---

## Sources

### Primary (HIGH confidence)

- `/Users/rob/project_orchestration/pro-orc/lib/types.ts` — Exact `Project`, `CodeProject`, `ResearchProject`, `BaseProject`, `GsdStatus` types with field names and optionality
- `/Users/rob/project_orchestration/pro-orc/lib/scanner.ts` — `scanProjects()` export, `Promise.allSettled` pattern, git enrichment for code only
- `/Users/rob/project_orchestration/pro-orc/lib/parser.ts` — `parseGsdData()`, `GsdParseResult` interface with exact field names
- `/Users/rob/project_orchestration/pro-orc/lib/git-reader.ts` — `getGitData()`, `GitFields` type (only `lastCommitMessage`, `lastCommitTimestamp`, `lastCommitSha` — NOT `branch`/`isDirty`)
- `/Users/rob/project_orchestration/pro-orc/lib/paths.ts` — `PATHS`, `planningDir`, `projectIdFromPath`
- `/Users/rob/project_orchestration/pro-orc/app/globals.css` — Exact CSS variable values, `.glow-cyan`, `.glow-fuchsia`, `.bg-orb-cyan`, `.bg-orb-fuchsia` utility classes
- `/Users/rob/project_orchestration/pro-orc/app/layout.tsx` — `dark` class hardcoded, Inter + JetBrains Mono font setup, CSS variable names `--font-inter` / `--font-mono`
- `/Users/rob/project_orchestration/pro-orc/app/page.tsx` — Current placeholder page structure with atmospheric orbs already in place
- `/Users/rob/project_orchestration/pro-orc/components/ui/card.tsx` — `Card`, `CardHeader`, `CardTitle`, `CardDescription`, `CardAction`, `CardContent`, `CardFooter` exports
- `/Users/rob/project_orchestration/pro-orc/components/ui/badge.tsx` — `Badge` variants: `default`, `secondary`, `destructive`, `outline`, `ghost`, `link`
- `/Users/rob/project_orchestration/pro-orc/components/ui/button.tsx` — `Button` variants and sizes including `size="xs"` and `size="sm"`
- `/Users/rob/project_orchestration/pro-orc/components/ui/progress.tsx` — `Progress` with `value` prop, is `'use client'`, `bg-primary/20` track
- `/Users/rob/project_orchestration/pro-orc/components/ui/tooltip.tsx` — `Tooltip`, `TooltipProvider`, `TooltipTrigger`, `TooltipContent`, is `'use client'`
- `/Users/rob/project_orchestration/pro-orc/next.config.ts` — `serverExternalPackages: ['chokidar', 'simple-git', 'fsevents']` — confirms `child_process` is NOT in this list (correct)
- `/Users/rob/project_orchestration/pro-orc/package.json` — `next@16.1.6`, `react@19.2.3`, `lucide-react@0.572.0` confirmed installed
- macOS `man open` — Terminal, Finder, URL opening behavior for `open -a Terminal`, `open /path`, `open https://`
- lucide-react ESM module — confirmed `Terminal`, `Folder`, `ExternalLink`, `Clock`, `BookOpen`, `AlertCircle`, `Activity`, `Code2`, `FolderOpen`, `Globe` all present
- `/Users/rob/project_orchestration/.planning/phases/02-data-layer/02-VERIFICATION.md` — Phase 2 deliverables verified, exact exports confirmed
- Context7 `/vercel/next.js` — Async Server Component patterns, Server Actions, Route Handler patterns

### Secondary (MEDIUM confidence)

- Phase 1 CONTEXT.md — Design decisions (Cyan = primary/code, Fuchsia = accent/research, card transparency, camelCase naming, Inter+JetBrains Mono)
- Phase 2 RESEARCH.md — Architecture patterns, pitfalls, and data shapes fully documented

### Tertiary (LOW confidence)

- WebSearch — `child_process` in Next.js Server Actions usage patterns (verified against Node.js built-in behavior empirically)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified against installed package versions and source files
- Architecture: HIGH — patterns derived from actual installed component APIs and Phase 2 deliverables
- Server Action/exec pattern: HIGH — Node.js built-in behavior verified, macOS `open` command verified via `man open`
- Stale detection: HIGH — simple Date arithmetic, edge cases documented
- Pitfalls: HIGH — from direct inspection of installed components (Progress is 'use client', card glassmorphism requires bg-card)

**Research date:** 2026-02-17
**Valid until:** 2026-04-17 (stable domain — Next.js 16 App Router, shadcn/ui, and Node.js built-ins are stable)
