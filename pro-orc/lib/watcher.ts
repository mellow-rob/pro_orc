// lib/watcher.ts
// Chokidar v3 singleton — initialized once at server startup, survives HMR.
// Must NOT import 'server-only' — this file is loaded via dynamic import from
// instrumentation.ts, outside the normal module graph where server-only resolves.

import chokidar, { type FSWatcher } from 'chokidar'
import path from 'path'
import { PATHS, projectIdFromPath } from '@/lib/paths'
import type { SseEvent } from '@/lib/types'

// ============================================================
// Global type augmentation — extend globalThis for persistence across HMR
// ============================================================
declare global {
  // eslint-disable-next-line no-var
  var __watcher: FSWatcher | undefined
  // eslint-disable-next-line no-var
  var __watcherSubscribers: Set<(event: SseEvent) => void> | undefined
  // eslint-disable-next-line no-var
  var __watcherDebounceTimers: Map<string, ReturnType<typeof setTimeout>> | undefined
}

// ============================================================
// Initialize subscriber Set and debounce Map (with guard)
// ============================================================
if (!globalThis.__watcherSubscribers) {
  globalThis.__watcherSubscribers = new Set()
}

if (!globalThis.__watcherDebounceTimers) {
  globalThis.__watcherDebounceTimers = new Map()
}

// ============================================================
// Initialize chokidar watcher (with guard — prevents duplicate watchers on HMR)
// ============================================================
if (!globalThis.__watcher) {
  console.log('[watcher] Initializing chokidar filesystem watcher...')

  globalThis.__watcher = chokidar.watch([PATHS.code, PATHS.research], {
    ignored: ['**/node_modules/**', '**/.git/**', '**/.next/**'],
    persistent: true,
    ignoreInitial: true,
    depth: 5,
  })

  globalThis.__watcher.on('all', (eventName, filePath) => {
    // Only process changes inside .planning/ directories
    if (!filePath.includes('.planning')) return

    // Extract project root — the segment immediately before /.planning/
    const planningIdx = filePath.indexOf('/.planning/')
    if (planningIdx === -1) return

    const projectRootPath = filePath.slice(0, planningIdx)
    const projectId = projectIdFromPath(projectRootPath)

    // Determine changedFile relative to project root
    const changedFile = path.relative(projectRootPath, filePath)

    // Debounce per projectId (300ms) — rapid saves produce a single event
    const existing = globalThis.__watcherDebounceTimers!.get(projectId)
    if (existing) clearTimeout(existing)

    const timer = setTimeout(() => {
      globalThis.__watcherDebounceTimers!.delete(projectId)

      const event: SseEvent = {
        type: 'project:updated',
        projectId,
        changedFile,
      }

      // Notify all SSE subscribers
      for (const subscriber of globalThis.__watcherSubscribers!) {
        subscriber(event)
      }
    }, 300)

    globalThis.__watcherDebounceTimers!.set(projectId, timer)
  })

  globalThis.__watcher.on('error', (err) => {
    console.error('[watcher] Chokidar error:', err)
  })

  console.log('[watcher] Watching:', [PATHS.code, PATHS.research])
}

// ============================================================
// Exported reference — SSE route uses this to register/deregister
// ============================================================
export const watcherSubscribers = globalThis.__watcherSubscribers!
