import { agentMessages } from './db'
import { postText } from './db/channels'
import { parseMessageMetadata } from './message-metadata'

import type { AgentConversation } from './db'
import type { MessageMetadata } from './message-metadata'

// Enough of the original to recognize it; the reply is about it, not a copy of it.
const REPLY_QUOTE_LENGTH = 200

/**
 * What a reply quotes: a snapshot of the post `messageId` in this channel, so
 * the quote stays when the original goes. None for a post the channel lacks.
 */
export async function replyQuote(
  channel: Pick<AgentConversation, 'sessionId' | 'userId'>,
  messageId: unknown,
): Promise<MessageMetadata['replyTo']> {
  if (typeof messageId !== 'string' || !messageId || messageId.length > 100) return undefined
  const original = await agentMessages().findOne({
    sessionId: channel.sessionId,
    userId: channel.userId,
    messageId,
  })
  const sender = parseMessageMetadata(original?.metadata)?.sender

  if (!original || !sender) return undefined
  // A post of files alone is quoted as its file.
  const text = Array.from(postText(original.parts).trim()).slice(0, REPLY_QUOTE_LENGTH).join('')

  return { id: messageId, authorName: sender.displayName, text: text || 'File' }
}
