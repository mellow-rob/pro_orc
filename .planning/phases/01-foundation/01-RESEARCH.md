# Phase 1: Foundation - Research

**Researched:** 2026-02-17
**Domain:** Next.js 16 project initialization, Tailwind v4 + shadcn/ui dark theme, TypeScript discriminated union types, serverExternalPackages pre-configuration
**Confidence:** HIGH — all critical decisions verified against official Next.js 16.1.6 docs and shadcn/ui official docs

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dark Mode Styling**
- Design reference: n3urala1.com — ultra-dark background, semi-transparent cards, Cyan/Fuchsia accents
- Color palette: Dark Navy background, `rgba(255,255,255,0.02-0.05)` for cards, `border-white/5` for borders
- Accent colors: Cyan (#06b6d4) + Fuchsia (#d946ef) — assignment per Claude's Discretion
- Card contrast: Per Claude's Discretion — what works for an info-dense dashboard
- Typography: Inter Font with antialiasing, monospace for timestamps
- Effects: Subtle glow-shadows on interactive elements, smooth hover transitions
- UI/UX Pro Max Skill to be used for design implementation

**TypeScript Types**
- Project variants: Union Type — `CodeProject | ResearchProject` with shared Base Interface
- GSD Status: Dynamically derived from STATE.md (no fixed enum)
- Missing .planning/: Optional fields (`gsdStatus?: GsdStatus`) — undefined when no .planning/
- Git data: Flat on project interface (`lastCommitMessage`, `lastCommitTimestamp` directly on Project)

**Project Structure**
- Route structure: Extensible — `/` (Dashboard) + `/tools` + `/api/*` — prepared for later pages
- File naming: camelCase convention (projectCard.tsx, gitReader.ts)

**shadcn/ui Setup**
- Components: Install all needed components completely (Card, Badge, Button, Progress, Tooltip, Separator etc.)
- Theme: CSS variables set to n3urala1 Cyan/Fuchsia/Dark Navy palette
- Icons: lucide-react installed in Phase 1 and ready for later phases

### Claude's Discretion
- Backend module folder structure (lib/ vs lib/services/)
- React component organization (flat vs feature-based)
- Cyan/Fuchsia color assignment (Code vs Research, Status vs Highlight)
- Card transparency level for optimal readability

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-01 | App binds to localhost:3000 only (no network binding) | Next.js dev server binds to localhost by default; no special config needed. `next dev` defaults to `localhost:3000`. |
| INFRA-02 | No authentication required | Architecture decision — simply don't add auth middleware. No config needed. |
| INFRA-03 | No database — filesystem + git are the only data sources | Architecture decision — no Prisma, no SQLite. Verified against STACK.md recommendations. |
| INFRA-04 | All paths resolved via os.homedir() (never hardcoded) | `path.join(os.homedir(), 'project_orchestration', ...)` pattern. Implement in `lib/paths.ts` shared constants file. |
| DASH-06 | Dashboard uses dark mode design (dark-first, no toggle in v1) | Add `class="dark"` to `<html>` in layout.tsx. No next-themes needed. `.dark` CSS class selector + CSS variable overrides handle everything. |
</phase_requirements>

---

## Summary

Phase 1 is pure infrastructure: get the Next.js 16.1.6 project correctly configured before writing any feature code. The critical risk is that mistakes at this layer — wrong `serverExternalPackages`, wrong Tailwind v4 CSS structure, wrong dark mode approach — propagate into every subsequent phase and require rewrites. All decisions are well-documented in official sources.

The shadcn/ui + Tailwind v4 combination has one important nuance: v4 moved from a `tailwind.config.js` to a CSS-first `@theme` directive, and shadcn/ui's latest CLI fully supports this. The correct globals.css structure uses `@import "tailwindcss"`, `@custom-variant dark (&:is(.dark *))`, and `@theme inline { ... }` to map CSS custom properties to Tailwind utility classes. Forcing dark-only mode is as simple as adding `class="dark"` to `<html>` in layout.tsx — no `next-themes`, no `prefers-color-scheme` media query needed.

The TypeScript type design is straightforward: a discriminated union with `type: 'code' | 'research'` as the discriminant, a shared `BaseProject` interface, and type-specific extensions. GSD status derives dynamically from STATE.md parsing rather than a fixed enum, which means the type is `string` with well-known literal values rather than a TypeScript enum.

**Primary recommendation:** Initialize with `npx create-next-app@latest --yes`, immediately add `serverExternalPackages` and TypeScript types, then configure Tailwind + shadcn/ui, then wire the dark mode CSS variables and custom palette. Verify each step works before proceeding to the next.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Next.js | 16.1.6 | App framework | Current stable on this machine — confirmed in 4 active projects |
| React | 19.2.4 | UI rendering | Required peer dep of Next.js 16 |
| TypeScript | 5.9.3 | Type safety | Native `next.config.ts` support; current stable |
| Tailwind CSS | 4.1.18 | Utility CSS | Current stable — v4 CSS-first, no tailwind.config.js |
| @tailwindcss/postcss | 4.1.18 | PostCSS integration | Required in Tailwind v4 — replaces old plugin setup |
| shadcn/ui | latest CLI | Components | `npx shadcn@latest init` generates v4-compatible output |
| lucide-react | 0.563.0 | Icons | shadcn/ui default icon set |
| clsx | 2.1.1 | Conditional classnames | Required by shadcn's `cn()` utility |
| tailwind-merge | 3.4.0 | Class merging | Required by shadcn's `cn()` utility |
| tw-animate-css | latest | Animations | shadcn/ui v4 replacement for tailwindcss-animate |

### Supporting (Phase 1 Only — No Feature Code)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| server-only | latest | Guard server-only modules | Add to `lib/watcher.ts`, `lib/gitReader.ts` etc. in later phases |

### Pre-declared for Later Phases (add to next.config.ts now)

| Library | Phase Used | Why Configure Now |
|---------|------------|-------------------|
| chokidar | Phase 5 | Must be in `serverExternalPackages` before any import |
| simple-git | Phase 2 | Must be in `serverExternalPackages` before any import |
| fsevents | Phase 5 | Native macOS binding, must be externalized |

**Installation:**
```bash
# Step 1: Initialize project
npx create-next-app@latest pro-orc --yes
# --yes uses defaults: TypeScript, Tailwind, ESLint, App Router, Turbopack, @/* alias

# Step 2: shadcn/ui init (interactive)
npx shadcn@latest init
# Select: New York style, oklch colors, CSS variables: yes

# Step 3: Install all Phase 1 needed shadcn components
npx shadcn@latest add card badge button progress tooltip separator

# Step 4: Install tw-animate-css (shadcn v4 dep)
npm install tw-animate-css

# Step 5: Install chokidar and simple-git NOW (even though used in later phases)
# so they're available for next.config.ts serverExternalPackages
npm install chokidar@^3.6.0 simple-git
```

---

## Architecture Patterns

### Recommended Project Structure

```
pro-orc/
├── instrumentation.ts           # Server startup hook (Phase 5 — create empty now)
├── next.config.ts               # CRITICAL: serverExternalPackages configured here
├── app/
│   ├── layout.tsx               # Root layout — dark class on <html>, Inter font
│   ├── page.tsx                 # Dashboard (Phase 4)
│   ├── tools/
│   │   └── page.tsx             # Tools inventory page (Phase 6)
│   └── api/
│       ├── sse/
│       │   └── route.ts         # SSE endpoint (Phase 5)
│       ├── projects/
│       │   ├── route.ts         # GET all projects (Phase 3)
│       │   └── [id]/
│       │       └── route.ts     # GET single project (Phase 3)
│       └── tools/
│           └── route.ts         # GET Claude tools (Phase 6)
├── components/
│   ├── ui/                      # shadcn/ui generated components (Phase 1)
│   ├── projectCard.tsx          # Project card (Phase 4)
│   ├── projectGrid.tsx          # Grid layout (Phase 4)
│   └── sseLlistener.tsx         # SSE client (Phase 5)
├── lib/
│   ├── types.ts                 # Shared TypeScript types (Phase 1 — FIRST file)
│   ├── paths.ts                 # os.homedir() path constants (Phase 1)
│   ├── utils.ts                 # cn() utility (shadcn generates this)
│   ├── scanner.ts               # Directory scanning (Phase 2)
│   ├── parser.ts                # .planning/ markdown parsing (Phase 2)
│   ├── gitReader.ts             # simple-git wrapper (Phase 2)
│   ├── watcher.ts               # chokidar singleton (Phase 5)
│   ├── eventBus.ts              # EventEmitter (Phase 5)
│   └── toolsReader.ts           # ~/.claude/ reader (Phase 6)
├── hooks/
│   └── useSse.ts                # EventSource hook (Phase 5)
└── app/globals.css              # Tailwind v4 + dark mode CSS variables
```

**Recommendation on lib/ structure:** Use flat `lib/` (not `lib/services/`). With only 6-7 modules total, sub-directories add navigation friction without organizational benefit. Each file's name makes its purpose clear.

**Recommendation on component organization:** Use flat `components/` with shadcn's `components/ui/` subdirectory (auto-generated). Feature-based subdirectories are unnecessary for this project scope.

### Pattern 1: next.config.ts — Configure serverExternalPackages First

**What:** Declare Node.js-native packages as external to prevent Next.js bundler from breaking them.
**When:** Before writing a single line of watcher or git code. Day 0.

```typescript
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // CRITICAL: prevents Next.js from bundling Node.js-native packages.
  // chokidar and simple-git are NOT in Next.js's auto-exclude list.
  // Without this, fsevents binary fails silently -> polling at 100% CPU.
  serverExternalPackages: ['chokidar', 'simple-git', 'fsevents'],
}

export default nextConfig
```

### Pattern 2: Dark Mode — Force Dark, No Toggle

**What:** Add `class="dark"` permanently to `<html>` and load Inter font with antialiasing.
**When:** layout.tsx — the single source of truth for the dark class.

```typescript
// app/layout.tsx
import type { Metadata } from 'next'
import { Inter, JetBrains_Mono } from 'next/font/google'
import './globals.css'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'Pro Orc',
  description: 'Project Orchestration Dashboard',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    // dark class hardcoded — no toggle, no next-themes, no flash
    <html lang="en" className="dark">
      <body className={`${inter.variable} ${jetbrainsMono.variable} font-sans antialiased`}>
        {children}
      </body>
    </html>
  )
}
```

**Why JetBrains Mono instead of a generic monospace:** The CONTEXT.md specifies monospace for timestamps. JetBrains Mono has a `--font-mono` variable that pairs well with Inter and is optimized for readability at small sizes.

### Pattern 3: Tailwind v4 + shadcn/ui CSS Variables — n3urala1 Palette

**What:** Define the custom dark navy / cyan / fuchsia palette using `@theme inline` in globals.css.
**When:** After `npx shadcn@latest init` generates the base globals.css — replace the generated color values.

```css
/* app/globals.css */
@import "tailwindcss";
@import "tw-animate-css";

/* Dark variant fires when any ancestor has .dark class */
@custom-variant dark (&:is(.dark *));

@theme inline {
  /* Font families */
  --font-sans: var(--font-inter);
  --font-mono: var(--font-mono);

  /* Color mappings — Tailwind utilities use these */
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-border: var(--border);
  --color-ring: var(--ring);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);

  /* Border radius */
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
}

/* ============================================================
   n3urala1 Dark Theme — Applied by default (dark class on html)
   ============================================================ */
:root {
  --radius: 0.5rem;

  /* Light mode defaults (not used in v1 — dark-only) */
  --background: oklch(0.985 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(0.985 0 0);
  --card-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
}

/* Dark theme — THE theme. Dark class is hardcoded on <html>. */
.dark {
  /* Background: ultra-dark navy (#0a0f1a approximate) */
  --background: oklch(0.11 0.02 264);
  --foreground: oklch(0.95 0 0);

  /* Cards: semi-transparent white over dark background */
  /* Equivalent to bg-white/[0.03] — very subtle glassmorphism */
  --card: oklch(0.18 0.015 264 / 0.6);
  --card-foreground: oklch(0.92 0 0);

  /* Primary: Cyan (#06b6d4) */
  --primary: oklch(0.715 0.143 212.34);
  --primary-foreground: oklch(0.11 0.02 264);

  /* Secondary: subtle surface for secondary actions */
  --secondary: oklch(0.22 0.015 264);
  --secondary-foreground: oklch(0.85 0 0);

  /* Muted: subdued text and backgrounds */
  --muted: oklch(0.18 0.01 264);
  --muted-foreground: oklch(0.62 0.01 264);

  /* Accent: Fuchsia (#d946ef) */
  --accent: oklch(0.70 0.22 320.08);
  --accent-foreground: oklch(0.11 0.02 264);

  /* Destructive: red for errors */
  --destructive: oklch(0.577 0.245 27.325);

  /* Borders: very subtle white — border-white/5 equivalent */
  --border: oklch(1 0 0 / 0.05);
  --input: oklch(1 0 0 / 0.05);
  --ring: oklch(0.715 0.143 212.34);
}

/* ============================================================
   Custom utilities not covered by shadcn defaults
   ============================================================ */
@layer utilities {
  /* Card glow on hover — cyan accent */
  .glow-cyan {
    box-shadow: 0 0 20px oklch(0.715 0.143 212.34 / 0.15);
  }

  /* Card glow on hover — fuchsia accent */
  .glow-fuchsia {
    box-shadow: 0 0 20px oklch(0.70 0.22 320.08 / 0.15);
  }

  /* Atmospheric blur background orb (n3urala1 style) */
  .bg-orb-cyan {
    background: oklch(0.715 0.143 212.34 / 0.08);
    filter: blur(100px);
  }

  .bg-orb-fuchsia {
    background: oklch(0.70 0.22 320.08 / 0.08);
    filter: blur(100px);
  }
}
```

**Cyan/Fuchsia assignment recommendation (Claude's Discretion):**
- Cyan (`--primary`): Code projects, active/in-progress status, interactive CTAs — "doing" color
- Fuchsia (`--accent`): Research projects, highlights, special status badges — "thinking" color
- This maps naturally: code = building (action) = cyan; research = exploring (insight) = fuchsia

**Card transparency recommendation (Claude's Discretion):**
- `oklch(0.18 0.015 264 / 0.6)` for the `--card` variable (~ bg-white/[0.03] over dark navy)
- Use `backdrop-blur-sm` on card components for glassmorphism effect
- Border: `border-white/5` (already in `--border`)
- For readability at high info density: keep background at 60% opacity minimum — below 50% text contrast suffers on dark backgrounds

### Pattern 4: Shared TypeScript Types — lib/types.ts

**What:** Define the full type system for project data before any scanner/parser code exists.
**When:** First file after project initialization. No dependencies.

```typescript
// lib/types.ts

// ============================================================
// GSD Status — derived from STATE.md, not a fixed enum.
// These are the known values but the type is open (string).
// ============================================================
export type GsdStatus =
  | 'research'
  | 'planning'
  | 'building'
  | 'paused'
  | 'done'
  | 'archived'
  | (string & {}) // allows unknown future states while keeping autocomplete

// ============================================================
// Shared Base — fields present on ALL project types
// ============================================================
export interface BaseProject {
  id: string              // slugified directory name: "landlord-checker"
  name: string            // display name: "Landlord Checker"
  path: string            // absolute filesystem path (from os.homedir())
  type: 'code' | 'research'  // discriminant — determines card layout

  // GSD planning data — optional (project may have no .planning/)
  gsdStatus?: GsdStatus         // current phase name from STATE.md
  currentPhase?: string         // e.g. "Phase 3: API Layer"
  nextStep?: string             // next action from STATE.md or ROADMAP.md
  phaseProgress?: number        // 0-100: completed checkboxes / total checkboxes
  notionUrl?: string            // from <!-- notion: URL --> in PROJECT.md
}

// ============================================================
// Code Project — extends Base with git data (flat, per CONTEXT.md)
// ============================================================
export interface CodeProject extends BaseProject {
  type: 'code'  // discriminant value

  // Git data — flat on the interface per user decision
  // All optional: project may not be a git repo
  lastCommitMessage?: string
  lastCommitTimestamp?: string  // ISO 8601: "2026-02-17T14:23:00Z"
  lastCommitSha?: string        // short SHA: "a3f8b12"
  branch?: string               // current branch: "main"
  isDirty?: boolean             // uncommitted changes exist
}

// ============================================================
// Research Project — no git, different metadata
// ============================================================
export interface ResearchProject extends BaseProject {
  type: 'research'  // discriminant value
  // Research projects: no git fields.
  // If .planning/ exists, they show GSD status.
  // If no .planning/, all BaseProject optional fields are undefined.
}

// ============================================================
// Discriminated Union — use this type for all project lists
// ============================================================
export type Project = CodeProject | ResearchProject

// ============================================================
// Type Guards — for narrowing in components and API handlers
// ============================================================
export function isCodeProject(p: Project): p is CodeProject {
  return p.type === 'code'
}

export function isResearchProject(p: Project): p is ResearchProject {
  return p.type === 'research'
}

// ============================================================
// API Response shape — what /api/projects returns
// ============================================================
export interface ProjectsResponse {
  projects: Project[]
  scannedAt: string  // ISO 8601 timestamp
  totalCount: number
  codeCount: number
  researchCount: number
}

// ============================================================
// SSE Event shape — signal-only pattern (browser re-fetches)
// ============================================================
export type SseEventType =
  | 'project:updated'
  | 'project:added'
  | 'project:removed'
  | 'ping'

export interface SseEvent {
  type: SseEventType
  projectId?: string      // undefined for ping events
  changedFile?: string    // relative path of changed file, for debugging
}
```

### Pattern 5: Shared Path Constants — lib/paths.ts

**What:** Centralize all filesystem path construction using os.homedir(). Never hardcode paths.
**When:** Phase 1, alongside types.ts. Used by Scanner, Parser, Watcher in later phases.

```typescript
// lib/paths.ts
import os from 'os'
import path from 'path'

const HOME = os.homedir()
const BASE = path.join(HOME, 'project_orchestration')

export const PATHS = {
  base: BASE,
  code: path.join(BASE, 'code'),
  research: path.join(BASE, 'project research'),
  claude: path.join(HOME, '.claude'),
} as const

// Helper: get the .planning/ directory for a project
export function planningDir(projectPath: string): string {
  return path.join(projectPath, '.planning')
}

// Helper: resolve a project ID from its absolute path
export function projectIdFromPath(projectPath: string): string {
  return path.basename(projectPath)
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
}
```

### Pattern 6: Empty instrumentation.ts — Placeholder for Phase 5

**What:** Create the file now so Phase 5 doesn't require root-level file creation mid-build.
**When:** Phase 1 initialization.

```typescript
// instrumentation.ts (root of project)
// Singleton watcher bootstrap — populated in Phase 5 (Live Updates)
export async function register() {
  // Phase 5: add chokidar watcher initialization here
  // Guard: if (process.env.NEXT_RUNTIME === 'nodejs') { ... }
}
```

### Anti-Patterns to Avoid

- **Avoid `next-themes`:** Adds unnecessary complexity for a dark-only app. One `class="dark"` on `<html>` is the complete solution.
- **Avoid `tailwind.config.js`:** In Tailwind v4, configuration lives in the CSS file (`@theme`). Creating a `tailwind.config.js` confuses the toolchain.
- **Avoid `bg-opacity-*` / `text-opacity-*`:** Removed in Tailwind v4. Use `/` syntax: `bg-white/5`, `text-white/70`.
- **Avoid hardcoded paths in any lib file:** Use `PATHS.code`, `PATHS.research` from `lib/paths.ts` everywhere.
- **Avoid `tailwindcss-animate` package:** shadcn v4 replaced it with `tw-animate-css`. Don't install the old one.
- **Avoid putting feature code in Phase 1:** This phase ends when the project runs on `localhost:3000` with correct config, types, and dark theme. No project scanning, no API routes, no card components.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UI components (Card, Badge, Button) | Custom implementations | `npx shadcn@latest add` | shadcn owns the code, it's yours to customize, Radix primitives handle a11y |
| Class name merging | Custom merge logic | `cn()` from `lib/utils.ts` (shadcn generates) | tailwind-merge handles conflict resolution correctly |
| Icon set | SVG files | lucide-react | 1000+ consistent icons, tree-shakeable, shadcn default |
| Font loading | `<link>` tags | `next/font/google` | Automatic subsetting, no layout shift, privacy-safe |
| Dark mode detection | JS media query listeners | CSS `.dark` class on `<html>` | No JavaScript needed; CSS variables handle everything |
| Animation utilities | CSS keyframes | `tw-animate-css` | Pairs with Tailwind v4, same approach shadcn uses |
| Path resolution | String concatenation | `path.join(os.homedir(), ...)` in `lib/paths.ts` | Handles all OS path separators, testable in isolation |

**Key insight:** Phase 1 is almost entirely "configure and install" rather than "build." The value is correctness of setup, not custom code.

---

## Common Pitfalls

### Pitfall 1: Tailwind v4 Class Name Changes from v3

**What goes wrong:** shadcn/ui components may contain v3 class names that silently render wrong in v4. `shadow-sm` renders smaller than expected, `ring` is 1px instead of 3px, `outline-none` doesn't exist.

**Why it happens:** shadcn CLI generates components from templates; if templates have v3 names, they compile without error but produce wrong styles.

**How to avoid:**
1. Run `npx @tailwindcss/upgrade` before any component installation
2. After each `npx shadcn@latest add [component]`, audit for: `shadow-sm`, `rounded-sm`, `blur-sm`, `ring`, `outline-none`, `bg-opacity-*`, `flex-shrink-*`
3. Verify PostCSS config uses `@tailwindcss/postcss` not `tailwindcss`

**Warning signs:** Focus rings on buttons are 1px/gray instead of 3px. Card shadows are shallower than expected.

**Tailwind v4 breaking class name mapping:**
| v3 Class | v4 Replacement |
|----------|---------------|
| `shadow-sm` | `shadow-xs` |
| `shadow` | `shadow-sm` |
| `rounded-sm` | `rounded-xs` |
| `rounded` | `rounded-sm` |
| `blur-sm` | `blur-xs` |
| `ring` | `ring-3` |
| `outline-none` | `outline-hidden` |
| `bg-opacity-50` | `bg-black/50` |
| `flex-shrink-0` | `shrink-0` |
| `flex-grow` | `grow` |
| `!flex` | `flex!` |

### Pitfall 2: serverExternalPackages Not Set Before Package Import

**What goes wrong:** If any code imports chokidar or simple-git before `next.config.ts` has them in `serverExternalPackages`, Next.js bundles them and fsevents fails. The error is often confusing ("module not found" for a binary).

**How to avoid:** Add `serverExternalPackages: ['chokidar', 'simple-git', 'fsevents']` to `next.config.ts` as step 1, before installing the packages.

**Warning signs:** CPU spikes to 100% on `next dev`. Console shows `Error: Cannot find module 'fsevents'`.

### Pitfall 3: shadcn init Generates HSL Instead of OKLCH

**What goes wrong:** Depending on the CLI version and selected base color, shadcn may generate `hsl()` color values instead of `oklch()`. These work but mix with Tailwind v4's OKLCH defaults, producing inconsistent color behavior.

**How to avoid:** After `npx shadcn@latest init`, verify `globals.css` uses `oklch()` not `hsl()`. If it's HSL, re-run `npx shadcn@latest init` and select a different base color, or manually convert values.

**Note:** As of February 2026, `npx shadcn@latest init` generates OKLCH for new projects by default.

### Pitfall 4: `@custom-variant dark` Missing from globals.css

**What goes wrong:** Without `@custom-variant dark (&:is(.dark *))`, Tailwind v4's `dark:` utilities use the `prefers-color-scheme: dark` media query by default. Since we add `class="dark"` to `<html>` but the user's system preference may be light mode, `dark:` utilities won't fire.

**How to avoid:** Ensure globals.css contains exactly:
```css
@custom-variant dark (&:is(.dark *));
```
This overrides the default dark variant to use the CSS class instead of media query.

**Warning signs:** `dark:bg-card` has no effect when `.dark` is on the HTML element but system is in light mode.

### Pitfall 5: Forgetting Path Alias in tsconfig.json

**What goes wrong:** `create-next-app --yes` sets up `@/*` alias pointing to the project root. If later imports use relative paths like `../../lib/types`, it works but creates friction when files move and breaks the convention.

**How to avoid:** Verify tsconfig.json has:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": { "@/*": ["./*"] }
  }
}
```
Use `@/lib/types`, `@/components/ui/card` everywhere from day 1.

---

## Code Examples

Verified patterns from official sources:

### Complete next.config.ts

```typescript
// Source: Next.js 16.1.6 official docs
// https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  serverExternalPackages: ['chokidar', 'simple-git', 'fsevents'],
}

export default nextConfig
```

### Inter Font with CSS Variable in layout.tsx

```typescript
// Source: Next.js 16.1.6 font optimization docs
// https://nextjs.org/docs/app/getting-started/fonts
import { Inter, JetBrains_Mono } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

// Usage in body:
// className={`${inter.variable} ${jetbrainsMono.variable} font-sans antialiased`}
```

### TypeScript Discriminated Union Usage

```typescript
// Usage pattern — type narrowing with discriminant
import { Project, isCodeProject } from '@/lib/types'

function renderProject(project: Project) {
  // TypeScript knows project.lastCommitMessage exists here
  if (isCodeProject(project)) {
    return project.lastCommitMessage  // string | undefined — OK
  }
  // TypeScript knows this is ResearchProject here
  return project.notionUrl  // string | undefined — OK
}

// Switch pattern also works
function getCardColor(project: Project): string {
  switch (project.type) {
    case 'code': return 'cyan'
    case 'research': return 'fuchsia'
    // TypeScript enforces exhaustiveness
  }
}
```

### shadcn Card with Dark Theme Classes

```typescript
// Example of how cards will look (Phase 4) — shows what CSS vars produce
// Not built in Phase 1, but this validates the theme setup
import { Card, CardHeader, CardContent } from '@/components/ui/card'

function ProjectCard({ project }: { project: Project }) {
  return (
    <Card className="
      bg-card/60
      backdrop-blur-sm
      border-border
      hover:glow-cyan
      transition-all duration-300
    ">
      <CardHeader>
        <h2 className="font-sans text-foreground tracking-tight">
          {project.name}
        </h2>
      </CardHeader>
      <CardContent>
        <span className="font-mono text-xs text-muted-foreground">
          {project.lastCommitTimestamp}  {/* monospace timestamp */}
        </span>
      </CardContent>
    </Card>
  )
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `tailwind.config.js` for customization | `@theme` directive in CSS | Tailwind v4.0 (early 2025) | No JS config needed; CSS-first setup |
| `tailwindcss-animate` for animations | `tw-animate-css` | shadcn v4 update (2025) | Must install `tw-animate-css`, not the old package |
| `hsl()` color values in shadcn | `oklch()` color values | shadcn CLI update (2025) | Better perceptual uniformity; wider gamut |
| `@tailwind base/components/utilities` | `@import "tailwindcss"` | Tailwind v4.0 | Single import replaces three directives |
| `tailwindcss` PostCSS plugin | `@tailwindcss/postcss` | Tailwind v4.0 | Different package name in postcss.config.mjs |
| `next-themes` for dark mode | CSS class on `<html>` + `@custom-variant` | Tailwind v4 + team decision | No JavaScript needed for static dark theme |
| `middleware.ts` | Renamed to `proxy.ts` in Next.js 16 | Next.js 16.0 | Don't use middleware.ts (though not needed here) |
| `next build` runs linter | Linter only via npm scripts | Next.js 16.0 | Run `npm run lint` manually; `next build` doesn't |
| `context.params` (sync) | `await context.params` (Promise) | Next.js 15.0 | All dynamic route handlers need `await params` |

**Deprecated/outdated:**
- `tailwindcss-animate`: Replaced by `tw-animate-css` in shadcn v4 — don't install
- `next-themes`: Unnecessary for dark-only apps — adds complexity with no benefit
- `tailwind.config.js`: Not scanned by default in v4 — all config moves to CSS
- `@tailwind base`, `@tailwind components`, `@tailwind utilities`: Replaced by `@import "tailwindcss"`

---

## Open Questions

1. **OKLCH value accuracy for n3urala1 colors**
   - What we know: Cyan is #06b6d4, Fuchsia is #d946ef. Navy background is described as "ultra-dark."
   - What's unclear: The exact OKLCH values for the background dark navy haven't been measured from n3urala1.com directly.
   - Recommendation: The values in the CSS above (`oklch(0.11 0.02 264)` for background) are reasonable approximations. During Phase 4 (Static UI), do a visual comparison against n3urala1.com and adjust L/C/H values until it matches. The implementation path is clear; only the exact numbers need tuning.

2. **JetBrains Mono vs Geist Mono for timestamps**
   - What we know: CONTEXT.md says "monospace for timestamps." Geist Mono is Vercel's font (excellent quality). JetBrains Mono is a developer-focused monospace.
   - What's unclear: User preference between the two.
   - Recommendation: Use JetBrains Mono (proposed above). It has strong readability at small sizes. Geist Mono is an acceptable alternative — the import change is trivial.

3. **shadcn style selection: New York vs Default**
   - What we know: shadcn init now defaults to "New York" style (as of 2025); "Default" is considered legacy.
   - What's unclear: Whether New York vs Default significantly affects the dark theme implementation.
   - Recommendation: Select New York style. It has slightly more refined defaults and is the current standard. CSS variable overrides work the same regardless of style selection.

---

## Sources

### Primary (HIGH confidence)

- Next.js 16.1.6 installation docs — `create-next-app` command, layout.tsx, font setup: https://nextjs.org/docs/app/getting-started/installation (verified 2026-02-17, doc version 16.1.6)
- Next.js 16.1.6 font optimization — `next/font/google`, CSS variables, antialiased: https://nextjs.org/docs/app/getting-started/fonts (verified 2026-02-17)
- Next.js 16.1.6 serverExternalPackages config: https://nextjs.org/docs/app/api-reference/config/next-config-js/serverExternalPackages (verified via STACK.md research)
- shadcn/ui Tailwind v4 guide — `@theme inline`, `@custom-variant dark`, `@import "tailwindcss"`: https://ui.shadcn.com/docs/tailwind-v4 (verified 2026-02-17)
- shadcn/ui theming — CSS variable names, oklch format, .dark block structure: https://ui.shadcn.com/docs/theming (verified 2026-02-17)
- shadcn/ui manual install — globals.css structure, components.json, tw-animate-css: https://ui.shadcn.com/docs/installation/manual (verified 2026-02-17)
- Tailwind CSS v4 theme variables — `@theme inline` custom colors in OKLCH: https://tailwindcss.com/docs/theme (verified via WebSearch 2026-02-17)
- Project STACK.md — versions confirmed from local node_modules: chokidar 3.6.0, Tailwind 4.1.18, React 19.2.4, TypeScript 5.9.3, Next.js 16.1.6, lucide-react 0.563.0, clsx 2.1.1, tailwind-merge 3.4.0
- Project PITFALLS.md — Tailwind v4 breaking changes, serverExternalPackages, dark mode patterns (HIGH confidence — official docs verified)

### Secondary (MEDIUM confidence)

- Tailwind v4 class name changes: https://tailwindcss.com/docs/upgrade-guide (referenced in PITFALLS.md, verified there)
- TypeScript discriminated unions — pattern for `type: 'code' | 'research'` discriminant: https://www.typescriptlang.org/docs/handbook/unions-and-intersections.html (TypeScript standard pattern — HIGH confidence)
- Dark mode with class strategy — `class="dark"` on HTML + `@custom-variant dark`: WebSearch finding verified against shadcn official docs

### Tertiary (LOW confidence)

- OKLCH color conversions for #06b6d4 (cyan) and #d946ef (fuchsia) — computed via OKLCH approximation from hex values; should be visually verified during Phase 4

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions confirmed from installed node_modules, official docs verified
- Architecture: HIGH — directory structure, file naming, and patterns all follow official Next.js 16 + shadcn docs
- TypeScript types: HIGH — discriminated union pattern is TypeScript handbook standard; type design follows CONTEXT.md decisions exactly
- Tailwind v4 + shadcn CSS: HIGH — structure verified from official shadcn docs; OKLCH values are MEDIUM (approximations from hex)
- Pitfalls: HIGH — serverExternalPackages, @custom-variant dark, class name changes all verified from official sources

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (30 days — stable libraries, low churn risk)
