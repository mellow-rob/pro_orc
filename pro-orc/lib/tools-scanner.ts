import 'server-only'

import { promises as fs, Dirent } from 'fs'
import path from 'path'
import { PATHS } from '@/lib/paths'
import type { ClaudeTool, ClaudeToolsData } from '@/lib/types'

// ============================================================
// Internal: parse YAML frontmatter from skill.md content
// Uses manual regex — no js-yaml required for simple name/description fields
// ============================================================
function parseFrontmatter(content: string): { name?: string; description?: string } | null {
  if (!content.startsWith('---')) return null

  const endIdx = content.indexOf('---', 3)
  if (endIdx === -1) return null

  const frontmatterBlock = content.slice(3, endIdx)
  const result: { name?: string; description?: string } = {}

  for (const line of frontmatterBlock.split('\n')) {
    const match = line.match(/^(\w+):\s*(.+)$/)
    if (match) {
      const key = match[1]
      const value = match[2].trim().replace(/^['"]|['"]$/g, '') // strip optional quotes
      if (key === 'name') result.name = value
      if (key === 'description') result.description = value
    }
  }

  return result
}

// ============================================================
// Internal: read skill.md (tries lowercase then uppercase)
// Returns parsed name/description or null on any error
// ============================================================
async function readSkillMd(dirPath: string): Promise<{ name?: string; description?: string } | null> {
  for (const filename of ['skill.md', 'SKILL.md']) {
    try {
      const content = await fs.readFile(path.join(dirPath, filename), 'utf-8')
      return parseFrontmatter(content)
    } catch {
      // Try next filename
    }
  }
  return null
}

// ============================================================
// Internal: scan ~/.claude/skills/ for skill entries
// Handles both real directories and symlinks via fs.realpath
// ============================================================
async function scanSkills(): Promise<ClaudeTool[]> {
  const skillsDir = path.join(PATHS.claude, 'skills')

  let entries: Dirent[]
  try {
    entries = await fs.readdir(skillsDir, { withFileTypes: true })
  } catch {
    return []
  }

  const skillEntries = entries.filter((e) => e.isDirectory() || e.isSymbolicLink())

  return Promise.all(
    skillEntries.map(async (entry) => {
      const entryPath = path.join(skillsDir, entry.name)
      const realPath = await fs.realpath(entryPath).catch(() => entryPath)
      const skillMd = await readSkillMd(realPath)

      return {
        id: entry.name,
        name: skillMd?.name ?? entry.name,
        type: 'skill' as const,
        description: skillMd?.description,
      }
    })
  )
}

// ============================================================
// Internal: read enabled plugin state from ~/.claude/settings.json
// Returns {} on any error — safe fallback
// ============================================================
async function readSettings(): Promise<Record<string, boolean>> {
  const settingsPath = path.join(PATHS.claude, 'settings.json')
  try {
    const raw = await fs.readFile(settingsPath, 'utf-8')
    const settings = JSON.parse(raw) as { enabledPlugins?: Record<string, boolean> }
    return settings.enabledPlugins ?? {}
  } catch {
    return {}
  }
}

// ============================================================
// Internal types for installed_plugins.json structure
// ============================================================
interface PluginInstall {
  scope: string
  installPath: string
  version: string
  installedAt: string
}

interface InstalledPluginsJson {
  version: number
  plugins: Record<string, PluginInstall[]>
}

// ============================================================
// Internal: scan ~/.claude/plugins/installed_plugins.json
// For each plugin: reads manifest, detects MCP via .mcp.json
// ============================================================
async function scanPlugins(enabledPlugins: Record<string, boolean>): Promise<ClaudeTool[]> {
  const installedPath = path.join(PATHS.claude, 'plugins', 'installed_plugins.json')

  let registry: InstalledPluginsJson
  try {
    const raw = await fs.readFile(installedPath, 'utf-8')
    registry = JSON.parse(raw) as InstalledPluginsJson
  } catch {
    return []
  }

  const pluginEntries = Object.entries(registry.plugins)

  return Promise.all(
    pluginEntries.map(async ([key, installs]) => {
      const install = installs[0]
      const atIdx = key.indexOf('@')
      const pluginName = atIdx !== -1 ? key.slice(0, atIdx) : key
      const marketplace = atIdx !== -1 ? key.slice(atIdx + 1) : undefined

      // Read .claude-plugin/plugin.json for display metadata
      const manifestPath = path.join(install.installPath, '.claude-plugin', 'plugin.json')
      let manifest: { name?: string; description?: string; version?: string } = {}
      try {
        const raw = await fs.readFile(manifestPath, 'utf-8')
        manifest = JSON.parse(raw) as typeof manifest
      } catch {
        // manifest absent — use key fallback
      }

      // Detect MCP: presence of .mcp.json in the install path
      const isMcp = await fs
        .access(path.join(install.installPath, '.mcp.json'))
        .then(() => true)
        .catch(() => false)

      const tool: ClaudeTool = {
        id: key,
        name: manifest.name ?? pluginName,
        type: isMcp ? 'mcp' : 'plugin',
        description: manifest.description,
        version: manifest.version ?? install.version,
        enabled: enabledPlugins[key] ?? false,
        marketplace,
      }

      return tool
    })
  )
}

// ============================================================
// Public: scan all Claude capabilities from ~/.claude/
// Returns typed ClaudeToolsData with skills, mcpPlugins, skillPlugins
// ============================================================
export async function scanClaudeTools(): Promise<ClaudeToolsData> {
  const enabledPlugins = await readSettings()

  const [skills, allPlugins] = await Promise.all([
    scanSkills(),
    scanPlugins(enabledPlugins),
  ])

  return {
    skills,
    mcpPlugins: allPlugins.filter((p) => p.type === 'mcp'),
    skillPlugins: allPlugins.filter((p) => p.type === 'plugin'),
    scannedAt: new Date().toISOString(),
  }
}
