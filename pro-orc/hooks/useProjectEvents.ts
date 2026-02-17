'use client'

import { useEffect, useCallback } from 'react'
import type { Project, SseEvent } from '@/lib/types'

export function useProjectEvents(
  onUpdate: (projectId: string, data: Project) => void,
) {
  useEffect(() => {
    const source = new EventSource('/api/events')

    source.onmessage = async (event: MessageEvent) => {
      let sseEvent: SseEvent
      try {
        sseEvent = JSON.parse(event.data as string) as SseEvent
      } catch {
        return
      }

      if (sseEvent.type !== 'project:updated' || !sseEvent.projectId) {
        return
      }

      const projectId = sseEvent.projectId

      try {
        const res = await fetch('/api/projects/' + projectId)
        if (!res.ok) return
        const project = (await res.json()) as Project
        onUpdate(projectId, project)
      } catch {
        // Network errors are ignored — the next SSE event will trigger a retry
      }
    }

    // No-op error handler — EventSource reconnects automatically on error
    source.onerror = () => {}

    return () => {
      source.close()
    }
  }, [onUpdate])
}
