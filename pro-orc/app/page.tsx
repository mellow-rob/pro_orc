import { cn } from '@/lib/utils'
import type { Project } from '@/lib/types'

export default function DashboardPage() {
  // Phase 3 will replace this with real project data from /api/projects
  const projects: Project[] = []

  return (
    <main className="relative min-h-screen overflow-hidden">
      {/* Atmospheric background orbs — n3urala1 aesthetic */}
      <div
        aria-hidden="true"
        className={cn(
          'pointer-events-none absolute -top-40 -left-40 h-[600px] w-[600px] rounded-full',
          'bg-orb-cyan'
        )}
      />
      <div
        aria-hidden="true"
        className={cn(
          'pointer-events-none absolute -bottom-40 -right-40 h-[600px] w-[600px] rounded-full',
          'bg-orb-fuchsia'
        )}
      />

      {/* Content */}
      <div className="relative z-10 flex min-h-screen flex-col items-center justify-center gap-4 p-8">
        <h1 className="font-sans text-4xl font-bold tracking-tighter text-foreground">
          Pro{' '}
          <span className="text-primary">Orc</span>
        </h1>
        <p className="text-muted-foreground">
          Project Orchestration Dashboard
        </p>
        <p className="font-mono text-xs text-muted-foreground/60">
          {/* Phase 3 will replace this with real project count */}
          {projects.length} projects — data layer coming in Phase 2
        </p>
      </div>
    </main>
  )
}
