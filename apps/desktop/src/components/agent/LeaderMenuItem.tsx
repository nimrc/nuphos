import { Star } from 'lucide-react'

import { api } from '../../api'
import { t } from '../../i18n'
import { pickBotLeader, useIsBotLeader } from '../../lib/botLeaders'
import { MenuItem } from '../ui/menu'
import { toast } from '../ui/toast'

/** Makes a Bot the Leader of its owner's other Bots in this team, or stops it leading. */
export function LeaderMenuItem({ sessionId, teamId }: { sessionId: string; teamId: string }) {
  const leader = useIsBotLeader(sessionId)

  return (
    <MenuItem
      icon={<Star className="h-3.5 w-3.5" />}
      onClick={() => {
        pickBotLeader(sessionId, !leader, () =>
          api.agentSetBotLeader(sessionId, teamId, !leader),
        ).catch((err: unknown) => toast.apiError(t('Could not change the Leader'), err))
      }}
    >
      {leader ? t('Stop leading Bots') : t('Make Leader of my Bots')}
    </MenuItem>
  )
}
