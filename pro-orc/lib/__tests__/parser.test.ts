// lib/__tests__/parser.test.ts
import { describe, it, expect, vi, beforeAll, afterAll } from 'vitest'
import { promises as fs } from 'fs'
import path from 'path'
import os from 'os'

// Mock server-only — it throws when imported outside Next.js
vi.mock('server-only', () => ({}))

import { parseGsdData, type GsdParseResult } from '@/lib/parser'

// ============================================================
// Helper: create a temporary .planning/ directory with files
// ============================================================
async function createTempProject(files: Record<string, string>): Promise<string> {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'parser-test-'))
  const planningDir = path.join(tmpDir, '.planning')
  await fs.mkdir(planningDir, { recursive: true })

  for (const [name, content] of Object.entries(files)) {
    await fs.writeFile(path.join(planningDir, name), content, 'utf-8')
  }

  return tmpDir
}

async function cleanupTempDir(dir: string): Promise<void> {
  await fs.rm(dir, { recursive: true, force: true })
}

// ============================================================
// STATE.md parsing — currentPhase
// ============================================================
describe('parseState — currentPhase', () => {
  it('extracts phase from **Phase:** format', async () => {
    const dir = await createTempProject({
      'STATE.md': '# State\n\n**Phase:** 3 of 5 (API Layer)\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.currentPhase).toBe('3 of 5 (API Layer)')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('extracts phase from **Current Phase:** format', async () => {
    const dir = await createTempProject({
      'STATE.md': '# State\n\n**Current Phase:** 2 of 3 -- COMPLETE\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.currentPhase).toBe('2 of 3 -- COMPLETE')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('extracts phase from plain Phase: format (no bold)', async () => {
    const dir = await createTempProject({
      'STATE.md': '# State\n\nPhase: 1 of 5 (Foundation)\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.currentPhase).toBe('1 of 5 (Foundation)')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('returns undefined for empty string', async () => {
    const dir = await createTempProject({ 'STATE.md': '' })
    try {
      const result = await parseGsdData(dir)
      expect(result.currentPhase).toBeUndefined()
    } finally {
      await cleanupTempDir(dir)
    }
  })
})

// ============================================================
// STATE.md parsing — gsdStatus
// ============================================================
describe('parseState — gsdStatus', () => {
  it('maps "Phase complete" to done', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** Phase complete\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('done')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps "Phase 3 in progress" to building', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** Phase 3 in progress\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('building')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps "archived" to archived', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** Project archived\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('archived')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps "paused" to paused', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** Development paused\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('paused')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps "research" to research', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** In research phase\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('research')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps "planning" to planning', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** Initial planning\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('planning')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps status with phase number to building', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Status:** Phase 2 active\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('building')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('maps plain Status: format (no bold) to correct status', async () => {
    const dir = await createTempProject({
      'STATE.md': 'Status: Phase complete\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBe('done')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('returns undefined for empty status', async () => {
    const dir = await createTempProject({
      'STATE.md': '# State\nSome content without status\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.gsdStatus).toBeUndefined()
    } finally {
      await cleanupTempDir(dir)
    }
  })
})

// ============================================================
// STATE.md parsing — nextStep
// ============================================================
describe('parseState — nextStep', () => {
  it('extracts from **Next Action:** format', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Next Action:** Implement scanner\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.nextStep).toBe('Implement scanner')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('extracts from **Next Step:** format', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Next Step:** Build the UI components\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.nextStep).toBe('Build the UI components')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('returns undefined when no next step pattern matches', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Phase:** 1 of 3\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.nextStep).toBeUndefined()
    } finally {
      await cleanupTempDir(dir)
    }
  })
})

// ============================================================
// ROADMAP.md parsing — phaseProgress
// ============================================================
describe('parseRoadmap — phaseProgress', () => {
  it('calculates progress from checkboxes (3 done, 2 pending = 60%)', async () => {
    const dir = await createTempProject({
      'ROADMAP.md': [
        '# Roadmap',
        '- [x] Plan 1',
        '- [x] Plan 2',
        '- [x] Plan 3',
        '- [ ] Plan 4',
        '- [ ] Plan 5',
      ].join('\n'),
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.phaseProgress).toBe(60)
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('returns undefined when no checkboxes found', async () => {
    const dir = await createTempProject({
      'ROADMAP.md': '# Roadmap\n\nSome text without checkboxes\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.phaseProgress).toBeUndefined()
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('returns 100 when all checkboxes are completed', async () => {
    const dir = await createTempProject({
      'ROADMAP.md': '- [x] Plan 1\n- [x] Plan 2\n- [x] Plan 3\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.phaseProgress).toBe(100)
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('handles case-insensitive [X] checkboxes', async () => {
    const dir = await createTempProject({
      'ROADMAP.md': '- [X] Plan 1\n- [x] Plan 2\n- [ ] Plan 3\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.phaseProgress).toBe(67) // Math.round(2/3 * 100)
    } finally {
      await cleanupTempDir(dir)
    }
  })
})

// ============================================================
// PROJECT.md parsing — notionUrl
// ============================================================
describe('parseProject — notionUrl', () => {
  it('extracts notion URL from HTML comment', async () => {
    const dir = await createTempProject({
      'PROJECT.md': '# My Project\n<!-- notion: https://notion.so/abc123 -->\n\nContent here\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.notionUrl).toBe('https://notion.so/abc123')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('returns undefined when no notion comment present', async () => {
    const dir = await createTempProject({
      'PROJECT.md': '# My Project\n\nJust content, no notion link\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.notionUrl).toBeUndefined()
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('handles notion comment with extra whitespace', async () => {
    const dir = await createTempProject({
      'PROJECT.md': '<!--  notion:  https://notion.so/workspace/page-id  -->\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.notionUrl).toBe('https://notion.so/workspace/page-id')
    } finally {
      await cleanupTempDir(dir)
    }
  })
})

// ============================================================
// Integration: missing/nonexistent paths
// ============================================================
describe('parseGsdData — missing data handling', () => {
  it('returns empty object for nonexistent path', async () => {
    const result = await parseGsdData('/nonexistent/path/that/does/not/exist')
    expect(result).toEqual({})
  })

  it('returns empty object for path with no .planning/ directory', async () => {
    const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'parser-test-noplan-'))
    try {
      const result = await parseGsdData(tmpDir)
      expect(result).toEqual({})
    } finally {
      await cleanupTempDir(tmpDir)
    }
  })

  it('returns partial data when only some files exist', async () => {
    const dir = await createTempProject({
      'STATE.md': '**Phase:** 2 of 4\n**Status:** Phase 2 in progress\n',
      // No ROADMAP.md or PROJECT.md
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.currentPhase).toBe('2 of 4')
      expect(result.gsdStatus).toBe('building')
      expect(result.phaseProgress).toBeUndefined()
      expect(result.notionUrl).toBeUndefined()
    } finally {
      await cleanupTempDir(dir)
    }
  })
})

// ============================================================
// Integration: real project directory
// ============================================================
describe('parseGsdData — real project integration', () => {
  const realProjectPath = path.join(os.homedir(), 'project_orchestration')

  it('parses real .planning/ directory without crashing', async () => {
    const result = await parseGsdData(realProjectPath)
    // This project has .planning/ with STATE.md, ROADMAP.md, PROJECT.md
    expect(result).toBeDefined()
    expect(typeof result).toBe('object')
    // Should have some data from the real files — at minimum gsdStatus and phaseProgress
    expect(result.gsdStatus).toBeDefined()
    expect(result.phaseProgress).toBeDefined()
  })

  it('extracts gsdStatus as a known value from real STATE.md', async () => {
    const result = await parseGsdData(realProjectPath)
    // Real STATE.md has "Status: Phase complete" -> done
    expect(result.gsdStatus).toBeDefined()
    expect(['research', 'planning', 'building', 'paused', 'done', 'archived']).toContain(result.gsdStatus)
  })
})

// ============================================================
// Edge cases: combined data from all three files
// ============================================================
describe('parseGsdData — combined parsing', () => {
  it('combines data from all three files', async () => {
    const dir = await createTempProject({
      'STATE.md': [
        '**Phase:** 3 of 5 (API Layer)',
        '**Status:** Phase 3 in progress',
        '**Next Action:** Build endpoints',
      ].join('\n'),
      'ROADMAP.md': [
        '- [x] Plan 1',
        '- [x] Plan 2',
        '- [ ] Plan 3',
        '- [ ] Plan 4',
      ].join('\n'),
      'PROJECT.md': '# API Project\n<!-- notion: https://notion.so/my-project -->\n',
    })
    try {
      const result = await parseGsdData(dir)
      expect(result.currentPhase).toBe('3 of 5 (API Layer)')
      expect(result.gsdStatus).toBe('building')
      expect(result.nextStep).toBe('Build endpoints')
      expect(result.phaseProgress).toBe(50)
      expect(result.notionUrl).toBe('https://notion.so/my-project')
    } finally {
      await cleanupTempDir(dir)
    }
  })

  it('handles null content from all files gracefully', async () => {
    const result = await parseGsdData('/totally/fake/path')
    expect(result).toEqual({})
  })
})
