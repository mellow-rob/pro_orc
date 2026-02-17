'use client'

import { useSyncExternalStore, useCallback } from 'react'

const STORAGE_KEY = 'pro-orc-private-projects'

function getSnapshot(): Set<string> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? new Set(JSON.parse(raw)) : new Set()
  } catch {
    return new Set()
  }
}

const emptySet = new Set<string>()
const listeners = new Set<() => void>()
let cache = typeof window !== 'undefined' ? getSnapshot() : new Set<string>()

function subscribe(cb: () => void) {
  listeners.add(cb)
  return () => listeners.delete(cb)
}

function emitChange() {
  cache = getSnapshot()
  listeners.forEach((cb) => cb())
}

export function usePrivateProjects() {
  const ids = useSyncExternalStore(
    subscribe,
    () => cache,
    () => emptySet,
  )

  const toggle = useCallback((projectId: string) => {
    const current = getSnapshot()
    if (current.has(projectId)) {
      current.delete(projectId)
    } else {
      current.add(projectId)
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify([...current]))
    emitChange()
  }, [])

  const isPrivate = useCallback((projectId: string) => ids.has(projectId), [ids])

  return { isPrivate, toggle }
}
