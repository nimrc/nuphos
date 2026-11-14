import { favoriteIdentity } from '../../lib/sidebar-favorites/store.ts'
import { favoriteSessionId } from '../../lib/sidebarPinnedChats.ts'

import type { Item } from './types'
import type { SidebarFavorite } from '../../lib/sidebarFavorites.ts'

/** The row's own entry: an href when it has a route, else its key. */
export function favoriteEntryForItem(item: Item): SidebarFavorite {
  return item.href ? { label: item.label, href: item.href } : { label: item.label, key: item.key }
}

/**
 * Matches either identity, so a pin made before this row gained an href — or
 * from the other surface — is still recognised and removable. A Bot's chat
 * also matches a pin made on the Bot before that chat existed.
 */
export function favoriteMatchIn(favorites: SidebarFavorite[], item: Item) {
  const identity = favoriteIdentity(favoriteEntryForItem(item))

  return favorites.find((entry) => {
    const entryIdentity = favoriteIdentity(entry)

    return (
      entryIdentity === identity ||
      entryIdentity === item.key ||
      (item.botChannelOf !== undefined && favoriteSessionId(entry) === item.botChannelOf)
    )
  })
}
