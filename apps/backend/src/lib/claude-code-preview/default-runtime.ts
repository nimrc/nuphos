import { ObjectId } from 'mongodb'

import { config } from '@/config'
import { teams } from '@/lib/identity/shared'
import { logError } from '@/lib/observability'

import { createManagedRuntimeInstance } from './runtime-instances'
import { defaultRuntimeLabel } from './runtime-provider'
import { runtimes } from './runtime-registry'

/** How long a listing's claim keeps others from creating; outlives a slow create, not a crash. */
const CLAIM_MS = 60_000

/**
 * Keeps a team's cloud runtime without anyone adding one: whenever the team's runtimes are listed
 * and it has no hosted runtime of `config...defaultProvider`, one is created, owned by the team
 * owner. Clients offer no way to add a runtime, so deleting it is how a team starts over: once the
 * deletion finishes (the record lasts until then), the next listing creates a fresh one. A
 * short-lived claim on the team document keeps concurrent listings from creating two. Never throws.
 */
export async function ensureDefaultRuntime(teamId: string): Promise<void> {
  const { enabled, defaultProvider: provider } = config.claudeCodeRuntimeProvisioner

  if (!enabled || !provider || !ObjectId.isValid(teamId)) return
  const hosted = { teamId, hostedBy: 'nuphos' as const, provider }

  try {
    if (await runtimes().findOne(hosted)) return
  } catch {
    return
  }
  const _id = new ObjectId(teamId)
  const claimedAt = new Date()
  const team = await teams()
    .findOneAndUpdate(
      {
        _id,
        $or: [
          { defaultRuntimeClaimedAt: { $exists: false } },
          { defaultRuntimeClaimedAt: { $lt: new Date(claimedAt.getTime() - CLAIM_MS) } },
        ],
      },
      { $set: { defaultRuntimeClaimedAt: claimedAt } },
    )
    .catch(() => null)

  if (!team) return
  try {
    if (await runtimes().findOne(hosted)) return
    await createManagedRuntimeInstance({
      teamId,
      userId: team.ownerID.toHexString(),
      provider,
      label: defaultRuntimeLabel(provider, []),
    })
  } catch (error) {
    logError('openab.default_runtime.create_failed', error, { team_id: teamId })
  } finally {
    await teams()
      .updateOne(
        { _id, defaultRuntimeClaimedAt: claimedAt },
        { $unset: { defaultRuntimeClaimedAt: '' } },
      )
      .catch(() => undefined)
  }
}
