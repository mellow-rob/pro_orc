'use client'

import { useTransition } from 'react'
import { ExternalLink, BookOpen, Layers, Folder, Terminal, Eye, EyeOff } from 'lucide-react'
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { openInTerminal, openInFinder } from '@/app/actions'
import { StatusBadge } from '@/components/statusBadge'
import type { ResearchProject } from '@/lib/types'
import { cn } from '@/lib/utils'

export function ResearchProjectCard({
  project,
  isPrivate,
  onTogglePrivate,
}: {
  project: ResearchProject
  isPrivate?: boolean
  onTogglePrivate?: () => void
}) {
  const [isPending, startTransition] = useTransition()

  return (
    <Card
      className={cn(
        'border-accent/20 backdrop-blur-sm transition-shadow duration-200 hover:glow-fuchsia',
        isPrivate && 'opacity-60',
      )}
    >
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-2">
            {project.gsdStatus ? (
              <Layers className="size-4 shrink-0 text-accent" />
            ) : (
              <BookOpen className="size-4 shrink-0 text-accent" />
            )}
            <CardTitle className="text-base">{project.name}</CardTitle>
          </div>
          <div className="flex shrink-0 items-center gap-1">
            {onTogglePrivate && (
              <button
                onClick={onTogglePrivate}
                className={cn(
                  'rounded p-1 transition-colors hover:bg-muted',
                  isPrivate ? 'text-muted-foreground' : 'text-muted-foreground/30 hover:text-muted-foreground/60',
                )}
                title={isPrivate ? 'Mark as visible' : 'Mark as private'}
              >
                {isPrivate ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
              </button>
            )}
            {project.gsdStatus && <StatusBadge status={project.gsdStatus} />}
          </div>
        </div>
      </CardHeader>

      <CardContent className="space-y-2">
        {project.description && (
          <p className="line-clamp-2 text-xs text-muted-foreground/60 italic">
            {project.description}
          </p>
        )}

        {project.phaseProgress !== undefined && (
          <div className="space-y-1">
            <div className="flex justify-between text-xs text-muted-foreground">
              <span>Progress</span>
              <span>{project.phaseProgress}%</span>
            </div>
            <Progress value={project.phaseProgress} className="h-1.5" />
          </div>
        )}

        {(project.phasesTotal || project.plansTotal) && (
          <div className="flex gap-3 font-mono text-xs text-muted-foreground/70">
            {project.phasesTotal !== undefined && (
              <span>
                <span className="text-foreground/80">{project.phasesCompleted}</span>
                /{project.phasesTotal} phases
              </span>
            )}
            {project.plansTotal !== undefined && (
              <span>
                <span className="text-foreground/80">{project.plansCompleted}</span>
                /{project.plansTotal} plans
              </span>
            )}
          </div>
        )}

        {project.nextStep && (
          <p className="line-clamp-2 text-sm text-muted-foreground">
            {project.nextStep}
          </p>
        )}
      </CardContent>

      <CardFooter className="flex-wrap gap-2">
        <Button
          variant="ghost"
          size="sm"
          disabled={isPending}
          onClick={() => startTransition(() => openInTerminal(project.path))}
          className="border border-border text-muted-foreground/70 hover:border-accent/40 hover:bg-accent/10 hover:text-accent"
        >
          <Terminal className="size-3.5" />
          Terminal
        </Button>
        <Button
          variant="ghost"
          size="sm"
          disabled={isPending}
          onClick={() => startTransition(() => openInFinder(project.path))}
          className="border border-border text-muted-foreground/70 hover:border-accent/40 hover:bg-accent/10 hover:text-accent"
        >
          <Folder className="size-3.5" />
          Finder
        </Button>
        {project.notionUrl && (
          <Button variant="ghost" size="sm" asChild className="border border-border text-muted-foreground/70 hover:border-accent/40 hover:bg-accent/10 hover:text-accent">
            <a href={project.notionUrl} target="_blank" rel="noopener noreferrer">
              <ExternalLink className="size-3.5" />
              Notion
            </a>
          </Button>
        )}
      </CardFooter>
    </Card>
  )
}
