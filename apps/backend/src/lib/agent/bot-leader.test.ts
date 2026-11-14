import { beforeEach, describe, expect, test } from 'bun:test'

import { useDb } from '@/lib/test/doubles/db'
import { portabilityDb } from '@/lib/test/runtime-portability-db'

import { botLeaderSection } from './bot-leader'
import { agentConversations, setBotLeader, setConversationAvatar } from './db'

import type { AgentConversation } from './db'
import type * as dbActual from '@/lib/db'

let memory = portabilityDb()

useDb({ db: (() => memory) as unknown as typeof dbActual.db })

async function bot(sessionId: string, title: string, extra: Partial<AgentConversation> = {}) {
  await agentConversations().insertOne({
    sessionId,
    userId: 'me',
    teamId: 'team',
    title,
    avatar: '07-ada',
    firstMessage: '',
    messageCount: 0,
    createdAt: new Date(),
    lastActiveAt: new Date(),
    ...extra,
  })
}

const leaders = async () =>
  (await agentConversations().find({ leader: true }).toArray()).map((row) => row.sessionId)

describe('Bot leader', () => {
  beforeEach(async () => {
    memory = portabilityDb()
    await bot('lead', 'Lead')
    await bot('writer', 'Writer', { instructions: 'Drafts the release notes.' })
    await bot('reviewer', 'Reviewer')
  })

  test('one Leader per owner and team: picking another takes it over', async () => {
    expect(await setBotLeader('lead', 'me', 'team', true)).toBe(true)
    expect(await setBotLeader('writer', 'me', 'team', true)).toBe(true)
    expect(await leaders()).toEqual(['writer'])
    expect(await setBotLeader('writer', 'me', 'team', false)).toBe(true)
    expect(await leaders()).toEqual([])
  })

  test("only the owner's Bot in that team can lead", async () => {
    await agentConversations().insertOne({
      sessionId: 'task',
      userId: 'me',
      teamId: 'team',
      title: 'A Task',
    } as AgentConversation)
    expect(await setBotLeader('lead', 'someone-else', 'team', true)).toBe(false)
    expect(await setBotLeader('lead', 'me', 'other-team', true)).toBe(false)
    expect(await setBotLeader('task', 'me', 'team', true)).toBe(false)
    expect(await leaders()).toEqual([])
  })

  test('a Bot made a Task stops leading', async () => {
    await setBotLeader('lead', 'me', 'team', true)
    await setConversationAvatar('lead', null)
    expect(await leaders()).toEqual([])
  })

  test('the Leader is told its Bots and how to hand work out', async () => {
    await bot('gone', 'Archived', { archivedAt: new Date() })
    await bot('theirs', 'Not mine', { userId: 'someone-else' })
    await setBotLeader('lead', 'me', 'team', true)
    const section = (await botLeaderSection('lead')) ?? ''

    expect(section).toContain("## You lead your owner's Bots")
    expect(section).toContain('Writer (session writer): Drafts the release notes.')
    expect(section).toContain('Reviewer (session reviewer)')
    expect(section).toContain('hand_off')
    expect(section).not.toContain('Archived')
    expect(section).not.toContain('Not mine')
    expect(section).not.toContain('(session lead)')
  })

  test('every other Bot is told where to report; none without a Leader', async () => {
    expect(await botLeaderSection('writer')).toBeNull()
    await setBotLeader('lead', 'me', 'team', true)
    const section = (await botLeaderSection('writer')) ?? ''

    expect(section).toContain('## Your Leader')
    expect(section).toContain('threadId lead')
  })
})
