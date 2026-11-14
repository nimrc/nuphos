import { Hono } from 'hono'

import { getConversationBySessionId } from '@/lib/agent/db'
import { setChannelLead } from '@/lib/agent/db/channel-lead'
import { AppError } from '@/lib/errors'

import { agentsResponse, channelOrNotFound, readBody, requireTeam } from './channel-route-helpers'

import type { AuthVariables } from '@/middleware/auth'

export const channelLeadRoutes = new Hono<{ Variables: AuthVariables }>()

// The channel's owner picks which of its Bots leads: people's posts then wake
// the lead, which hands work to the others by name. null ends it.
channelLeadRoutes.put('/conversations/:sessionId/lead', async (c) => {
  const userId = c.get('userId')
  const body = await readBody(c)
  const teamId = await requireTeam(c, body)
  const channelId = c.req.param('sessionId')
  const found = await getConversationBySessionId(channelId)
  const channel = channelOrNotFound(found?.teamId === teamId ? found : null)
  const lead = body.agentSessionId

  if (channel.userId !== userId)
    throw new AppError(403, 'forbidden', 'Only the chat’s owner can choose its lead')
  if (lead !== null && (typeof lead !== 'string' || !lead))
    throw new AppError(400, 'invalid_request', 'agentSessionId must name a Bot here, or be null')
  if (lead !== null && !channel.agentSessionIds?.includes(lead))
    throw new AppError(404, 'not_found', 'This Bot is not in the chat')

  return c.json(await agentsResponse(await setChannelLead(channelId, lead)))
})
