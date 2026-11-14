import { z } from 'zod'

import { handOff, listHandoffs, updateHandoff } from '@/lib/agent/handoffs'
import { toolError, toolResult } from '@/lib/mcp/protocol'

import { toolInputJsonSchema } from './ai-sdk-adapter'

import type { PreviewToolModule } from '../preview-tool-context'

const label = z
  .string()
  .trim()
  .min(1)
  .max(200)
  .describe('Short step label in the conversation language.')
const dueInMinutes = z
  .number()
  .int()
  .min(5)
  .max(7 * 24 * 60)
const create = z
  .object({
    label,
    threadId: z.string().uuid().describe('The Bot or thread to hand the work to.'),
    task: z
      .string()
      .trim()
      .min(1)
      .max(3000)
      .describe('What to do, self-contained; never include credentials.'),
    doneWhen: z.string().trim().min(1).max(500).optional().describe('What done looks like.'),
    dueInMinutes: dueInMinutes
      .optional()
      .describe('When to expect a report; you are reminded if none comes. Default 60.'),
  })
  .strict()
const update = z
  .object({
    label,
    handoffId: z.string().uuid(),
    status: z
      .enum(['open', 'blocked', 'done', 'cancelled'])
      .optional()
      .describe(
        'Assignee: "done" or "blocked". Delegator: "done" to accept, "cancelled", or "open".',
      ),
    report: z
      .string()
      .trim()
      .min(1)
      .max(3000)
      .optional()
      .describe('The outcome, or what blocks it.'),
    dueInMinutes: dueInMinutes.optional().describe('Delegator only: a new due time from now.'),
  })
  .strict()
const list = z
  .object({ label, all: z.boolean().optional().describe('Include finished handoffs.') })
  .strict()

function answer(work: Promise<unknown>) {
  return work.then(toolResult, (error: unknown) =>
    toolError(error instanceof Error ? error.message : String(error)),
  )
}

export function handoffToolModule(): PreviewToolModule {
  return {
    definitions: [
      {
        name: 'hand_off',
        description:
          'Hand a piece of work to another Bot or thread you own in this team and track it until ' +
          'it is reported. Like send_message_to_thread, but recorded with a due time: the assignee ' +
          'reports back with update_handoff, and you are reminded when no report comes in time. ' +
          'Use it when you delegate work you need back; use send_message_to_thread for a plain message.',
        inputSchema: toolInputJsonSchema(create),
      },
      {
        name: 'update_handoff',
        description:
          'Update a handoff. As its assignee, report it "done" or "blocked" with a short report: ' +
          'that wakes the Bot that handed it out. As the delegator, accept it ("done"), cancel it, ' +
          'reopen it, or move its due time.',
        inputSchema: toolInputJsonSchema(update),
      },
      {
        name: 'list_handoffs',
        description:
          'List the handoffs this conversation handed out or was given that are still open or ' +
          'blocked (all=true includes finished ones), with their status, due time and report.',
        inputSchema: toolInputJsonSchema(list),
      },
    ],
    handlers: (ctx) => ({
      hand_off: async (args) => {
        const parsed = create.safeParse(args)

        if (!parsed.success) return toolError(parsed.error.message)
        const { threadId, task, doneWhen, dueInMinutes: due } = parsed.data

        return answer(
          handOff(ctx, {
            toSessionId: threadId,
            task,
            ...(doneWhen ? { doneWhen } : {}),
            ...(due ? { dueInMinutes: due } : {}),
          }),
        )
      },
      update_handoff: async (args) => {
        const parsed = update.safeParse(args)

        if (!parsed.success) return toolError(parsed.error.message)
        const { label: _label, ...input } = parsed.data

        return answer(updateHandoff(ctx, input))
      },
      list_handoffs: async (args) => {
        const parsed = list.safeParse(args)

        if (!parsed.success) return toolError(parsed.error.message)

        return answer(listHandoffs(ctx.sessionId, ctx.userId, parsed.data.all ?? false))
      },
    }),
  }
}
