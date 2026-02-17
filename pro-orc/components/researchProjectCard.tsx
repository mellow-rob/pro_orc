'use client'

import { ExternalLink, BookOpen } from 'lucide-react'
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
} from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { StatusBadge } from '@/components/statusBadge'
import type { ResearchProject } from '@/lib/types'
import { cn } from '@/lib/utils'

export function ResearchProjectCard({
  project,
}: {
  project: ResearchProject
}) {
  return (
    <Card
      className={cn(
        'border-accent/20 backdrop-blur-sm transition-shadow duration-200 hover:glow-fuchsia'
      )}
    >
      <CardHeader>
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-2">
            <BookOpen className="size-4 shrink-0 text-accent" />
            <CardTitle className="text-base">{project.name}</CardTitle>
          </div>
          {project.gsdStatus && <StatusBadge status={project.gsdStatus} />}
        </div>
      </CardHeader>

      {project.nextStep && (
        <CardContent>
          <p className="line-clamp-2 text-sm text-muted-foreground">
            {project.nextStep}
          </p>
        </CardContent>
      )}

      {project.notionUrl && (
        <CardFooter>
          <Button variant="outline" size="sm" asChild>
            <a
              href={project.notionUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              <ExternalLink className="size-3.5" />
              Open Notion
            </a>
          </Button>
        </CardFooter>
      )}
    </Card>
  )
}
