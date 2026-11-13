import { Hono } from 'hono'
import { ObjectId } from 'mongodb'

import { config } from '@/config'
import { AppError } from '@/lib/errors'
import { verifyPreviewMcpToken } from '@/lib/claude-code-preview/mcp-token'
import { users } from '@/lib/identity/shared'
import { isTokenRevoked } from '@/lib/internal-token/revocation'
import { yuaiKeyFor } from '@/lib/yuai/user-key'

import type { Context } from 'hono'

// Request headers a model call needs; everything else (cookies, the runtime's bearer) stays here.
const FORWARD_REQUEST = ['content-type', 'accept', 'anthropic-version', 'anthropic-beta']
const DROP_RESPONSE = new Set([
  'content-encoding',
  'content-length',
  'transfer-encoding',
  'connection',
])

/** The Nuphos user a runtime turn bills: the one who sent it, or the owner for automated turns. */
async function payingEmail(c: Context): Promise<string> {
  const header = c.req.header('authorization') ?? ''
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : ''
  const claims = token ? verifyPreviewMcpToken(token) : null

  // TODO(yuai): the token is minted per turn with a 24h expiry, but OpenCode reads it once at
  // start. A single OpenCode process alive past 24h would get 401 here; see docs/yuai.md.
  // Exchanged tokens (`lim`) only vend one connector's credential, never model calls.
  if (!claims || claims.lim)
    throw new AppError(401, 'unauthorized', 'A Nuphos runtime session token is required')
  if (await isTokenRevoked(claims))
    throw new AppError(401, 'token_revoked', 'This conversation token has been revoked')
  const userId = claims.hum ? claims.sub : claims.own

  if (!ObjectId.isValid(userId)) throw new AppError(401, 'unauthorized', 'Unknown user')
  const user = await users().findOne({ _id: new ObjectId(userId), deletedAt: { $exists: false } })

  if (!user) throw new AppError(401, 'unauthorized', 'Unknown user')

  return user.email
}

async function forward(c: Context) {
  const email = await payingEmail(c)
  const key = await yuaiKeyFor(email)

  if (!key)
    throw new AppError(
      403,
      'yuai_key_missing',
      `${email} has no active Yu AI API key. Create one at ${config.yuai.apiUrl}/keys and try again.`,
    )
  const url = new URL(c.req.url)
  const upstream = `${config.yuai.apiUrl}${url.pathname.replace(/^\/llm\/yuai/, '')}${url.search}`
  const headers = new Headers({
    authorization: `Bearer ${key}`,
    'x-api-key': key,
    'user-agent': 'nuphos',
  })

  for (const name of FORWARD_REQUEST) {
    const value = c.req.header(name)

    if (value) headers.set(name, value)
  }
  const response = await fetch(upstream, {
    method: c.req.method,
    headers,
    body: c.req.method === 'GET' ? undefined : c.req.raw.body,
    signal: c.req.raw.signal,
    // Streams the request body through (half-duplex), as Bun and undici require.
    duplex: 'half',
  })
  const out = new Headers()

  response.headers.forEach((value, name) => {
    if (!DROP_RESPONSE.has(name)) out.set(name, value)
  })

  return new Response(response.body, { status: response.status, headers: out })
}

/** OpenAI/Anthropic-compatible Yu AI for OpenCode runtimes, paid with each user's own key. */
export const llmYuaiRoutes = new Hono()

llmYuaiRoutes.get('/v1/*', forward)
llmYuaiRoutes.post('/v1/*', forward)
