import type { ChannelFields } from './db/channels'

type Member = { sessionId: string; title: string }

/** The chat's lead Bot, while it is still a member. */
export function channelLead(channel: ChannelFields): string | undefined {
  const lead = channel.leadAgentSessionId

  return lead && channel.agentSessionIds?.includes(lead) ? lead : undefined
}

/** The member Bots a post names as `@Name`, other than its author. */
export function addressedAgents(members: Member[], text: string, authorSessionId?: string) {
  const lower = text.toLowerCase()

  return members
    .filter(
      (member) =>
        member.sessionId !== authorSessionId &&
        member.title.trim() !== '' &&
        lower.includes(`@${member.title.trim().toLowerCase()}`),
    )
    .map((member) => member.sessionId)
}

/**
 * Who a post wakes. Without a lead, every other agent. With one, the lead
 * routes: a person's or a member's post wakes the lead and the members it names;
 * the lead's own posts wake only the members it names.
 */
export function channelRecipients(
  channel: ChannelFields,
  authorSessionId: string | undefined,
  addressed: readonly string[],
): string[] {
  const members = channel.agentSessionIds ?? []
  const lead = channelLead(channel)

  if (!lead) return members.filter((id) => id !== authorSessionId)
  const named = new Set(addressed)

  if (authorSessionId !== lead) named.add(lead)
  named.delete(authorSessionId ?? '')

  return members.filter((id) => named.has(id))
}

const LEAD_NOTE =
  'You lead this chat. People’s posts wake only you (and any Bot they name), so take each request: answer small ones yourself, and split larger ones across the Bots in `members` by writing @Name in channel_post with what to do and what done looks like. Only the Bots you name wake. They report back here to you; follow up on a missing report, check the results, and give the people one combined answer. Ask the people only for judgment calls.'

const MEMBER_NOTE =
  'The Bot in `lead` leads this chat and hands out the work. You wake when it or a person names you with @Name. Do what is handed to you; when you finish or are blocked, post a short report that names the lead with @Name. Do not take up requests addressed to the lead or to another Bot.'

/** What channel_read tells a reader about the chat's lead: names are data, the note is the rule. */
export function leadFieldsFor(lead: Member, members: Member[], readerId: string) {
  const name = (member: Member) => ({ sessionId: member.sessionId, name: member.title })

  return {
    lead: name(lead),
    members: members.filter((member) => member.sessionId !== lead.sessionId).map(name),
    leadNote: readerId === lead.sessionId ? LEAD_NOTE : MEMBER_NOTE,
  }
}
