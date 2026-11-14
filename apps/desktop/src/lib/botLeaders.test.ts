import assert from 'node:assert/strict'
import test from 'node:test'

import { isBotLeader, pickBotLeader, receiveBotLeaders } from './botLeaders.ts'

const read = (...ids: string[]) => ids.map(isBotLeader)

test('one Bot leads at a time, and a failed save puts the old one back', async () => {
  receiveBotLeaders([
    { sessionId: 'a', avatar: '07-ada', leader: true },
    { sessionId: 'b', avatar: '07-ada' },
    { sessionId: 'task', leader: true },
  ])
  assert.deepEqual(read('a', 'b', 'task'), [true, false, false])
  await pickBotLeader('b', true, () => Promise.resolve())
  assert.deepEqual(read('a', 'b'), [false, true])
  await assert.rejects(pickBotLeader('a', true, () => Promise.reject(new Error('no'))))
  assert.deepEqual(read('a', 'b'), [false, true])
  await pickBotLeader('b', false, () => Promise.resolve())
  assert.deepEqual(read('a', 'b'), [false, false])
})
