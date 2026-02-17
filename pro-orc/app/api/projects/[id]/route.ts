// app/api/projects/[id]/route.ts
// Per-project data endpoint — returns fresh JSON for a single project.
// Used by the browser after receiving an SSE event to re-fetch stale data.

import { type NextRequest } from 'next/server'
import { scanProjectById } from '@/lib/scanner'

export const dynamic = 'force-dynamic'

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
): Promise<Response> {
  const { id } = await params
  const project = await scanProjectById(id)

  if (!project) {
    return Response.json({ error: 'not found' }, { status: 404 })
  }

  return Response.json(project)
}
