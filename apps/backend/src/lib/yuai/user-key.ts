import { config } from '@/config'
import { AppError } from '@/lib/errors'

type Sub2apiKey = { key: string; name: string; status: string; created_at: string }
type Page<T> = { items: T[] }

const HIT_TTL_MS = 5 * 60_000
const MISS_TTL_MS = 30_000
const cache = new Map<string, { until: number; key: string | null }>()

async function admin<T>(path: string): Promise<T> {
  const { apiUrl, adminKey } = config.yuai

  if (!adminKey) throw new AppError(503, 'yuai_unconfigured', 'Yu AI is not configured')
  const response = await fetch(`${apiUrl}/api/v1/admin${path}`, {
    headers: { 'x-api-key': adminKey, 'user-agent': 'nuphos' },
    signal: AbortSignal.timeout(10_000),
  })

  if (!response.ok)
    throw new AppError(502, 'yuai_lookup_failed', `Yu AI key lookup failed (${response.status})`)
  const body = (await response.json()) as { data?: T } & T

  return body.data ?? body
}

/** The user's active Yu AI key: one named like `config.yuai.keyName`, else the newest. */
async function lookupKey(email: string): Promise<string | null> {
  const users = await admin<Page<{ id: number; email: string }>>(
    `/users?${new URLSearchParams({ search: email, page_size: '20' }).toString()}`,
  )
  const user = users.items.find((u) => u.email.toLowerCase() === email)

  if (!user) return null
  const keys = await admin<Page<Sub2apiKey>>(`/users/${String(user.id)}/api-keys?page_size=100`)
  const active = keys.items.filter((k) => k.status === 'active')
  const named = active.filter((k) => k.name.toLowerCase() === config.yuai.keyName.toLowerCase())
  const pick = (named.length ? named : active).sort((a, b) =>
    b.created_at.localeCompare(a.created_at),
  )[0]

  return pick?.key ?? null
}

export async function yuaiKeyFor(rawEmail: string): Promise<string | null> {
  const email = rawEmail.trim().toLowerCase()
  const hit = cache.get(email)

  if (hit && hit.until > Date.now()) return hit.key
  const key = await lookupKey(email)

  cache.set(email, { until: Date.now() + (key ? HIT_TTL_MS : MISS_TTL_MS), key })

  return key
}

export function clearYuaiKeyCache() {
  cache.clear()
}
