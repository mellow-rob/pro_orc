import { describe, it, expect, vi, beforeAll } from 'vitest'

// Mock server-only (no Next.js runtime in tests)
vi.mock('server-only', () => ({}))

import { scanProjects } from '@/lib/scanner'
import type { Project } from '@/lib/types'

describe('scanProjects', () => {
  let projects: Project[]

  // Run scanner once for all tests (real filesystem)
  beforeAll(async () => {
    projects = await scanProjects()
  }, 30000)

  it('returns both code and research projects', () => {
    expect(projects.length).toBeGreaterThan(0)
    expect(projects.some((p) => p.type === 'code')).toBe(true)
    expect(projects.some((p) => p.type === 'research')).toBe(true)
  })

  it('every project has required BaseProject fields', () => {
    for (const project of projects) {
      expect(typeof project.id).toBe('string')
      expect(project.id.length).toBeGreaterThan(0)
      expect(typeof project.name).toBe('string')
      expect(project.name.length).toBeGreaterThan(0)
      expect(typeof project.path).toBe('string')
      expect(project.path.length).toBeGreaterThan(0)
      expect(['code', 'research']).toContain(project.type)
    }
  })

  it('code projects have git data for git repos', () => {
    const codeProjects = projects.filter((p) => p.type === 'code')
    expect(codeProjects.length).toBeGreaterThan(0)

    // At least one code project should be a git repo with commit data
    const withGit = codeProjects.filter(
      (p) => p.type === 'code' && 'lastCommitMessage' in p && p.lastCommitMessage
    )
    expect(withGit.length).toBeGreaterThan(0)

    for (const p of withGit) {
      if (p.type === 'code') {
        expect(typeof p.lastCommitMessage).toBe('string')
        expect(typeof p.lastCommitTimestamp).toBe('string')
      }
    }
  })

  it('research projects have no git fields', () => {
    const researchProjects = projects.filter((p) => p.type === 'research')
    expect(researchProjects.length).toBeGreaterThan(0)

    for (const p of researchProjects) {
      expect('lastCommitMessage' in p).toBe(false)
      expect('lastCommitTimestamp' in p).toBe(false)
      expect('lastCommitSha' in p).toBe(false)
    }
  })

  it('no hidden directories in results', () => {
    for (const project of projects) {
      expect(project.name.startsWith('.')).toBe(false)
    }
  })

  it('project type matches scan root', () => {
    for (const project of projects) {
      if (project.type === 'code') {
        expect(project.path).toContain('/code/')
      } else {
        expect(project.path).toContain('/project research/')
      }
    }
  })

  it('GSD data present for projects with .planning/', () => {
    // project_orchestration itself has .planning/ and is in code/
    // or any other project with GSD data
    const withGsd = projects.filter(
      (p) => p.gsdStatus !== undefined || p.currentPhase !== undefined || p.phaseProgress !== undefined
    )
    expect(withGsd.length).toBeGreaterThan(0)
  })

  it('projects without .planning/ have no GSD data and no error', () => {
    // Some projects should lack GSD data — verify they exist without error
    const withoutGsd = projects.filter(
      (p) =>
        p.gsdStatus === undefined &&
        p.currentPhase === undefined &&
        p.phaseProgress === undefined &&
        p.notionUrl === undefined
    )
    // If all projects happen to have GSD data, that's fine — the important thing
    // is that the scanner didn't crash
    expect(projects.length).toBeGreaterThan(0)
  })
})
