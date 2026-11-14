import { afterEach, beforeEach, expect, test } from 'bun:test'
import { ObjectId } from 'mongodb'

import { config } from '@/config'
import { useDb } from '@/lib/test/doubles/db'
import { useRuntimeInstances } from '@/lib/test/doubles/runtime-instances'
import { useRuntimeRegistry } from '@/lib/test/doubles/runtime-registry'

import { ensureDefaultRuntime } from './default-runtime'

type Team = { _id: ObjectId; ownerID: ObjectId; defaultRuntimeClaimedAt?: Date }
type Claim = { _id: ObjectId; $or: [unknown, { defaultRuntimeClaimedAt: { $lt: Date } }] }

const OWNER = new ObjectId()
const TEAM = new ObjectId()
let team: Team
let hosted: { teamId: string; provider: string }[]
let created: { teamId: string; userId: string; provider: string; label: string }[]
let failNext = false
const provisioner = config.claudeCodeRuntimeProvisioner
const original = { ...provisioner }

useDb({
  db: () => ({
    collection: () => ({
      // An atomic claim, like Mongo's: only an unclaimed team, or one claimed too long ago, matches.
      findOneAndUpdate: async (filter: Claim, update: { $set: Partial<Team> }) => {
        const held = team.defaultRuntimeClaimedAt

        if (
          !filter._id.equals(team._id) ||
          (held && held >= filter.$or[1].defaultRuntimeClaimedAt.$lt)
        )
          return null
        const before = { ...team }

        Object.assign(team, update.$set)

        return before
      },
      updateOne: async (filter: { defaultRuntimeClaimedAt: Date }) => {
        if (team.defaultRuntimeClaimedAt === filter.defaultRuntimeClaimedAt)
          delete team.defaultRuntimeClaimedAt

        return { modifiedCount: 1 }
      },
    }),
  }),
} as never)
useRuntimeRegistry({
  runtimes: () =>
    ({
      findOne: async (filter: { teamId: string; provider: string }) =>
        hosted.find((r) => r.teamId === filter.teamId && r.provider === filter.provider) ?? null,
    }) as never,
})
useRuntimeInstances({
  createManagedRuntimeInstance: async (args: (typeof created)[number]) => {
    if (failNext) {
      failNext = false
      throw new Error('cluster unavailable')
    }
    created.push(args)
    hosted.push({ teamId: args.teamId, provider: args.provider })

    return {} as never
  },
})

beforeEach(() => {
  team = { _id: TEAM, ownerID: OWNER }
  hosted = []
  created = []
  Object.assign(provisioner, { enabled: true, defaultProvider: 'opencode' })
})
afterEach(() => {
  Object.assign(provisioner, original)
})

test('creates one runtime for the owner, however many listings race', async () => {
  await Promise.all([1, 2, 3].map(() => ensureDefaultRuntime(TEAM.toHexString())))
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created).toEqual([
    {
      teamId: TEAM.toHexString(),
      userId: OWNER.toHexString(),
      provider: 'opencode',
      label: 'OpenCode',
    },
  ])
})

test('a deleted runtime is replaced on the next listing, once its record is gone', async () => {
  await ensureDefaultRuntime(TEAM.toHexString())
  // Still deleting: the record stays until the runtime is torn down.
  await ensureDefaultRuntime(TEAM.toHexString())
  expect(created).toHaveLength(1)
  hosted = []
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created).toHaveLength(2)
  expect(team.defaultRuntimeClaimedAt).toBeUndefined()
})

test('a claim left by a listing that died stops blocking once it is stale', async () => {
  team.defaultRuntimeClaimedAt = new Date()
  await ensureDefaultRuntime(TEAM.toHexString())
  expect(created).toEqual([])
  team.defaultRuntimeClaimedAt = new Date(Date.now() - 120_000)
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created).toHaveLength(1)
})

test('a team that already has a hosted runtime gets none', async () => {
  hosted = [{ teamId: TEAM.toHexString(), provider: 'opencode' }]
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created).toEqual([])
})

test('a failed create is retried on the next listing', async () => {
  failNext = true
  await ensureDefaultRuntime(TEAM.toHexString())
  expect(created).toEqual([])
  await ensureDefaultRuntime(TEAM.toHexString())
  expect(created).toHaveLength(1)
})

test('nothing without a default provider or with the provisioner off', async () => {
  Object.assign(provisioner, { defaultProvider: undefined })
  await ensureDefaultRuntime(TEAM.toHexString())
  Object.assign(provisioner, { enabled: false, defaultProvider: 'opencode' })
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created).toEqual([])
})

test('a new default provider gives a team that had the old one a runtime of the new one', async () => {
  await ensureDefaultRuntime(TEAM.toHexString())
  Object.assign(provisioner, { defaultProvider: 'omp' })
  await ensureDefaultRuntime(TEAM.toHexString())
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created.map((c) => c.provider)).toEqual(['opencode', 'omp'])
})
