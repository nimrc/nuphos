import { beforeEach, describe, expect, test } from 'bun:test'

import { useConversationTurn } from '@/lib/test/doubles/conversation-turn'
import { useDb } from '@/lib/test/doubles/db'
import { useThreadBridge } from '@/lib/test/doubles/thread-bridge'
import { portabilityDb } from '@/lib/test/runtime-portability-db'

import { agentConversations } from './db'
import {
  MAX_NUDGES,
  agentHandoffs,
  handOff,
  listHandoffs,
  nudgeOverdueHandoffs,
  updateHandoff,
} from './handoffs'

import type { AgentConversation } from './db'
import type * as dbActual from '@/lib/db'

let memory = portabilityDb()

useDb({ db: (() => memory) as unknown as typeof dbActual.db })

// What reached each conversation, as `${target}: ${prompt}`.
let delivered: string[] = []
let failDelivery = false

useThreadBridge({
  authorizeThreadActor: async (actor) => ({ sessionId: actor.sessionId }) as AgentConversation,
  authorizeThreadDelivery: async (data) => {
    if (data.targetSessionId === 'stranger')
      throw new Error('Target must be another conversation you own in this team.')

    return { source: {} as AgentConversation, target: {} as AgentConversation }
  },
  startThreadTurn: async (data) => {
    if (failDelivery) throw new Error('runtime offline')
    delivered.push(`${data.targetSessionId}: ${data.prompt}`)

    return { status: 'started', run: Promise.resolve(undefined) }
  },
})
useConversationTurn({
  startConversationTurn: async (data, _target, text) => {
    delivered.push(`${data.targetSessionId}: ${text}`)

    return { status: 'started', run: Promise.resolve(undefined) }
  },
})

const lead = { userId: 'me', teamId: 'team', sessionId: 'lead', locale: 'en' }
const writer = { ...lead, sessionId: 'writer' }

beforeEach(async () => {
  memory = portabilityDb()
  delivered = []
  failDelivery = false
  const bots: [string, string][] = [
    ['lead', 'Lead'],
    ['writer', 'Writer'],
  ]

  for (const [sessionId, title] of bots)
    await agentConversations().insertOne({
      sessionId,
      title,
      userId: 'me',
      teamId: 'team',
      avatar: '07-ada',
      firstMessage: '',
      messageCount: 0,
      createdAt: new Date(),
      lastActiveAt: new Date(),
    })
})

describe('handoffs', () => {
  test('handing off records the work and sends it with how to report', async () => {
    const handoff = await handOff(lead, {
      toSessionId: 'writer',
      task: 'Draft the release notes',
      doneWhen: 'A PR with the notes',
      dueInMinutes: 30,
    })

    expect(handoff).toMatchObject({ status: 'open', fromSessionId: 'lead', delivery: 'started' })
    expect(delivered[0]).toContain(`writer: Handoff ${handoff.id}: Draft the release notes`)
    expect(delivered[0]).toContain('Done when: A PR with the notes')
    expect(delivered[0]).toContain('update_handoff')
    expect((await listHandoffs('writer', 'me')).map((row) => row.id)).toEqual([handoff.id])
  })

  test('a handoff that could not be delivered or targets a stranger waits on nothing', async () => {
    await expect(handOff(lead, { toSessionId: 'stranger', task: 'x' })).rejects.toThrow()
    failDelivery = true
    await expect(handOff(lead, { toSessionId: 'writer', task: 'x' })).rejects.toThrow('offline')
    expect(await listHandoffs('lead', 'me')).toEqual([])
  })

  test('the assignee reports, which wakes the lead; the lead accepts it', async () => {
    const { id } = await handOff(lead, { toSessionId: 'writer', task: 'Draft' })
    const reported = await updateHandoff(writer, {
      handoffId: id,
      status: 'done',
      report: 'PR #12',
    })

    expect(reported).toMatchObject({ status: 'done', report: 'PR #12', delivery: 'started' })
    expect(delivered[1]).toContain(`lead: Handoff ${id} is done: PR #12`)
    await updateHandoff(lead, { handoffId: id, status: 'done' })
    expect(delivered).toHaveLength(2)
    expect(await listHandoffs('lead', 'me')).toEqual([])
    expect(await listHandoffs('lead', 'me', true)).toHaveLength(1)
  })

  test('each side may only do its part, and nobody else may touch it', async () => {
    const { id } = await handOff(lead, { toSessionId: 'writer', task: 'Draft' })

    await expect(updateHandoff(writer, { handoffId: id, status: 'cancelled' })).rejects.toThrow()
    await expect(updateHandoff(writer, { handoffId: id, dueInMinutes: 90 })).rejects.toThrow()
    await expect(
      updateHandoff({ ...lead, sessionId: 'other' }, { handoffId: id, status: 'done' }),
    ).rejects.toThrow('No such handoff')
    await expect(
      updateHandoff({ ...lead, userId: 'someone' }, { handoffId: id, status: 'done' }),
    ).rejects.toThrow('No such handoff')
  })

  test('overdue work reminds the lead once per due time, at most a few times', async () => {
    const { id } = await handOff(lead, { toSessionId: 'writer', task: 'Draft', dueInMinutes: 10 })
    const later = (minutes: number) => new Date(Date.now() + minutes * 60_000)

    expect(await nudgeOverdueHandoffs(later(5))).toBe(0)
    expect(await nudgeOverdueHandoffs(later(11))).toBe(1)
    expect(delivered.at(-1)).toContain(
      `lead: Handoff ${id} to Writer (session writer) has no report yet`,
    )
    // Already reminded for this due time; the next comes as long again later.
    expect(await nudgeOverdueHandoffs(later(12))).toBe(0)
    expect(await nudgeOverdueHandoffs(later(30))).toBe(1)
    expect(await nudgeOverdueHandoffs(later(60))).toBe(1)
    expect(delivered.at(-1)).toContain('This is the last reminder.')
    expect(await nudgeOverdueHandoffs(later(600))).toBe(0)
    expect((await agentHandoffs().findOne({ id }))?.nudges).toBe(MAX_NUDGES)
  })

  test('a report or a new due time stops the reminders', async () => {
    const { id } = await handOff(lead, { toSessionId: 'writer', task: 'Draft', dueInMinutes: 10 })

    await updateHandoff(writer, { handoffId: id, status: 'done', report: 'ok' })
    expect(await nudgeOverdueHandoffs(new Date(Date.now() + 60 * 60_000))).toBe(0)
  })
})
