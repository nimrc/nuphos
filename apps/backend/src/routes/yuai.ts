import { Hono } from 'hono'

import { yuaiUser } from '@/lib/yuai/user-key'
import { requireAuth } from '@/middleware/auth'

import type { AuthVariables } from '@/middleware/auth'

/** The signed-in user's own Yu AI account, matched by email. */
export const yuaiRoutes = new Hono<{ Variables: AuthVariables }>()

yuaiRoutes.use('*', requireAuth)

// USD; null when the email has no Yu AI account.
yuaiRoutes.get('/balance', async (c) => {
  const user = await yuaiUser(c.get('userEmail'))

  return c.json({ balance: user ? user.balance : null })
})
