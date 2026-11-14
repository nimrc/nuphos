import { Star } from 'lucide-react'

import { t } from '../../i18n'
import { useIsBotLeader } from '../../lib/botLeaders'
import { Tooltip } from '../ui/tooltip'

/** On the Bot that leads its owner's other Bots, or on its 1:1 chat. */
export function LeaderBadge({ botId }: { botId: string | undefined }) {
  const leader = useIsBotLeader(botId ?? '')

  if (!leader) return null

  return (
    <Tooltip content={t('Leader: hands work to your other Bots')}>
      <span className="flex h-[18px] w-[18px] flex-shrink-0 items-center justify-center text-warning">
        <Star
          className="h-3.5 w-3.5"
          strokeWidth={1.8}
          fill="currentColor"
          aria-label={t('Leader')}
        />
      </span>
    </Tooltip>
  )
}
