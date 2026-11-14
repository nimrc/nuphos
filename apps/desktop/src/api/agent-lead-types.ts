/** A chat's Bot as its lead: people's posts wake it, and it hands work to the other Bots. */
export type AgentLead = {
  lead?: boolean
  /** Set where this viewer, the chat's owner, may make it the lead or stop it leading. */
  setLead?: (lead: boolean) => void
}
