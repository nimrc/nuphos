import { channelLead } from '@/lib/agent/channel-lead'
import { isChannel, listChannelAgents } from '@/lib/agent/db/channels'
import { AppError } from '@/lib/errors'

import { readTeamIdCandidate, resolveVerifiedTeamId } from './team-scope'

import type { AgentConversation } from '@/lib/agent/db'
import type { AuthVariables } from '@/middleware/auth'
import type { Context } from 'hono'

export type Body = Record<string, unknown>

export async function readBody(c: Context): Promise<Body> {
  return (await c.req.json().catch(() => ({}))) as Body
}

export async function requireTeam(c: Context<{ Variables: AuthVariables }>, body: Body = {}) {
  const teamId = await resolveVerifiedTeamId(c, readTeamIdCandidate(c, body.teamId))

  if (!teamId) throw new AppError(403, 'forbidden', 'Workspace membership is required')

  return teamId
}

export function channelOrNotFound(conversation: AgentConversation | null): AgentConversation {
  if (!conversation || !isChannel(conversation))
    throw new AppError(404, 'not_found', 'Channel not found')

  return conversation
}

/** A chat's Bots, and which of them leads it. */
export async function agentsResponse(channel: AgentConversation | null) {
  const found = channelOrNotFound(channel)
  const lead = channelLead(found)

  return {
    agents: await listChannelAgents(found),
    ...(lead ? { leadAgentSessionId: lead } : {}),
  }
}
