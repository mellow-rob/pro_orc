import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

const STATUS_STYLES: Record<string, string> = {
  building: 'border-primary/50 text-primary',
  done: 'border-green-500/50 text-green-400',
  paused: 'border-amber-500/50 text-amber-400',
  research: 'border-accent/50 text-accent',
  planning: 'border-blue-500/50 text-blue-400',
  archived: 'border-border text-muted-foreground',
}

export function StatusBadge({ status }: { status: string }) {
  const style = STATUS_STYLES[status] ?? 'border-border text-muted-foreground'
  return (
    <Badge variant="outline" className={cn('text-xs capitalize', style)}>
      {status}
    </Badge>
  )
}
