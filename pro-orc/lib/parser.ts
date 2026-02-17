// lib/parser.ts
import 'server-only'
import { promises as fs } from 'fs'
import path from 'path'
import { planningDir } from '@/lib/paths'
import type { GsdStatus } from '@/lib/types'

// ============================================================
// GSD Parse Result — partial data from .planning/ files
// ============================================================
export interface GsdParseResult {
  gsdStatus?: GsdStatus
  currentPhase?: string
  nextStep?: string
  phaseProgress?: number
  notionUrl?: string
}

// ============================================================
// Internal: safe file reader — returns null on any error
// ============================================================
async function readFile(filePath: string): Promise<string | null> {
  try {
    return await fs.readFile(filePath, 'utf-8')
  } catch {
    return null // ENOENT, EACCES, mid-save corruption — all treated as missing
  }
}

// ============================================================
// Internal: STATE.md parser — currentPhase, gsdStatus, nextStep
// ============================================================
function parseState(content: string | null): Pick<GsdParseResult, 'gsdStatus' | 'currentPhase' | 'nextStep'> {
  if (!content) return {}

  // Current Phase — multiple field name variants seen in real projects
  // Both bold (**Phase:**) and plain (Phase:) formats exist in the wild
  const phasePatterns = [
    /^\*\*Phase:\*\*\s*(.+)$/m,
    /^\*\*Current Phase:\*\*\s*(.+)$/m,
    /^\*\*Aktuelle Phase:\*\*\s*(.+)$/m,
    /^Phase:\s*(.+)$/m,
    /^Current Phase:\s*(.+)$/m,
    /^Aktuelle Phase:\s*(.+)$/m,
  ]
  let currentPhase: string | undefined
  for (const pattern of phasePatterns) {
    const match = content.match(pattern)
    if (match) {
      currentPhase = match[1].trim()
      break
    }
  }

  // Status — derive GsdStatus from free-form STATUS field (bold or plain)
  const statusMatch = content.match(/^\*\*Status:\*\*\s*(.+)$/m)
    ?? content.match(/^Status:\s*(.+)$/m)
  const statusRaw = statusMatch?.[1]?.trim().toLowerCase() ?? ''
  const gsdStatus = deriveStatus(statusRaw)

  // Next step — multiple field name variants (bold and plain)
  const nextStepPatterns = [
    /^\*\*Next Action:\*\*\s*(.+)$/m,
    /^\*\*Next Step:\*\*\s*(.+)$/m,
    /^\*\*Nächster Schritt:\*\*\s*(.+)$/m,
    /^Next Action:\s*(.+)$/m,
    /^Next Step:\s*(.+)$/m,
    /^Nächster Schritt:\s*(.+)$/m,
  ]
  let nextStep: string | undefined
  for (const pattern of nextStepPatterns) {
    const match = content.match(pattern)
    if (match) {
      nextStep = match[1].trim()
      break
    }
  }

  return { gsdStatus, currentPhase, nextStep }
}

// ============================================================
// Internal: derive GsdStatus from free-form status text
// ============================================================
function deriveStatus(statusRaw: string): GsdStatus | undefined {
  if (!statusRaw) return undefined
  if (statusRaw.includes('complete')) return 'done'
  if (statusRaw.includes('archived')) return 'archived'
  if (statusRaw.includes('paused')) return 'paused'
  if (statusRaw.includes('research')) return 'research'
  if (statusRaw.includes('planning')) return 'planning'
  if (statusRaw.includes('progress')) return 'building'
  // Any phase mentioned implies active building
  if (/phase\s+\d/i.test(statusRaw)) return 'building'
  return undefined
}

// ============================================================
// Internal: ROADMAP.md parser — phaseProgress from checkboxes
// ============================================================
function parseRoadmap(content: string | null): Pick<GsdParseResult, 'phaseProgress'> {
  if (!content) return {}

  const completed = (content.match(/^- \[x\]/gim) ?? []).length
  const pending = (content.match(/^- \[ \]/gm) ?? []).length
  const total = completed + pending

  if (total === 0) return {} // No plan checkboxes — don't return 0%, return undefined

  return { phaseProgress: Math.round((completed / total) * 100) }
}

// ============================================================
// Internal: PROJECT.md parser — notionUrl from HTML comment
// ============================================================
function parseProject(content: string | null): Pick<GsdParseResult, 'notionUrl'> {
  if (!content) return {}

  const notionMatch = content.match(/<!--\s*notion:\s*(https?:\/\/[^\s>]+)\s*-->/)
  return { notionUrl: notionMatch?.[1] }
}

// ============================================================
// Public: parse all GSD data from a project's .planning/ dir
// ============================================================
export async function parseGsdData(projectPath: string): Promise<GsdParseResult> {
  const dir = planningDir(projectPath)

  // Read all three files concurrently — each independently null-safe
  const [stateContent, roadmapContent, projectContent] = await Promise.all([
    readFile(path.join(dir, 'STATE.md')),
    readFile(path.join(dir, 'ROADMAP.md')),
    readFile(path.join(dir, 'PROJECT.md')),
  ])

  // No .planning/ data at all — not an error, just "no GSD data"
  if (!stateContent && !roadmapContent && !projectContent) {
    return {}
  }

  return {
    ...parseState(stateContent),
    ...parseRoadmap(roadmapContent),
    ...parseProject(projectContent),
  }
}
