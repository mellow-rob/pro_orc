import 'server-only'

import { promises as fs } from 'fs'
import path from 'path'
import { PATHS, projectIdFromPath } from '@/lib/paths'
import type { Project, CodeProject, ResearchProject } from '@/lib/types'
import { parseGsdData } from '@/lib/parser'
import { getGitData } from '@/lib/git-reader'

// ============================================================
// Internal: scan a root directory for non-hidden subdirectories
// ============================================================
interface BaseEntry {
  id: string
  name: string
  path: string
  gsdStatus?: string
  currentPhase?: string
  nextStep?: string
  phaseProgress?: number
  notionUrl?: string
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

      return {
        id,
        name,
        path: projectPath,
        ...gsdData,
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
