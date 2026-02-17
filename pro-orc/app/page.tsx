import { scanProjects } from '@/lib/scanner'
import { isCodeProject } from '@/lib/types'
import { CodeProjectCard } from '@/components/codeProjectCard'
import { ResearchProjectCard } from '@/components/researchProjectCard'
import { cn } from '@/lib/utils'

export default async function DashboardPage() {
  const projects = await scanProjects()

  const codeProjects = projects.filter(isCodeProject)
  const researchProjects = projects.filter((p) => !isCodeProject(p))

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
      <div className="relative z-10 p-8">
        <header className="mb-8">
          <h1 className="font-sans text-4xl font-bold tracking-tighter text-foreground">
            Pro{' '}
            <span className="text-primary">Orc</span>
          </h1>
          <p className="mt-2 font-mono text-sm text-muted-foreground/60">
            {projects.length} projects &mdash; {codeProjects.length} code &middot;{' '}
            {researchProjects.length} research
          </p>
        </header>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {projects.map((project) =>
            isCodeProject(project) ? (
              <CodeProjectCard key={`${project.type}-${project.id}`} project={project} />
            ) : (
              <ResearchProjectCard key={`${project.type}-${project.id}`} project={project} />
            )
          )}
        </div>
      </div>
    </main>
  )
}
