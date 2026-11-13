import { afterEach, beforeEach, expect, test } from 'bun:test'
import { ObjectId } from 'mongodb'

import { config } from '@/config'
import { useDb } from '@/lib/test/doubles/db'
import { useRuntimeInstances } from '@/lib/test/doubles/runtime-instances'
import { useRuntimeRegistry } from '@/lib/test/doubles/runtime-registry'

import { ensureDefaultRuntime } from './default-runtime'

type Team = { _id: ObjectId; ownerID: ObjectId; defaultRuntimeClaimedAt?: Date }

const OWNER = new ObjectId()
const TEAM = new ObjectId()
let team: Team
let hosted: { teamId: string }[]
let created: { teamId: string; userId: string; provider: string; label: string }[]
let failNext = false
const provisioner = config.claudeCodeRuntimeProvisioner
const original = { ...provisioner }

useDb({
  db: () => ({
    collection: () => ({
      // An atomic claim, like Mongo's: only a team without the field matches.
      findOneAndUpdate: async (filter: { _id: ObjectId }, update: { $set: Partial<Team> }) => {
        if (!filter._id.equals(team._id) || team.defaultRuntimeClaimedAt) return null
        const before = { ...team }

        Object.assign(team, update.$set)

        return before
      },
      updateOne: async () => {
        delete team.defaultRuntimeClaimedAt

        return { modifiedCount: 1 }
      },
    }),
  }),
} as never)
useRuntimeRegistry({
  runtimes: () =>
    ({
      findOne: async (filter: { teamId: string }) =>
        hosted.find((r) => r.teamId === filter.teamId) ?? null,
    }) as never,
})
useRuntimeInstances({
  createManagedRuntimeInstance: async (args: (typeof created)[number]) => {
    if (failNext) {
      failNext = false
      throw new Error('cluster unavailable')
    }
    created.push(args)
    hosted.push({ teamId: args.teamId })

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

test('a team whose runtime was deleted on purpose gets no new one', async () => {
  await ensureDefaultRuntime(TEAM.toHexString())
  hosted = []
  await ensureDefaultRuntime(TEAM.toHexString())

  expect(created).toHaveLength(1)
})

test('a team that already has a hosted runtime gets none', async () => {
  hosted = [{ teamId: TEAM.toHexString() }]
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
