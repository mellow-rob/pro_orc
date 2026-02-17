// lib/paths.ts
import os from 'os'
import path from 'path'

const HOME = os.homedir()
const BASE = path.join(HOME, 'project_orchestration')

export const PATHS = {
  base: BASE,
  code: path.join(BASE, 'code'),
  research: path.join(BASE, 'project research'),
  claude: path.join(HOME, '.claude'),
} as const

// Helper: get the .planning/ directory for a project
export function planningDir(projectPath: string): string {
  return path.join(projectPath, '.planning')
}

// Helper: resolve a project ID from its absolute path
export function projectIdFromPath(projectPath: string): string {
  return path.basename(projectPath)
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
}
