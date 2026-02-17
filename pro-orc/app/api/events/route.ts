// app/api/events/route.ts
// SSE endpoint — streams real-time project update events to connected clients.
// Signal-only pattern: events carry { type, projectId }, browser re-fetches data.

import { type NextRequest } from 'next/server'
import { watcherSubscribers } from '@/lib/watcher'
import type { SseEvent } from '@/lib/types'

export const dynamic = 'force-dynamic'

export function GET(request: NextRequest): Response {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    start(controller) {
      // Send initial ping to confirm connection
      controller.enqueue(
        encoder.encode('data: ' + JSON.stringify({ type: 'ping' }) + '\n\n')
      )

      // Subscriber function — encodes and enqueues SSE-formatted events
      const subscriber = (event: SseEvent) => {
        try {
          controller.enqueue(
            encoder.encode('data: ' + JSON.stringify(event) + '\n\n')
          )
        } catch {
          // Stream was closed — remove subscriber to prevent future errors
          watcherSubscribers.delete(subscriber)
        }
      }

      // Register with the watcher
      watcherSubscribers.add(subscriber)

      // Clean up when the client disconnects
      request.signal.addEventListener('abort', () => {
        watcherSubscribers.delete(subscriber)
        try {
          controller.close()
        } catch {
          // Already closed — ignore
        }
      })
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  })
}
