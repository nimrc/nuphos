import { afterEach, beforeEach, expect, test } from 'bun:test'
import { Hono } from 'hono'

import { config } from '@/config'
import { errorHandler } from '@/lib/errors'
import { useIdentity } from '@/lib/test/doubles/identity'

import { yuaiRoutes } from './yuai'

useIdentity({
  authenticateToken: async (token: string) =>
    ({
      user: {
        id: '64b5f1c2e4b0a1d2c3e4f5aa',
        email: token === 'known' ? 'Owner@Example.com' : 'stranger@example.com',
        name: 'Owner',
      },
    }) as never,
})

const app = new Hono().onError(errorHandler).route('/auth/yuai', yuaiRoutes)
const originalFetch = globalThis.fetch
const original = { ...config.yuai }

beforeEach(() => {
  Object.assign(config.yuai, { apiUrl: 'https://yuai.test', adminKey: 'admin' })
  globalThis.fetch = (async () =>
    Response.json({
      data: { items: [{ id: 1, email: 'owner@example.com', balance: 12.5 }] },
    })) as unknown as typeof fetch
})
afterEach(() => {
  globalThis.fetch = originalFetch
  Object.assign(config.yuai, original)
})

const get = (token: string) =>
  app.request('/auth/yuai/balance', { headers: { authorization: `Bearer ${token}` } })

test("returns the signed-in user's Yu AI balance", async () => {
  const response = await get('known')

  expect(response.status).toBe(200)
  expect(await response.json()).toEqual({ balance: 12.5 })
})

test('is null without a Yu AI account', async () => {
  expect(await (await get('other')).json()).toEqual({ balance: null })
})

test('requires sign-in', async () => {
  expect((await app.request('/auth/yuai/balance')).status).toBe(401)
})
