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
  description?: string
  phasesCompleted?: number
  phasesTotal?: number
  plansCompleted?: number
  plansTotal?: number
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
  if (statusRaw.includes('complete') || statusRaw.includes('komplett')) return 'done'
  if (statusRaw.includes('archived') || statusRaw.includes('archiviert')) return 'archived'
  if (statusRaw.includes('paused') || statusRaw.includes('pausiert')) return 'paused'
  if (statusRaw.includes('research') || statusRaw.includes('recherche')) return 'research'
  if (statusRaw.includes('planning') || statusRaw.includes('planung')) return 'planning'
  if (statusRaw.includes('progress') || statusRaw.includes('fortschritt')) return 'building'
  // Any phase mentioned implies active building
  if (/phase\s+\d/i.test(statusRaw)) return 'building'
  return undefined
}

// ============================================================
// Internal: ROADMAP.md parser — phaseProgress from checkboxes
// ============================================================
function parseRoadmap(content: string | null): Pick<GsdParseResult, 'phaseProgress' | 'phasesCompleted' | 'phasesTotal' | 'plansCompleted' | 'plansTotal'> {
  if (!content) return {}

  // Plan lines: "- [x] NN-NN-PLAN.md" or "- [ ] NN-NN-PLAN.md"
  const plansDone = (content.match(/^- \[x\]\s+\d+-\d+-PLAN/gim) ?? []).length
  const plansPending = (content.match(/^- \[ \]\s+\d+-\d+-PLAN/gim) ?? []).length
  const plansTotal = plansDone + plansPending

  // Phase counting — two formats supported:
  // Format A (pro-orc style): "- [x] **Phase N:" checkbox lines
  const phaseCheckDone = (content.match(/^- \[x\]\s+\*\*Phase\s/gim) ?? []).length
  const phaseCheckPending = (content.match(/^- \[ \]\s+\*\*Phase\s/gim) ?? []).length
  const phaseCheckTotal = phaseCheckDone + phaseCheckPending

  let phasesTotal: number
  let phasesDone: number

  if (phaseCheckTotal > 0) {
    // Format A: phases are checkboxes
    phasesTotal = phaseCheckTotal
    phasesDone = phaseCheckDone
  } else {
    // Format B (site_intelligence/masterplan style): "### Phase N:" or "## Phase N:" headings
    // Derive completion by checking if ALL plans within each phase section are [x]
    const phaseHeadings = content.match(/^#{2,3}\s+Phase\s+\d/gim) ?? []
    phasesTotal = phaseHeadings.length

    if (phasesTotal > 0 && plansTotal > 0) {
      // Split content by phase headings and check plan completion per phase
      const sections = content.split(/^(?=#{2,3}\s+Phase\s+\d)/gim)
      phasesDone = 0
      for (const section of sections) {
        // Only count sections that are actual phase sections
        if (!/^#{2,3}\s+Phase\s+\d/im.test(section)) continue
        const sectionPlansDone = (section.match(/^- \[x\]\s+\d+-\d+-PLAN/gim) ?? []).length
        const sectionPlansPending = (section.match(/^- \[ \]\s+\d+-\d+-PLAN/gim) ?? []).length
        const sectionPlansTotal = sectionPlansDone + sectionPlansPending
        if (sectionPlansTotal > 0 && sectionPlansPending === 0) {
          phasesDone++
        }
      }
    } else {
      phasesDone = 0
    }
  }

  const result: Pick<GsdParseResult, 'phaseProgress' | 'phasesCompleted' | 'phasesTotal' | 'plansCompleted' | 'plansTotal'> = {}

  if (phasesTotal > 0) {
    result.phasesCompleted = phasesDone
    result.phasesTotal = phasesTotal
  }
  if (plansTotal > 0) {
    result.plansCompleted = plansDone
    result.plansTotal = plansTotal
  }

  // Progress = weighted average of phase completion and plan completion.
  // Both must be 100% for overall 100%. Phases weigh 50%, plans weigh 50%.
  if (phasesTotal > 0 && plansTotal > 0) {
    const phasePercent = phasesDone / phasesTotal
    const planPercent = plansDone / plansTotal
    result.phaseProgress = Math.round(((phasePercent + planPercent) / 2) * 100)
  } else if (phasesTotal > 0) {
    result.phaseProgress = Math.round((phasesDone / phasesTotal) * 100)
  } else if (plansTotal > 0) {
    result.phaseProgress = Math.round((plansDone / plansTotal) * 100)
  }

  return result
}

// ============================================================
// Internal: PROJECT.md parser — notionUrl from HTML comment
// ============================================================
function parseProject(content: string | null): Pick<GsdParseResult, 'notionUrl' | 'description'> {
  if (!content) return {}

  const notionMatch = content.match(/<!--\s*notion:\s*(https?:\/\/[^\s>]+)\s*-->/)

  // Description — first non-empty line after common heading variants
  let description: string | undefined
  const descMatch = content.match(/^##\s+(?:Core Value|Kernwert|Was ist das|What This Is|What is this)\s*\n+(.+)/im)
  if (descMatch) {
    // Strip bold prefix like "**Die eine Sache:**" but keep the rest
    description = descMatch[1].trim().replace(/^\*\*[^*]+\*\*:?\s*/, '').trim()
    // If stripping removed everything (whole line was bold), use original
    if (!description) description = descMatch[1].trim().replace(/\*\*/g, '')
    if (description.length > 200) description = description.slice(0, 197) + '...'
  }

  return {
    notionUrl: notionMatch?.[1],
    ...(description && { description }),
  }
}

// ============================================================
// Public: parse description from CLAUDE.md (fallback for non-GSD)
// ============================================================
export async function parseDescription(projectPath: string): Promise<string | undefined> {
  const content = await readFile(path.join(projectPath, 'CLAUDE.md'))
  if (!content) return undefined
  const match = content.match(/^##\s+(?:Project Overview|Project Purpose)\s*\n+(.+)/im)
  if (!match) return undefined
  // Strip bold/italic markers and "This is a **X** —" prefix patterns
  let desc = match[1].trim().replace(/\*\*/g, '')
  if (desc.length > 200) desc = desc.slice(0, 197) + '...'
  return desc
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

  const result = {
    ...parseState(stateContent),
    ...parseRoadmap(roadmapContent),
    ...parseProject(projectContent),
  }

  // If .planning/ exists but no status was derived, default to 'planning'
  if (!result.gsdStatus) {
    result.gsdStatus = 'planning'
  }

  // Post-process: "done" only when ALL phases are complete.
  // If status says "complete/komplett" but there are remaining phases, it's still "building".
  if (result.phasesTotal && result.phasesCompleted !== undefined) {
    if (result.phasesCompleted >= result.phasesTotal) {
      result.gsdStatus = 'done'
    } else if (result.gsdStatus === 'done') {
      result.gsdStatus = 'building'
    }
  }

  return result
}
