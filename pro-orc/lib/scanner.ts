import 'server-only'

import { promises as fs } from 'fs'
import path from 'path'
import { PATHS, projectIdFromPath } from '@/lib/paths'
import type { Project, CodeProject, ResearchProject } from '@/lib/types'
import { parseGsdData, parseDescription } from '@/lib/parser'
import { getGitData } from '@/lib/git-reader'

// ============================================================
// Internal: scan a root directory for non-hidden subdirectories
// ============================================================
interface BaseEntry {
  id: string
  name: string
  path: string
  description?: string
  gsdStatus?: string
  currentPhase?: string
  nextStep?: string
  phaseProgress?: number
  notionUrl?: string
  phasesCompleted?: number
  phasesTotal?: number
  plansCompleted?: number
  plansTotal?: number
}

async function scanDir(rootPath: string): Promise<BaseEntry[]> {
  const entries = await fs.readdir(rootPath, { withFileTypes: true })

  const dirs = entries.filter(
    (entry) => entry.isDirectory() && !entry.name.startsWith('.')
  )

  const results: BaseEntry[] = await Promise.all(
    dirs.map(async (entry) => {
      const projectPath = path.join(rootPath, entry.name)
      const id = projectIdFromPath(projectPath)
      const name = entry.name
      const gsdData = await parseGsdData(projectPath)

      // Fallback description from CLAUDE.md if GSD didn't provide one
      let description = gsdData.description
      if (!description) {
        description = await parseDescription(projectPath)
      }

      return {
        id,
        name,
        path: projectPath,
        ...gsdData,
        ...(description && { description }),
      }
    })
  )

  return results
}

// ============================================================
// Public: scan all project directories and return typed Project[]
// ============================================================
export async function scanProjects(): Promise<Project[]> {
  // 1. Scan both roots concurrently — missing dirs return empty arrays
  const [codeDirs, researchDirs] = await Promise.all([
    scanDir(PATHS.code).catch(() => [] as BaseEntry[]),
    scanDir(PATHS.research).catch(() => [] as BaseEntry[]),
  ])

  // 2. Enrich code projects with git data concurrently via Promise.allSettled
  const gitResults = await Promise.allSettled(
    codeDirs.map((p) => getGitData(p.path))
  )

  const codeProjects: CodeProject[] = codeDirs.map((project, i) => {
    const gitResult = gitResults[i]
    const gitData = gitResult.status === 'fulfilled' ? gitResult.value : {}
    return { ...project, type: 'code' as const, ...gitData }
  })

  // 3. Research projects get no git data
  const researchProjects: ResearchProject[] = researchDirs.map((p) => ({
    ...p,
    type: 'research' as const,
  }))

  // 4. Return combined list
  return [...codeProjects, ...researchProjects]
}

// ============================================================
// Public: scan a single project by ID and return typed Project | null
// ============================================================
export async function scanProjectById(id: string): Promise<Project | null> {
  // 1. Try direct path lookup in PATHS.code
  const codePath = path.join(PATHS.code, id)
  try {
    await fs.stat(codePath)
    // Found in code root — enrich with git data
    const gsdData = await parseGsdData(codePath)
    let description = gsdData.description
    if (!description) {
      description = await parseDescription(codePath)
    }
    const gitData = await getGitData(codePath).catch(() => ({}))
    const project: CodeProject = {
      id: projectIdFromPath(codePath),
      name: id,
      path: codePath,
      type: 'code',
      ...gsdData,
      ...(description && { description }),
      ...gitData,
    }
    return project
  } catch {
    // Not found in code root — try research
  }

  // 2. Try direct path lookup in PATHS.research
  const researchPath = path.join(PATHS.research, id)
  try {
    await fs.stat(researchPath)
    // Found in research root — no git data
    const gsdData = await parseGsdData(researchPath)
    let description = gsdData.description
    if (!description) {
      description = await parseDescription(researchPath)
    }
    const project: ResearchProject = {
      id: projectIdFromPath(researchPath),
      name: id,
      path: researchPath,
      type: 'research',
      ...gsdData,
      ...(description && { description }),
    }
    return project
  } catch {
    // Not found by direct path — fall back to full scan
  }

  // 3. Fall back: scan both roots and filter by matching id
  const [codeDirs, researchDirs] = await Promise.all([
    scanDir(PATHS.code).catch(() => [] as Awaited<ReturnType<typeof scanDir>>),
    scanDir(PATHS.research).catch(() => [] as Awaited<ReturnType<typeof scanDir>>),
  ])

  const codeEntry = codeDirs.find((e) => e.id === id)
  if (codeEntry) {
    const gitData = await getGitData(codeEntry.path).catch(() => ({}))
    return { ...codeEntry, type: 'code' as const, ...gitData }
  }

  const researchEntry = researchDirs.find((e) => e.id === id)
  if (researchEntry) {
    return { ...researchEntry, type: 'research' as const }
  }

  return null
}
