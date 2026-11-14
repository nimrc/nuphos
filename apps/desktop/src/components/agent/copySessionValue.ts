import { t } from '../../i18n'
import { copyLinkWithFeedback } from '../../lib/copyLink'
import { toast } from '../ui/toast'

/** Copies a chat's link or ID, saying so, or why it could not. */
export function copySessionValue(value: string, what: 'Link' | 'ID', isBot: boolean) {
  const copied =
    what === 'Link' ? t('Link copied') : isBot ? t('Bot ID copied') : t('Task ID copied')

  void copyLinkWithFeedback(value, (text) => navigator.clipboard.writeText(text), {
    onSuccess: () =>
      toast.success(copied, undefined, {
        timeoutMs: 1200,
        dedupe: false,
      }),
    onError: () =>
      toast.error(
        what === 'Link'
          ? t('Could not copy link')
          : isBot
            ? t('Could not copy Bot ID')
            : t('Could not copy task ID'),
        t('Clipboard was blocked.'),
      ),
  })
}
