import { Star } from 'lucide-react'

import { t } from '../../i18n'
import { Button } from '../ui/button'

import type { AgentFace } from '../../api/agent-types'

/** An agent's row in the Share card: what it is here, and what the viewer may do with it. */
export function AgentParticipantActions({
  agent,
  disabled,
  onRemove,
}: {
  agent: AgentFace
  disabled: boolean
  onRemove: () => void
}) {
  const { lead, setLead } = agent

  return (
    <>
      {lead ? (
        <span className="flex items-center gap-1 px-1.5 text-[12px] text-tertiary">
          <Star className="h-3 w-3 text-warning" fill="currentColor" aria-hidden="true" />
          {t('Lead')}
        </span>
      ) : (
        <span className="px-1.5 text-[12px] text-tertiary">{t('Agent')}</span>
      )}
      {setLead && (
        <Button variant="ghost" size="sm" disabled={disabled} onClick={() => setLead(!lead)}>
          {lead ? t('Stop leading') : t('Make lead')}
        </Button>
      )}
      {agent.removable && (
        <Button variant="ghost" size="sm" disabled={disabled} onClick={onRemove}>
          {t('Remove')}
        </Button>
      )}
    </>
  )
}
