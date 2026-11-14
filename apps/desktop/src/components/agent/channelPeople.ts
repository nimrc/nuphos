import { api } from '../../api'
import { t } from '../../i18n'
import { announceChatArchived } from '../../lib/chatArchiveEvents'
import { ownAgents } from '../channels/channelShared'
import { toast } from '../ui/toast'

import { announceTimelineChange } from './panel/timelineEvents'

import type {
  AgentConversationParticipant,
  ChannelAgent,
  ConversationAccessState,
} from '../../api/agent-types'
import type { Pickable } from './PersonFace'

/**
 * A channel's agents as the Share card's people; the viewer may take out their
 * own, or any if they own the channel, and then also picks which one leads.
 */
export function agentPeople(
  viewerId: string,
  channel: { agents: ChannelAgent[]; ownerId: string; onAgentsChange: () => void } | undefined,
  sessionId: string,
  teamId: string,
): AgentConversationParticipant[] {
  const agents = channel?.agents ?? []
  const owns = channel?.ownerId === viewerId

  return agents.map((agent) => ({
    id: agent.sessionId,
    name: agent.title,
    email: '',
    isOwner: false,
    role: 'reply',
    agent: {
      avatar: agent.avatar,
      removable: agent.ownerId === viewerId || owns,
      lead: agent.lead === true,
      ...(owns && agents.length > 1
        ? {
            setLead: (lead: boolean) =>
              setLead(sessionId, teamId, lead ? agent.sessionId : null, channel),
          }
        : {}),
    },
  }))
}

function setLead(
  sessionId: string,
  teamId: string,
  agentId: string | null,
  channel: { onAgentsChange: () => void },
) {
  api
    .agentSetChannelLead(sessionId, teamId, agentId)
    .then(() => channel.onAgentsChange())
    .catch((err: unknown) => toast.apiError(t('Could not change the lead'), err))
}

/** The viewer's own agents that are not in the channel yet, as teammates to pick. */
export function addableAgents(
  teamId: string,
  viewerId: string,
  agents: ChannelAgent[],
): Pickable[] {
  const inChannel = new Set(agents.map((agent) => agent.sessionId))

  // A chat holds people and Bots; a Task speaks through the Bot above it.
  return ownAgents(teamId, viewerId)
    .filter((agent) => agent.avatar && !inChannel.has(agent.sessionId))
    .map((agent) => ({
      id: agent.sessionId,
      name: agent.title || t('Untitled agent'),
      email: '',
      agent: { avatar: agent.avatar, provider: agent.agentRuntime },
    }))
}

/** Takes people out of a session, a channel's agents by their own route; each person's answer is the new state. */
export async function removePeople(
  people: { id: string; agent?: unknown }[],
  at: {
    sessionId: string
    teamId: string
    apply: (state: ConversationAccessState) => void
    onAgentsChange?: () => void
  },
): Promise<void> {
  for (const { id, agent } of people) {
    if (agent) {
      await api.agentRemoveChannelAgent(at.sessionId, at.teamId, id)
      at.onAgentsChange?.()
    } else at.apply(await api.agentRemoveConversationParticipant(at.sessionId, at.teamId, id))
  }
  announceTimelineChange(at.sessionId)
}

/** The viewer takes themselves out; the session leaves their lists and tabs as an archived one does. */
export async function leaveSession(sessionId: string, teamId: string, viewerId: string) {
  await api.agentRemoveConversationParticipant(sessionId, teamId, viewerId)
  announceChatArchived({ sessionId, teamId })
}
