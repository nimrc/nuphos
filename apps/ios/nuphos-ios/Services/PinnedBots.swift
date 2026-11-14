import Foundation

/// An ordered list of pinned Bot ids, kept only on this device.
///
/// The order is the order the viewer pinned them: a new pin goes last, pinning
/// an id already in the list changes nothing, and unpinning removes it. The
/// list is sanitised on every load, so a duplicate or an empty id written by an
/// older build never reaches the row. Bots that no longer exist are pruned once
/// the loaded Bots list says which ids are still available.
struct PinnedBotsOrder: Equatable, Sendable {
    private(set) var ids: [String]

    init(_ ids: [String] = []) {
        self.ids = Self.sanitised(ids)
    }

    /// Duplicate and empty ids dropped, first appearance kept.
    static func sanitised(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    /// Appends a new pin. False when it was already pinned or the id is empty.
    @discardableResult
    mutating func pin(_ id: String) -> Bool {
        guard !id.isEmpty, !ids.contains(id) else { return false }
        ids.append(id)
        return true
    }

    /// Removes a pin. False when it was not pinned.
    @discardableResult
    mutating func unpin(_ id: String) -> Bool {
        guard let index = ids.firstIndex(of: id) else { return false }
        ids.remove(at: index)
        return true
    }

    /// Drops ids the loaded Bots list no longer has, keeping the rest in order.
    /// True when something was removed.
    @discardableResult
    mutating func prune(keeping available: Set<String>) -> Bool {
        let kept = ids.filter { available.contains($0) }
        guard kept != ids else { return false }
        ids = kept
        return true
    }

    /// The pinned Bots, in pin order, resolved against what the list loaded.
    func resolved(in bots: [PinnedBot]) -> [PinnedBot] {
        var byId: [String: PinnedBot] = [:]
        for bot in bots where byId[bot.id] == nil { byId[bot.id] = bot }
        return ids.compactMap { byId[$0] }
    }
}

/// One Bot as the pinned row shows it.
struct PinnedBot: Identifiable, Equatable, Sendable {
    /// The Bot's own session id: what the pin stores.
    let id: String
    /// The chat that opens it; the Bot itself when it has no 1:1 chat yet.
    let conversationId: String
    let title: String
    /// The face the Bots list carried, when this row is a Bot without a chat.
    let avatar: String?
    let runtime: String?

    init(id: String, conversationId: String, title: String, avatar: String? = nil, runtime: String? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.title = title
        self.avatar = avatar
        self.runtime = runtime
    }

    /// Whether the row has anything to say for this Bot. A slot with no name
    /// reads as an anonymous circle, so it is not drawn at all.
    var isDrawable: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// What the pinned row draws: the pinned Bots that still exist, in pin order.
///
/// Empty when there is no pin, or when none of the pinned ids resolve — the
/// row is then not built at all, so it leaves no space and no element in the
/// accessibility tree. A pin this list cannot resolve draws nothing either:
/// the stored id stays (the list may have been truncated), but an anonymous
/// empty circle is never shown for it.
struct PinnedBotsRowModel: Equatable, Sendable {
    let bots: [PinnedBot]

    init(order: PinnedBotsOrder, available: [PinnedBot]) {
        bots = order.resolved(in: available).filter(\.isDrawable)
    }

    var isVisible: Bool { !bots.isEmpty }
    var count: Int { bots.count }
}


/// The row's measurements, shared with the standalone tests.
enum PinnedBotsLayout {
    static let height: CGFloat = 60
    static let avatar: CGFloat = 44
    /// A slot is the ring's outer diameter: 44 pt face + 2 x 2 pt gap + 2 x 2.5 pt
    /// ring = 53. The ring sits 2 pt clear of the face, so the slot is wider than
    /// the face and the gap between two faces is spacing + (slot - avatar).
    static let slot: CGFloat = 53
    static let spacing: CGFloat = 3
    /// Slots centre their faces, so the row inset gives up the slot's overflow.
    /// 15.5 + (53 - 44) / 2 = 20, the same left edge as a list row's avatar.
    static let inset: CGFloat = 15.5
    static let ring: CGFloat = 2.5
    static let fade: CGFloat = 20
    static let hairline: CGFloat = 0.5

    /// Navigation-bar clearance above the List's safe-area origin. Measured
    /// as the gap between the row's safe-area top and the first list content:
    /// 55 pt on iPhone 18 Pro (121.66 -> 176.66) and iPad Pro 13-inch M5
    /// (91.5 -> 146.5). It keeps the row below the bar's material.
    static let navigationBarClearance: CGFloat = 55

    static func rowTop(forSafeAreaTop top: CGFloat) -> CGFloat {
        top + navigationBarClearance
    }
}

/// The accessibility structure of the row: a labelled container once there
/// is a Bot, and no element at all when nothing is pinned.
enum PinnedBotsAccessibility: Equatable {
    case absent
    case container(count: Int)

    var containerCount: Int? {
        if case .container(let count) = self { return count }
        return nil
    }
}

extension PinnedBotsRowModel {
    var accessibility: PinnedBotsAccessibility {
        isVisible ? .container(count: count) : .absent
    }
}

/// Whether a listing page proves the list is complete.
///
/// The Bots list is one page per scope and does not page, so a page at the
/// limit may be cut short. A server answer of `hasMore` is authoritative; a
/// page that reached the limit counts as incomplete even when an older
/// backend leaves `hasMore` out.
enum PinnedBotsListing {
    static func pageIsComplete(rowCount: Int, limit: Int, hasMore: Bool) -> Bool {
        !hasMore && rowCount < limit
    }
}

/// Whether the loaded Bots list may prune saved pins. Pins are local to one
/// team on this device, so a filtered list (search replaces `botsList`), an
/// empty list (a team switch clears it), or a list loaded for another team or
/// query must never be allowed to delete them. A list that hit the server's
/// page limit may be missing Bots beyond it, so it is not proof either: a pin
/// that is not in a truncated list is probably just further down.
struct PinnedBotsPrunePolicy: Equatable, Sendable {
    let search: String
    /// The query `botsList` was actually loaded with, which can lag the field
    /// when a search is cleared but its reload fails.
    let loadedQuery: String?
    let botsListIsEmpty: Bool
    let loadedTeamId: String?
    /// The team the page currently shows.
    let currentTeamId: String?
    /// The team the session's pins belong to.
    let pinsTeamId: String?
    /// False when any listing scope returned a full page with more rows, or
    /// when the load did not record whether it did: an unverified list is
    /// never allowed to prune.
    let listIsComplete: Bool

    var allowsPruning: Bool {
        search.isEmpty
            && loadedQuery == search
            && !botsListIsEmpty
            && loadedTeamId != nil
            && loadedTeamId == currentTeamId
            && pinsTeamId == currentTeamId
            && listIsComplete
    }
}

/// What one pinned avatar reads aloud. The label is the name exactly once;
/// the value is only the selected wording, never the name again.
struct PinnedBotAccessibility: Equatable, Sendable {
    let label: String
    let value: String

    init(title: String, isCurrent: Bool) {
        label = title
        value = isCurrent ? String(localized: "Selected") : ""
    }
}

/// The device-local store behind the pinned row.
enum PinnedBotsStorage {
    /// The pre-team key. Its list follows the first team selected after this
    /// build, so an upgrade does not lose the pins already on the device.
    static let legacyKey = "nuphos.pinnedBots"

    static func key(for teamId: String) -> String { "\(legacyKey).\(teamId)" }

    /// The team's own list.
    ///
    /// `canAdoptLegacy` decides whether the old list may move into this team.
    /// It must be false until the team list has loaded and this id is one of
    /// them: the app reads pins for the team id the launch cache remembered,
    /// which can name a team that no longer exists. Migrating into that id
    /// would write the pins into a dead team's key and delete the old list, so
    /// they would never reach a real team. Until then this reads the team's own
    /// key (nothing, for a team that never had pins) and leaves the legacy
    /// list where it is for the team that does qualify.
    static func load(
        teamId: String,
        canAdoptLegacy: Bool,
        defaults: UserDefaults = .standard
    ) -> PinnedBotsOrder {
        let scopedKey = key(for: teamId)
        if let scoped = defaults.stringArray(forKey: scopedKey) {
            // One verified team has taken the old list; no other team may
            // read it. Until the team list confirms this id, the id can name
            // a dead team, and deleting the old list here would strand the
            // pins that a real team still has to inherit.
            if canAdoptLegacy, defaults.object(forKey: legacyKey) != nil {
                defaults.removeObject(forKey: legacyKey)
            }
            return PinnedBotsOrder(scoped)
        }
        guard canAdoptLegacy, !teamId.isEmpty,
              let legacy = defaults.stringArray(forKey: legacyKey) else { return PinnedBotsOrder() }
        let order = PinnedBotsOrder(legacy)
        defaults.set(order.ids, forKey: scopedKey)
        defaults.removeObject(forKey: legacyKey)
        return order
    }

    /// A team's stored list, never migrating: for callers that want to know
    /// what is saved rather than what may be adopted.
    static func stored(teamId: String, defaults: UserDefaults = .standard) -> PinnedBotsOrder {
        PinnedBotsOrder(defaults.stringArray(forKey: key(for: teamId)) ?? [])
    }

    static func save(_ order: PinnedBotsOrder, teamId: String, defaults: UserDefaults = .standard) {
        defaults.set(order.ids, forKey: key(for: teamId))
    }
}

/// The pins for the team on screen: which team they belong to and its order.
/// AgentPage keeps one, so a team switch loads that team's pins and nothing
/// else — another team never sees them and can never delete them.
struct PinnedBotsSession: Equatable, Sendable {
    private(set) var teamId: String?
    private(set) var order: PinnedBotsOrder

    init(teamId: String? = nil, order: PinnedBotsOrder = PinnedBotsOrder()) {
        self.teamId = teamId
        self.order = order
    }

    /// Loads `teamId`'s pins. Nil clears the row without touching any team.
    ///
    /// `canAdoptLegacy` says the team list has loaded and this id is one of
    /// its teams; only then may the pre-team list move into it. It defaults to
    /// false, so a caller that has not checked cannot migrate by accident.
    mutating func select(
        teamId: String?,
        canAdoptLegacy: Bool = false,
        defaults: UserDefaults = .standard
    ) {
        guard teamId != self.teamId else { return }
        self.teamId = teamId
        order = teamId.map {
            PinnedBotsStorage.load(teamId: $0, canAdoptLegacy: canAdoptLegacy, defaults: defaults)
        } ?? PinnedBotsOrder()
    }

    /// Moves the pre-team list into the session's team once that team has
    /// turned out to exist. The team the session already read without
    /// migrating — the launch cache's, before the list loaded — takes the pins
    /// here, so a valid team still inherits them.
    mutating func adoptLegacyPinsIfPossible(
        teamIsValid: Bool,
        defaults: UserDefaults = .standard
    ) {
        guard teamIsValid, let teamId, !teamId.isEmpty else { return }
        if defaults.object(forKey: PinnedBotsStorage.key(for: teamId)) != nil {
            // This verified team already has its own list. The pre-team list
            // cannot be merged into it without rewriting pins made since, so
            // drop it before another team can inherit it.
            defaults.removeObject(forKey: PinnedBotsStorage.legacyKey)
            return
        }
        guard order.ids.isEmpty,
              let legacy = defaults.stringArray(forKey: PinnedBotsStorage.legacyKey)
        else { return }
        order = PinnedBotsOrder(legacy)
        PinnedBotsStorage.save(order, teamId: teamId, defaults: defaults)
        defaults.removeObject(forKey: PinnedBotsStorage.legacyKey)
    }

    @discardableResult
    mutating func pin(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        guard order.pin(id) else { return false }
        save(defaults: defaults)
        return true
    }

    @discardableResult
    mutating func unpin(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        guard order.unpin(id) else { return false }
        save(defaults: defaults)
        return true
    }

    /// Drops ids the loaded list no longer has, but only when that list is
    /// this team's current, unfiltered, non-empty and complete list.
    @discardableResult
    mutating func prune(
        available: Set<String>,
        search: String,
        loadedQuery: String?,
        botsListIsEmpty: Bool,
        loadedTeamId: String?,
        currentTeamId: String?,
        listIsComplete: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let policy = PinnedBotsPrunePolicy(
            search: search,
            loadedQuery: loadedQuery,
            botsListIsEmpty: botsListIsEmpty,
            loadedTeamId: loadedTeamId,
            currentTeamId: currentTeamId,
            pinsTeamId: teamId,
            listIsComplete: listIsComplete
        )
        guard policy.allowsPruning, order.prune(keeping: available) else { return false }
        save(defaults: defaults)
        return true
    }

    private func save(defaults: UserDefaults) {
        guard let teamId else { return }
        PinnedBotsStorage.save(order, teamId: teamId, defaults: defaults)
    }
}

extension PinnedBot {
    /// The initial an avatar without a face shows: the first word's first
    /// character, which is the first character for a Chinese name.
    static func initial(of title: String) -> String {
        let word = title.split(whereSeparator: { $0.isWhitespace }).first ?? Substring(title)
        return word.first.map { String($0).uppercased() } ?? ""
    }
}
