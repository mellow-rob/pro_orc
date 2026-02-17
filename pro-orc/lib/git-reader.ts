import 'server-only'

import simpleGit from 'simple-git'
import type { CodeProject } from '@/lib/types'

export type GitFields = Pick<CodeProject, 'lastCommitMessage' | 'lastCommitTimestamp' | 'lastCommitSha'>

export async function getGitData(projectPath: string): Promise<GitFields> {
  try {
    const git = simpleGit({
      baseDir: projectPath,
      timeout: {
        block: 5000,
        stdOut: false,
        stdErr: false,
      },
    })

    const log = await git.log({ maxCount: 1 })

    if (!log.latest) return {}

    return {
      lastCommitMessage: log.latest.message,
      lastCommitTimestamp: log.latest.date,
      lastCommitSha: log.latest.hash.slice(0, 7),
    }
  } catch {
    return {}
  }
}
