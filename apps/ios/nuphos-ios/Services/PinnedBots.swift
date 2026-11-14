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
}

/// What the pinned row draws: the pinned Bots that still exist, in pin order.
///
/// Empty when there is no pin, or when none of the pinned ids resolve — the
/// row is then not built at all, so it leaves no space and no element in the
/// accessibility tree.
struct PinnedBotsRowModel: Equatable, Sendable {
    let bots: [PinnedBot]

    init(order: PinnedBotsOrder, available: [PinnedBot]) {
        bots = order.resolved(in: available)
    }

    var isVisible: Bool { !bots.isEmpty }
    var count: Int { bots.count }
}

/// The device-local store behind the pinned row.
enum PinnedBotsStorage {
    static let key = "nuphos.pinnedBots"

    static func load(defaults: UserDefaults = .standard) -> PinnedBotsOrder {
        PinnedBotsOrder(defaults.stringArray(forKey: key) ?? [])
    }

    static func save(_ order: PinnedBotsOrder, defaults: UserDefaults = .standard) {
        defaults.set(order.ids, forKey: key)
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
