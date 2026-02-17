import 'server-only'

import simpleGit from 'simple-git'
import type { CodeProject } from '@/lib/types'

export type GitFields = Pick<CodeProject, 'lastCommitMessage' | 'lastCommitTimestamp' | 'lastCommitSha' | 'githubUrl'>

function remoteToGithubUrl(remoteUrl: string): string | undefined {
  // SSH: git@github.com:owner/repo.git
  const sshMatch = remoteUrl.match(/git@github\.com:(.+?)(?:\.git)?$/)
  if (sshMatch) return `https://github.com/${sshMatch[1]}`
  // HTTPS: https://github.com/owner/repo.git
  const httpsMatch = remoteUrl.match(/https?:\/\/github\.com\/(.+?)(?:\.git)?$/)
  if (httpsMatch) return `https://github.com/${httpsMatch[1]}`
  return undefined
}

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

    const [log, remotes] = await Promise.all([
      git.log({ maxCount: 1 }),
      git.getRemotes(true),
    ])

    if (!log.latest) return {}

    const origin = remotes.find(r => r.name === 'origin')
    const githubUrl = origin ? remoteToGithubUrl(origin.refs.fetch || origin.refs.push) : undefined

    return {
      lastCommitMessage: log.latest.message,
      lastCommitTimestamp: log.latest.date,
      lastCommitSha: log.latest.hash.slice(0, 7),
      ...(githubUrl && { githubUrl }),
    }
  } catch {
    return {}
  }
}
