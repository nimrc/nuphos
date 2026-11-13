import { mock } from 'bun:test'

import * as actual from '@/lib/claude-code-preview/runtime-instances'

import { buildDouble, makeInstaller } from '../double-registry'

const double = buildDouble('@/lib/claude-code-preview/runtime-instances', actual)

await mock.module('@/lib/claude-code-preview/runtime-instances', () => double)

export const useRuntimeInstances = makeInstaller<typeof actual>(
  '@/lib/claude-code-preview/runtime-instances',
)
