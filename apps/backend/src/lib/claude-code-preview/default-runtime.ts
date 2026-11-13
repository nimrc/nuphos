import { ObjectId } from 'mongodb'

import { config } from '@/config'
import { teams } from '@/lib/identity/shared'
import { logError } from '@/lib/observability'

import { createManagedRuntimeInstance } from './runtime-instances'
import { defaultRuntimeLabel } from './runtime-provider'
import { runtimes } from './runtime-registry'

/**
 * Gives a team its cloud runtime without anyone adding one: the first time the team's runtimes
 * are listed, a team with no hosted runtime gets one of `config...defaultProvider`, owned by the
 * team owner. Once per team: a claim on the team document makes concurrent listings create one,
 * and a team whose runtime was later deleted on purpose is not given another. A failed create
 * drops the claim so the next listing tries again. Never throws.
 */
export async function ensureDefaultRuntime(teamId: string): Promise<void> {
  const { enabled, defaultProvider: provider } = config.claudeCodeRuntimeProvisioner

  if (!enabled || !provider || !ObjectId.isValid(teamId)) return
  const _id = new ObjectId(teamId)
  const team = await teams()
    .findOneAndUpdate(
      { _id, defaultRuntimeClaimedAt: { $exists: false } },
      { $set: { defaultRuntimeClaimedAt: new Date() } },
    )
    .catch(() => null)

  if (!team) return
  try {
    if (await runtimes().findOne({ teamId, hostedBy: 'nuphos' })) return
    await createManagedRuntimeInstance({
      teamId,
      userId: team.ownerID.toHexString(),
      provider,
      label: defaultRuntimeLabel(provider, []),
    })
  } catch (error) {
    logError('openab.default_runtime.create_failed', error, { team_id: teamId })
    await teams()
      .updateOne({ _id }, { $unset: { defaultRuntimeClaimedAt: '' } })
      .catch(() => undefined)
  }
}
