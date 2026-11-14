import { addressedAgents, channelLead, leadFieldsFor } from '../channel-lead'

import { listChannelAgents } from './channels'
import { agentConversations } from './shared'

import type { AgentConversation } from './shared'

type LedChannel = Pick<AgentConversation, 'agentSessionIds' | 'leadAgentSessionId' | 'teamId'>

/** The chat's lead, one of its Bots, or none. */
export async function setChannelLead(channelId: string, agentSessionId: string | null) {
  return await agentConversations().findOneAndUpdate(
    agentSessionId === null
      ? { sessionId: channelId, kind: 'channel' }
      : { sessionId: channelId, kind: 'channel', agentSessionIds: agentSessionId },
    agentSessionId === null
      ? { $unset: { leadAgentSessionId: '' } }
      : { $set: { leadAgentSessionId: agentSessionId } },
    { returnDocument: 'after' },
  )
}

/** The member Bots a post names; only a led chat routes by name, so only it looks. */
export async function addressedIn(channel: LedChannel, text: string, authorSessionId?: string) {
  return channelLead(channel)
    ? addressedAgents(await listChannelAgents(channel), text, authorSessionId)
    : []
}

/** The lead, and what it means for this reader, as channel_read shows them. */
export async function leadFields(channel: LedChannel, readerId: string) {
  const leadId = channelLead(channel)

  if (!leadId) return {}
  const members = await listChannelAgents(channel)
  const lead = members.find((member) => member.sessionId === leadId)

  return lead ? { leadAgentSessionId: leadId, ...leadFieldsFor(lead, members, readerId) } : {}
}
