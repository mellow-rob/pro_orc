'use client'

import { useTransition } from 'react'
import { Terminal, Folder, Clock } from 'lucide-react'
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
} from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { openInTerminal, openInFinder } from '@/app/actions'
import { StatusBadge } from '@/components/statusBadge'
import type { CodeProject } from '@/lib/types'
import { cn } from '@/lib/utils'

function isStale(timestamp?: string): boolean {
  if (!timestamp) return false
  const thirtyDays = 30 * 24 * 60 * 60 * 1000
  return Date.now() - new Date(timestamp).getTime() > thirtyDays
}

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

export function CodeProjectCard({ project }: { project: CodeProject }) {
  const [isPending, startTransition] = useTransition()
  const stale = isStale(project.lastCommitTimestamp)

  return (
    <Card
      className={cn(
        'backdrop-blur-sm transition-shadow duration-200',
        stale ? 'border-amber-500/30 hover:glow-cyan' : 'hover:glow-cyan'
      )}
    >
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base">{project.name}</CardTitle>
          <div className="flex shrink-0 gap-1">
            {stale && (
              <Badge
                variant="outline"
                className="border-amber-500/50 text-xs text-amber-400"
              >
                Stale
              </Badge>
            )}
            {project.gsdStatus && <StatusBadge status={project.gsdStatus} />}
          </div>
        </div>
        {project.currentPhase && (
          <p className="font-mono text-xs text-muted-foreground">
            {project.currentPhase}
          </p>
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
          <p className="line-clamp-2 text-sm text-muted-foreground">
            {project.nextStep}
          </p>
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
