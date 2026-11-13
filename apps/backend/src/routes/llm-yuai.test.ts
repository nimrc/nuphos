import { afterEach, beforeEach, expect, test } from 'bun:test'
import { Hono } from 'hono'
import { ObjectId } from 'mongodb'

import { config } from '@/config'
import { mintPreviewMcpToken } from '@/lib/claude-code-preview/mcp-token'
import { errorHandler } from '@/lib/errors'
import { useDb } from '@/lib/test/doubles/db'
import { useTokenRevocation } from '@/lib/test/doubles/token-revocation'
import { clearYuaiKeyCache } from '@/lib/yuai/user-key'

import { llmYuaiRoutes } from './llm-yuai'

useTokenRevocation({ isTokenRevoked: async () => false, inheritRevocation: async () => false })

const OWNER = new ObjectId()
const GUEST = new ObjectId()
const people = new Map([
  [OWNER.toHexString(), { _id: OWNER, email: 'owner@example.com' }],
  [GUEST.toHexString(), { _id: GUEST, email: 'Guest@Example.com' }],
])

useDb({
  db: () => ({
    collection: () => ({
      findOne: async (filter: { _id: ObjectId }) => people.get(filter._id.toHexString()) ?? null,
    }),
  }),
} as never)

const app = new Hono().onError(errorHandler).route('/llm/yuai', llmYuaiRoutes)
const originalFetch = globalThis.fetch
const original = { ...config.yuai }
let upstream: { url: string; auth: string | null; body: string }[] = []

beforeEach(() => {
  upstream = []
  clearYuaiKeyCache()
  Object.assign(config.yuai, { apiUrl: 'https://yuai.test', adminKey: 'admin', keyName: 'nuphos' })
  globalThis.fetch = (async (input: unknown, init?: RequestInit) => {
    const url = String(input)

    if (url.includes('/api/v1/admin/users?'))
      return Response.json({
        data: {
          items: [
            { id: 1, email: 'owner@example.com' },
            { id: 2, email: 'guest@example.com' },
          ],
        },
      })
    if (url.includes('/users/1/api-keys'))
      return Response.json({
        data: {
          items: [
            { key: 'sk-owner-old', name: 'old', status: 'active', created_at: '2026-01-01' },
            { key: 'sk-owner-nuphos', name: 'Nuphos', status: 'active', created_at: '2025-01-01' },
            { key: 'sk-owner-off', name: 'nuphos', status: 'disabled', created_at: '2026-06-01' },
          ],
        },
      })
    if (url.includes('/users/2/api-keys')) return Response.json({ data: { items: [] } })
    const headers = new Headers(init?.headers)

    upstream.push({
      url,
      auth: headers.get('authorization'),
      body: await new Response(init?.body).text(),
    })

    return new Response('data: {"ok":true}\n\n', {
      headers: { 'content-type': 'text/event-stream' },
    })
  }) as typeof fetch
})
afterEach(() => {
  globalThis.fetch = originalFetch
  Object.assign(config.yuai, original)
})

const token = (userId: ObjectId, humanTurn = false) =>
  mintPreviewMcpToken({
    userId: userId.toHexString(),
    conversationOwnerUserId: OWNER.toHexString(),
    sessionId: 'session',
    teamId: 'team',
    humanTurn,
  })

const call = async (bearer?: string) =>
  app.request('/llm/yuai/v1/chat/completions?x=1', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
    },
    body: '{"model":"deepseek-v4.1-flash"}',
  })

test("forwards a turn with the paying user's own key and streams the answer", async () => {
  const response = await call(await token(OWNER))

  expect(response.status).toBe(200)
  expect(await response.text()).toContain('"ok":true')
  expect(upstream).toEqual([
    {
      url: 'https://yuai.test/v1/chat/completions?x=1',
      auth: 'Bearer sk-owner-nuphos',
      body: '{"model":"deepseek-v4.1-flash"}',
    },
  ])
})

test("a guest's own turn bills the guest; an automated turn bills the owner", async () => {
  expect((await call(await token(GUEST, true))).status).toBe(403)
  expect((await call(await token(GUEST, false))).status).toBe(200)
  expect(upstream[0]?.auth).toBe('Bearer sk-owner-nuphos')
})

test('refuses calls without a session token', async () => {
  expect((await call()).status).toBe(401)
  expect((await call('not-a-token')).status).toBe(401)
  expect(upstream).toEqual([])
})

test('says which account has no key', async () => {
  const response = await call(await token(GUEST, true))

  expect(response.status).toBe(403)
  expect(await response.text()).toContain('Guest@Example.com has no active Yu AI API key')
})
