import assert from 'node:assert/strict'
import { test } from 'node:test'

import { favoriteMatchIn } from './favorite-match.ts'

import type { Item } from './types'

const chat = (sessionId: string, botChannelOf?: string): Item => ({
  key: `agent-session:${sessionId}`,
  label: 'Writer',
  href: `/teams/t/agent/${sessionId}`,
  enabled: true,
  ...(botChannelOf ? { channel: true, botChannelOf } : {}),
})

test("a Bot's chat matches the pin made on the Bot before the chat existed", () => {
  const pin = { label: 'Writer', href: '/teams/t/agent/bot' }

  assert.equal(favoriteMatchIn([pin], chat('chat', 'bot')), pin)
  assert.equal(favoriteMatchIn([pin], chat('other', 'someone')), undefined)
})

test('a row matches its own pin by href or key', () => {
  const byHref = { label: 'Writer', href: '/teams/t/agent/chat' }
  const byKey = { label: 'Writer', key: 'agent-session:chat' }

  assert.equal(favoriteMatchIn([byHref], chat('chat')), byHref)
  assert.equal(favoriteMatchIn([byKey], chat('chat')), byKey)
})
