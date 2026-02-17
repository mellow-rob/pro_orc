'use server'

import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

// ACT-01: Open project folder in Terminal.app
export async function openInTerminal(projectPath: string): Promise<void> {
  if (!projectPath.startsWith('/Users/') || projectPath.includes('..')) {
    throw new Error('Invalid project path')
  }
  const safePath = projectPath.replace(/'/g, "'\\''")
  await execAsync(`open -a Terminal '${safePath}'`)
}

// ACT-02: Open project folder in Finder
export async function openInFinder(projectPath: string): Promise<void> {
  if (!projectPath.startsWith('/Users/') || projectPath.includes('..')) {
    throw new Error('Invalid project path')
  }
  const safePath = projectPath.replace(/'/g, "'\\''")
  await execAsync(`open '${safePath}'`)
}

// ACT-03: Open Notion URL in default browser
export async function openNotionPage(notionUrl: string): Promise<void> {
  if (!notionUrl.startsWith('https://') && !notionUrl.startsWith('http://')) {
    throw new Error('Invalid URL')
  }
  const safeUrl = notionUrl.replace(/'/g, "'\\''")
  await execAsync(`open '${safeUrl}'`)
}
