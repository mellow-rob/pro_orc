'use client'

import { useState, useCallback } from 'react'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Code, BookOpen, EyeOff, ChevronRight } from 'lucide-react'
import { CodeProjectCard } from '@/components/codeProjectCard'
import { ResearchProjectCard } from '@/components/researchProjectCard'
import { usePrivateProjects } from '@/hooks/usePrivateProjects'
import { useProjectEvents } from '@/hooks/useProjectEvents'
import type { CodeProject, ResearchProject, Project } from '@/lib/types'
import { cn } from '@/lib/utils'

const triggerBase = cn(
  'gap-2 rounded-t-lg rounded-b-none border border-b-0 px-5 py-3 text-sm font-medium',
  'backdrop-blur-sm transition-all duration-200',
  'data-[state=inactive]:border-transparent data-[state=inactive]:bg-transparent',
  'data-[state=inactive]:text-muted-foreground data-[state=inactive]:hover:text-foreground',
  'data-[state=inactive]:hover:bg-card/40',
)

function PrivateSection({ count, children }: { count: number; children: React.ReactNode }) {
  return (
    <details className="group/private pt-4">
      <summary className="flex cursor-pointer select-none items-center gap-2 py-2 list-none">
        <div className="h-px flex-1 bg-border" />
        <span className="flex items-center gap-1.5 font-mono text-xs text-muted-foreground/50 transition-colors group-open/private:text-muted-foreground/70">
          <ChevronRight className="size-3 transition-transform group-open/private:rotate-90" />
          <EyeOff className="size-3" />
          Private ({count})
        </span>
        <div className="h-px flex-1 bg-border" />
      </summary>
      <div className="pt-3">
        {children}
      </div>
    </details>
  )
}

export function ProjectTabs({
  codeProjects,
  researchProjects,
}: {
  codeProjects: CodeProject[]
  researchProjects: ResearchProject[]
}) {
  const { isPrivate, toggle } = usePrivateProjects()

  // Live data overlay — keyed by project id, merged over server-rendered props
  const [liveData, setLiveData] = useState<Map<string, Project>>(new Map())

  // Stable callback: useCallback with empty deps prevents useProjectEvents
  // from re-creating the EventSource on every render
  const handleUpdate = useCallback((projectId: string, project: Project) => {
    setLiveData((prev) => new Map(prev).set(projectId, project))
  }, [])

  useProjectEvents(handleUpdate)

  // Merge live data over server-rendered props — live data wins when present
  const resolvedCode = codeProjects.map(
    (p) => (liveData.get(p.id) as CodeProject) ?? p,
  )
  const resolvedResearch = researchProjects.map(
    (p) => (liveData.get(p.id) as ResearchProject) ?? p,
  )

  const codeVisible = resolvedCode.filter((p) => !isPrivate(p.id))
  const codePrivate = resolvedCode.filter((p) => isPrivate(p.id))
  const researchVisible = resolvedResearch.filter((p) => !isPrivate(p.id))
  const researchPrivate = resolvedResearch.filter((p) => isPrivate(p.id))

  return (
    <Tabs defaultValue="code">
      <TabsList className="h-auto gap-1 bg-transparent p-0">
        <TabsTrigger
          value="code"
          className={cn(
            triggerBase,
            'data-[state=active]:border-border data-[state=active]:bg-card/60',
            'data-[state=active]:text-primary data-[state=active]:shadow-[0_0_12px_oklch(0.715_0.143_212.34/0.1)]',
          )}
        >
          <Code className="size-4" />
          Code
          <span className="rounded-full bg-primary/10 px-2 py-0.5 font-mono text-xs text-primary/80">
            {codeVisible.length}
          </span>
        </TabsTrigger>
        <TabsTrigger
          value="research"
          className={cn(
            triggerBase,
            'data-[state=active]:border-border data-[state=active]:bg-card/60',
            'data-[state=active]:text-accent data-[state=active]:shadow-[0_0_12px_oklch(0.70_0.22_320.08/0.1)]',
          )}
        >
          <BookOpen className="size-4" />
          Research
          <span className="rounded-full bg-accent/10 px-2 py-0.5 font-mono text-xs text-accent/80">
            {researchVisible.length}
          </span>
        </TabsTrigger>
      </TabsList>

      <div className="rounded-lg rounded-tl-none border border-border bg-card/30 p-4 backdrop-blur-sm">
        <TabsContent value="code" className="mt-0">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            {codeVisible.map((project) => (
              <CodeProjectCard
                key={`code-${project.id}`}
                project={project}
                isPrivate={false}
                onTogglePrivate={() => toggle(project.id)}
              />
            ))}
          </div>
          {codePrivate.length > 0 && (
            <PrivateSection count={codePrivate.length}>
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                {codePrivate.map((project) => (
                  <CodeProjectCard
                    key={`code-${project.id}`}
                    project={project}
                    isPrivate={true}
                    onTogglePrivate={() => toggle(project.id)}
                  />
                ))}
              </div>
            </PrivateSection>
          )}
        </TabsContent>

        <TabsContent value="research" className="mt-0">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            {researchVisible.map((project) => (
              <ResearchProjectCard
                key={`research-${project.id}`}
                project={project}
                isPrivate={false}
                onTogglePrivate={() => toggle(project.id)}
              />
            ))}
          </div>
          {researchPrivate.length > 0 && (
            <PrivateSection count={researchPrivate.length}>
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                {researchPrivate.map((project) => (
                  <ResearchProjectCard
                    key={`research-${project.id}`}
                    project={project}
                    isPrivate={true}
                    onTogglePrivate={() => toggle(project.id)}
                  />
                ))}
              </div>
            </PrivateSection>
          )}
        </TabsContent>
      </div>
    </Tabs>
  )
}
