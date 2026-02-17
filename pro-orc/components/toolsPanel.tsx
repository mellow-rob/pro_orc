'use client'

import { Sparkles, Server, Puzzle } from 'lucide-react'
import { Card } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import type { ClaudeToolsData, ClaudeTool } from '@/lib/types'
import { cn } from '@/lib/utils'

// ============================================================
// Type badge — color-coded by tool type
// ============================================================
function TypeBadge({ type }: { type: ClaudeTool['type'] }) {
  if (type === 'skill') {
    return (
      <Badge
        className="border-cyan-500/30 bg-cyan-500/10 text-cyan-400"
        variant="outline"
      >
        skill
      </Badge>
    )
  }
  if (type === 'mcp') {
    return (
      <Badge
        className="border-fuchsia-500/30 bg-fuchsia-500/10 text-fuchsia-400"
        variant="outline"
      >
        mcp
      </Badge>
    )
  }
  return (
    <Badge variant="secondary">
      plugin
    </Badge>
  )
}

// ============================================================
// Individual tool card
// ============================================================
function ToolCard({ tool }: { tool: ClaudeTool }) {
  const isDisabled = tool.enabled === false

  return (
    <Card
      className={cn(
        'gap-3 border-border bg-card/40 py-4 backdrop-blur-sm',
        isDisabled && 'opacity-50',
      )}
    >
      <div className="flex items-start justify-between gap-2 px-4">
        <p className={cn('font-medium text-sm leading-tight', isDisabled && 'text-muted-foreground')}>
          {tool.name}
        </p>
        <TypeBadge type={tool.type} />
      </div>

      {tool.description && (
        <p className="line-clamp-2 px-4 text-xs text-muted-foreground">
          {tool.description}
        </p>
      )}

      {(isDisabled || tool.marketplace) && (
        <div className="flex items-center gap-2 px-4">
          {isDisabled && (
            <span className="font-mono text-xs text-muted-foreground/50">
              Disabled
            </span>
          )}
          {tool.marketplace && (
            <span className="font-mono text-xs text-muted-foreground/60">
              {tool.marketplace}
            </span>
          )}
        </div>
      )}
    </Card>
  )
}

// ============================================================
// Category section — heading + grid of cards
// ============================================================
function CategorySection({
  icon,
  label,
  tools,
}: {
  icon: React.ReactNode
  label: string
  tools: ClaudeTool[]
}) {
  if (tools.length === 0) return null

  return (
    <div>
      <div className="mb-3 flex items-center gap-2 text-sm font-medium text-muted-foreground">
        {icon}
        {label}
        <span className="font-mono text-xs text-muted-foreground/50">({tools.length})</span>
      </div>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
        {tools.map((tool) => (
          <ToolCard key={tool.id} tool={tool} />
        ))}
      </div>
    </div>
  )
}

// ============================================================
// ToolsPanel — main export
// Props: { tools: ClaudeToolsData }
// ============================================================
export function ToolsPanel({ tools }: { tools: ClaudeToolsData }) {
  const total = tools.skills.length + tools.mcpPlugins.length + tools.skillPlugins.length

  if (total === 0) {
    return (
      <div className="flex min-h-32 items-center justify-center text-sm text-muted-foreground">
        No Claude tools found in ~/.claude/
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <CategorySection
        icon={<Sparkles className="size-4" />}
        label="Skills"
        tools={tools.skills}
      />
      <CategorySection
        icon={<Server className="size-4" />}
        label="MCP Servers"
        tools={tools.mcpPlugins}
      />
      <CategorySection
        icon={<Puzzle className="size-4" />}
        label="Plugins"
        tools={tools.skillPlugins}
      />
    </div>
  )
}
