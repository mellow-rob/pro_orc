import { describe, it, expect, vi } from 'vitest'
import path from 'path'
import fs from 'fs'
import os from 'os'

// Mock server-only (not available in test environment)
vi.mock('server-only', () => ({}))

import { getGitData, type GitFields } from '@/lib/git-reader'
import type { CodeProject } from '@/lib/types'

describe('getGitData', () => {
  it('returns commit data for a real git project', async () => {
    // Use the pro-orc directory itself (which is inside a git repo)
    const projectPath = path.resolve(__dirname, '../../')
    const result = await getGitData(projectPath)

    expect(result.lastCommitMessage).toBeDefined()
    expect(typeof result.lastCommitMessage).toBe('string')
    expect(result.lastCommitMessage!.length).toBeGreaterThan(0)

    expect(result.lastCommitTimestamp).toBeDefined()
    expect(typeof result.lastCommitTimestamp).toBe('string')
    expect(result.lastCommitTimestamp!.length).toBeGreaterThan(0)

    expect(result.lastCommitSha).toBeDefined()
    expect(typeof result.lastCommitSha).toBe('string')
    expect(result.lastCommitSha).toHaveLength(7)
  })

  it('returns empty object for non-git directory', async () => {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'git-reader-test-'))

    try {
      const result = await getGitData(tempDir)
      expect(result).toEqual({})
      expect(Object.keys(result)).toHaveLength(0)
    } finally {
      fs.rmSync(tempDir, { recursive: true, force: true })
    }
  })

  it('returns empty object for nonexistent path', async () => {
    const result = await getGitData('/tmp/definitely-not-a-real-path-xyz123')
    expect(result).toEqual({})
    expect(Object.keys(result)).toHaveLength(0)
  })

  it('GitFields type is assignable to Partial<CodeProject>', () => {
    // Type-level test: if this compiles, GitFields is compatible with Partial<CodeProject>
    const gitFields: GitFields = {
      lastCommitMessage: 'test',
      lastCommitTimestamp: '2026-01-01T00:00:00Z',
      lastCommitSha: 'abc1234',
    }
    const partial: Partial<CodeProject> = gitFields
    expect(partial).toBeDefined()
  })
})
