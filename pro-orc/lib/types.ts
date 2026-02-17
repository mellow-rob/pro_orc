// lib/types.ts

// ============================================================
// GSD Status — derived from STATE.md, not a fixed enum.
// Known values listed; type is open (string & {}) keeps autocomplete.
// ============================================================
export type GsdStatus =
  | 'research'
  | 'planning'
  | 'building'
  | 'paused'
  | 'done'
  | 'archived'
  | (string & {})

// ============================================================
// Shared Base — fields present on ALL project types
// ============================================================
export interface BaseProject {
  id: string              // slugified directory name: "landlord-checker"
  name: string            // display name: "Landlord Checker"
  path: string            // absolute filesystem path (from os.homedir())
  type: 'code' | 'research'  // discriminant — determines card layout

  // GSD planning data — optional (project may have no .planning/)
  gsdStatus?: GsdStatus
  currentPhase?: string         // e.g. "Phase 3: API Layer"
  nextStep?: string             // next action from STATE.md or ROADMAP.md
  phaseProgress?: number        // 0-100: completed checkboxes / total checkboxes
  notionUrl?: string            // from <!-- notion: URL --> in PROJECT.md
}

// ============================================================
// Code Project — extends Base with git data (flat, per decisions)
// ============================================================
export interface CodeProject extends BaseProject {
  type: 'code'

  // Git data — flat on the interface per user decision
  // All optional: project may not be a git repo
  lastCommitMessage?: string
  lastCommitTimestamp?: string  // ISO 8601: "2026-02-17T14:23:00Z"
  lastCommitSha?: string        // short SHA: "a3f8b12"
  branch?: string               // current branch: "main"
  isDirty?: boolean             // uncommitted changes exist
}

// ============================================================
// Research Project — no git fields, different metadata
// ============================================================
export interface ResearchProject extends BaseProject {
  type: 'research'
  // Research projects: no git fields.
  // GSD fields (from BaseProject) are present if .planning/ exists.
}

// ============================================================
// Discriminated Union — use this type for all project lists
// ============================================================
export type Project = CodeProject | ResearchProject

// ============================================================
// Type Guards — for narrowing in components and API handlers
// ============================================================
export function isCodeProject(p: Project): p is CodeProject {
  return p.type === 'code'
}

export function isResearchProject(p: Project): p is ResearchProject {
  return p.type === 'research'
}

// ============================================================
// API Response shape — what /api/projects returns
// ============================================================
export interface ProjectsResponse {
  projects: Project[]
  scannedAt: string  // ISO 8601 timestamp
  totalCount: number
  codeCount: number
  researchCount: number
}

// ============================================================
// SSE Event shape — signal-only pattern (browser re-fetches)
// ============================================================
export type SseEventType =
  | 'project:updated'
  | 'project:added'
  | 'project:removed'
  | 'ping'

export interface SseEvent {
  type: SseEventType
  projectId?: string      // undefined for ping events
  changedFile?: string    // relative path of changed file, for debugging
}
