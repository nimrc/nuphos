import { mock } from 'bun:test'

import * as actual from '@/lib/agent/thread-bridge'

import { buildDouble, makeInstaller } from '../double-registry'

const double = buildDouble('@/lib/agent/thread-bridge', actual)

await mock.module('@/lib/agent/thread-bridge', () => double)

export const useThreadBridge = makeInstaller<typeof actual>('@/lib/agent/thread-bridge')
