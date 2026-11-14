import { randomUUID } from 'node:crypto'

import { db } from '@/lib/db'
import { logError, logEvent } from '@/lib/observability'

import { getConversationBySessionId } from './db'
import { systemSender } from './message-metadata'
import { authorizeThreadActor, authorizeThreadDelivery, startThreadTurn } from './thread-bridge'

import type { ThreadActor } from './thread-bridge'
import type { Collection } from 'mongodb'

export type HandoffStatus = 'open' | 'blocked' | 'done' | 'cancelled'

/** Work one of the owner's Bots handed another, tracked until it is reported done. */
export type Handoff = {
  id: string
  teamId: string
  /** Owns both ends: a handoff never crosses owners. */
  userId: string
  fromSessionId: string
  toSessionId: string
  task: string
  doneWhen?: string
  status: HandoffStatus
  /** The assignee's latest report. */
  report?: string
  dueAt: Date
  /** How long to wait for a report, again after each reminder. */
  remindEveryMs: number
  createdAt: Date
  updatedAt: Date
  /** Overdue reminders sent to the delegator; they stop at MAX_NUDGES. */
  nudges: number
}

export const MAX_NUDGES = 3
const DEFAULT_DUE_MINUTES = 60
const ACTIVE: HandoffStatus[] = ['open', 'blocked']

export const agentHandoffs = (): Collection<Handoff> => db().collection<Handoff>('agent_handoffs')

export async function setupHandoffIndexes(): Promise<void> {
  await agentHandoffs().createIndex({ id: 1 }, { unique: true, background: true })
  await agentHandoffs().createIndex({ status: 1, dueAt: 1 }, { background: true })
  await agentHandoffs().createIndex({ fromSessionId: 1, status: 1 }, { background: true })
  await agentHandoffs().createIndex({ toSessionId: 1, status: 1 }, { background: true })
}

function view(handoff: Handoff) {
  const { id, fromSessionId, toSessionId, task, doneWhen, status, report, dueAt, nudges } = handoff

  return { id, fromSessionId, toSessionId, task, doneWhen, status, report, dueAt, nudges }
}

/** Records the work, then sends it to the assignee as its own turn. */
export async function handOff(
  actor: ThreadActor,
  input: { toSessionId: string; task: string; doneWhen?: string; dueInMinutes?: number },
) {
  await authorizeThreadDelivery({ ...actor, targetSessionId: input.toSessionId })
  const now = new Date()
  const handoff: Handoff = {
    id: randomUUID(),
    teamId: actor.teamId,
    userId: actor.userId,
    fromSessionId: actor.sessionId,
    toSessionId: input.toSessionId,
    task: input.task,
    ...(input.doneWhen ? { doneWhen: input.doneWhen } : {}),
    status: 'open',
    dueAt: new Date(now.getTime() + (input.dueInMinutes ?? DEFAULT_DUE_MINUTES) * 60_000),
    remindEveryMs: (input.dueInMinutes ?? DEFAULT_DUE_MINUTES) * 60_000,
    createdAt: now,
    updatedAt: now,
    nudges: 0,
  }

  await agentHandoffs().insertOne(handoff)
  const prompt = [
    `Handoff ${handoff.id}: ${input.task}`,
    input.doneWhen ? `Done when: ${input.doneWhen}` : null,
    `Due by ${handoff.dueAt.toISOString()}. When it is done or you are blocked, call update_handoff with handoffId ${handoff.id}, status "done" or "blocked" and a short report; that reaches the Bot that handed it to you.`,
  ]
    .filter(Boolean)
    .join('\n')

  try {
    const { status } = await startThreadTurn({
      ...actor,
      targetSessionId: input.toSessionId,
      messageId: randomUUID(),
      prompt,
    })

    return { ...view(handoff), delivery: status }
  } catch (error) {
    // Never delivered, so nothing waits on it.
    await agentHandoffs().updateOne({ id: handoff.id }, { $set: { status: 'cancelled' } })
    throw error
  }
}

/**
 * The assignee reports done or blocked, which wakes the delegator with the
 * report; the delegator closes, cancels, reopens or moves the due time.
 */
export async function updateHandoff(
  actor: ThreadActor,
  input: { handoffId: string; status?: HandoffStatus; report?: string; dueInMinutes?: number },
) {
  await authorizeThreadActor(actor)
  const handoff = await agentHandoffs().findOne({ id: input.handoffId, userId: actor.userId })

  if (!handoff || ![handoff.fromSessionId, handoff.toSessionId].includes(actor.sessionId))
    throw new Error('No such handoff for this conversation.')
  const assignee = actor.sessionId === handoff.toSessionId

  if (assignee && input.status && !['done', 'blocked'].includes(input.status))
    throw new Error('The assignee reports "done" or "blocked".')
  if (assignee && input.dueInMinutes !== undefined)
    throw new Error('Only the Bot that handed it out moves the due time.')
  const now = new Date()
  const update: Partial<Handoff> = {
    updatedAt: now,
    ...(input.status ? { status: input.status } : {}),
    ...(input.report ? { report: input.report } : {}),
    // A new due time starts the reminders over.
    ...(input.dueInMinutes === undefined
      ? {}
      : {
          dueAt: new Date(now.getTime() + input.dueInMinutes * 60_000),
          remindEveryMs: input.dueInMinutes * 60_000,
          nudges: 0,
        }),
  }

  await agentHandoffs().updateOne({ id: handoff.id }, { $set: update })
  const next = { ...handoff, ...update }

  if (assignee) {
    const prompt = `Handoff ${handoff.id} is ${next.status}: ${input.report ?? '(no report)'}\nTask was: ${handoff.task}\nCheck the result, then close it with update_handoff (status "done"), or hand back what is missing with send_message_to_thread.`
    const { status } = await startThreadTurn({
      ...actor,
      targetSessionId: handoff.fromSessionId,
      messageId: randomUUID(),
      prompt,
    })

    return { ...view(next), delivery: status }
  }

  return view(next)
}

/** The handoffs this conversation gave out or was given that are not finished. */
export async function listHandoffs(sessionId: string, userId: string, all = false) {
  const rows = await agentHandoffs()
    .find({
      userId,
      $or: [{ fromSessionId: sessionId }, { toSessionId: sessionId }],
      ...(all ? {} : { status: { $in: ACTIVE } }),
    })
    .sort({ createdAt: -1 })
    .limit(50)
    .toArray()

  return rows.map(view)
}

/**
 * Reminds each delegator of overdue work, once per due time: the claim moves
 * the due time on, so concurrent sweeps on several replicas send it once.
 */
export async function nudgeOverdueHandoffs(now = new Date()): Promise<number> {
  const overdue = await agentHandoffs()
    .find({ status: { $in: ACTIVE }, dueAt: { $lte: now }, nudges: { $lt: MAX_NUDGES } })
    .limit(100)
    .toArray()
  let sent = 0

  for (const handoff of overdue) {
    const claimed = await agentHandoffs().findOneAndUpdate(
      { id: handoff.id, nudges: handoff.nudges, dueAt: handoff.dueAt },
      {
        $inc: { nudges: 1 },
        // Wait as long again before the next reminder.
        $set: { dueAt: new Date(now.getTime() + handoff.remindEveryMs) },
      },
      { returnDocument: 'after' },
    )

    if (!claimed) continue
    try {
      await remind(claimed)
      sent++
    } catch (error) {
      logError('agent.handoff.nudge_failed', error, { handoff_id: handoff.id })
    }
  }

  return sent
}

async function remind(handoff: Handoff) {
  const [delegator, assignee] = await Promise.all([
    getConversationBySessionId(handoff.fromSessionId),
    getConversationBySessionId(handoff.toSessionId),
  ])

  if (!delegator || delegator.archivedAt) return
  const name = assignee?.title || 'the assignee'
  const last = handoff.nudges >= MAX_NUDGES ? ' This is the last reminder.' : ''
  const text = `Handoff ${handoff.id} to ${name} (session ${handoff.toSessionId}) has no report yet (${handoff.status}). Task: ${handoff.task}\nCheck on it with send_message_to_thread, do it yourself, move the due time or cancel it with update_handoff, or tell your owner if it needs them.${last}`
  const { startConversationTurn } = await import('./conversation-turn')
  const { run } = await startConversationTurn(
    {
      userId: handoff.userId,
      teamId: handoff.teamId,
      targetSessionId: handoff.fromSessionId,
      messageId: randomUUID(),
      locale: delegator.metadata?.locale ?? 'en-US',
    },
    delegator,
    text,
    'agent.resource',
    systemSender('nuphos', 'Nuphos', `/teams/${handoff.teamId}/agent/${handoff.toSessionId}`),
  )

  run.catch((error: unknown) => {
    logError('agent.handoff.nudge_turn_failed', error, { handoff_id: handoff.id })
  })
}

const SWEEP_INTERVAL_MS = 5 * 60 * 1000
let sweepTimer: ReturnType<typeof setInterval> | undefined
let sweeping = false

function runSweep() {
  if (sweeping) return
  sweeping = true
  void nudgeOverdueHandoffs()
    .then((sent) => {
      if (sent > 0) logEvent('info', 'agent.handoff.nudged', { sent })
    })
    .catch((error: unknown) => {
      logError('agent.handoff.sweep_failed', error)
    })
    .finally(() => {
      sweeping = false
    })
}

/** Every replica sweeps; the claim in nudgeOverdueHandoffs keeps each reminder single. */
export const handoffReminders = {
  init(): void {
    sweepTimer = setInterval(runSweep, SWEEP_INTERVAL_MS)
    void setupHandoffIndexes().catch((error: unknown) => {
      logError('agent.handoff.indexes_failed', error)
    })
  },
  shutdown(): void {
    if (sweepTimer) clearInterval(sweepTimer)
    sweepTimer = undefined
  },
}
