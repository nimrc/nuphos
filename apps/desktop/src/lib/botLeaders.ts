import { useSyncExternalStore } from 'react'

// Which Bots lead their owner's other Bots, learned from every conversation the
// client fetches, so the sidebar row and the titlebar menu agree at once.
let leaders = new Map<string, boolean>()
const listeners = new Set<() => void>()

function publish(next: Map<string, boolean>) {
  leaders = next
  for (const listener of listeners) listener()
}

/** Only a Bot (with a face) is told about; a Task never leads. */
export function receiveBotLeaders(
  conversations: { sessionId: string; avatar?: string; leader?: boolean }[],
) {
  let next: Map<string, boolean> | null = null

  for (const { sessionId, avatar, leader = false } of conversations) {
    if (!avatar || leaders.get(sessionId) === leader) continue
    next ??= new Map(leaders)
    next.set(sessionId, leader)
  }
  if (next) publish(next)
}

/**
 * Shows the choice at once, and puts it back if `save` fails. One Bot leads
 * at a time, so picking one sets the others the client knows apart.
 */
export async function pickBotLeader(
  sessionId: string,
  leader: boolean,
  save: () => Promise<unknown>,
) {
  const previous = leaders
  const next = new Map(leaders)

  if (leader) for (const id of next.keys()) next.set(id, false)
  next.set(sessionId, leader)
  publish(next)
  try {
    await save()
  } catch (err) {
    publish(previous)
    throw err
  }
}

function subscribe(listener: () => void) {
  listeners.add(listener)

  return () => listeners.delete(listener)
}

export function isBotLeader(sessionId: string): boolean {
  return leaders.get(sessionId) === true
}

export function useIsBotLeader(sessionId: string): boolean {
  return useSyncExternalStore(subscribe, () => isBotLeader(sessionId))
}
