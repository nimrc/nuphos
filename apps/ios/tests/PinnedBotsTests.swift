import Foundation

@main
enum PinnedBotsTests {
    static func main() {
        pinOrderIsTheOrderTheyWerePinned()
        pinningTwiceDoesNotDuplicate()
        unpinningRemovesAndKeepsOrder()
        storageSurvivesRelaunch()
        legacyPinsFollowTheFirstSelectedTeam()
        deadTeamCannotTakeTheLegacyPins()
        emptyTeamIdCannotTakeTheLegacyPins()
        loadDropsDuplicatesAndEmptyIds()
        pruneDropsBotsThatNoLongerExist()
        searchFilteredListDoesNotDeletePins()
        incompleteListDoesNotDeletePins()
        teamSwitchDoesNotDeleteOrShowAnotherTeamsPins()
        sessionTeamMismatchDoesNotDeletePins()
        rowIsAbsentWhenNothingIsPinned()
        anUnresolvedPinDrawsNoRowItem()
        rowAccessibilityIsAContainerAtOneAndMany()
        pinnedAvatarAccessibilityNamesTheBotOnce()
        pinnedRowUsesALazyStack()
        barClearanceClearsTheListContent()
        rowResolvesInPinOrder()
        initialIsTheFirstWordOrFirstCharacter()
        rowGeometryMatchesTheSpec()
        print("Pinned bots passed")
    }

    private static func pinOrderIsTheOrderTheyWerePinned() {
        var pins = PinnedBotsOrder()
        precondition(pins.pin("bot-b"))
        precondition(pins.pin("bot-a"))
        precondition(pins.pin("bot-c"))
        precondition(pins.ids == ["bot-b", "bot-a", "bot-c"], "pins are not in the order they were made")
    }

    private static func pinningTwiceDoesNotDuplicate() {
        var pins = PinnedBotsOrder()
        precondition(pins.pin("bot-a"))
        precondition(!pins.pin("bot-a"), "pinning an already pinned Bot reported a change")
        precondition(!pins.pin(""), "an empty id was pinned")
        precondition(pins.ids == ["bot-a"], "pinning twice duplicated the Bot")
    }

    private static func unpinningRemovesAndKeepsOrder() {
        var pins = PinnedBotsOrder(["bot-b", "bot-a", "bot-c"])
        precondition(pins.unpin("bot-a"))
        precondition(pins.ids == ["bot-b", "bot-c"], "unpinning did not keep the order")
        precondition(!pins.unpin("bot-a"), "unpinning an absent Bot reported a change")
        precondition(pins.ids == ["bot-b", "bot-c"])
    }

    private static func storageSurvivesRelaunch() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var pins = PinnedBotsOrder()
        pins.pin("bot-b"); pins.pin("bot-a")
        PinnedBotsStorage.save(pins, teamId: "team-a", defaults: defaults)
        let reloaded = PinnedBotsStorage.load(teamId: "team-a", canAdoptLegacy: false, defaults: defaults)
        precondition(reloaded == pins, "the pin order did not survive a reload")
    }

    /// The old build kept one key for every team. On upgrade its pins must
    /// follow the team selected first, not vanish and not leak to a second team.
    private static func legacyPinsFollowTheFirstSelectedTeam() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(["bot-old"], forKey: PinnedBotsStorage.legacyKey)
        var pins = PinnedBotsSession()
        pins.select(teamId: "team-a", canAdoptLegacy: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-old"], "existing pins vanished on upgrade")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) == nil,
                     "the legacy pins were left behind for another team to read")

        pins.select(teamId: "team-b", canAdoptLegacy: true, defaults: defaults)
        precondition(pins.order.ids.isEmpty, "the migrated pins were copied to a second team")
        precondition(PinnedBotsStorage.stored(teamId: "team-a", defaults: defaults).ids == ["bot-old"])
    }

    /// The launch cache hands the page the team id of the last launch, which
    /// can name a team that no longer exists. Migrating into it would write
    /// the pins to a dead key and delete the old list, so nothing may move
    /// until the team list says the id is real — and a team that does turn out
    /// real must still get the pins.
    private static func deadTeamCannotTakeTheLegacyPins() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(["bot-old"], forKey: PinnedBotsStorage.legacyKey)
        var pins = PinnedBotsSession()

        // The cached id is read first, before the team list has loaded.
        pins.select(teamId: "team-gone", canAdoptLegacy: false, defaults: defaults)
        precondition(pins.order.ids.isEmpty, "a cached, unverified team took the legacy pins")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) != nil,
                     "reading an unverified team deleted the legacy pins")
        precondition(defaults.object(forKey: PinnedBotsStorage.key(for: "team-gone")) == nil,
                     "the legacy pins were written into the dead team's key")

        // A stale scoped list on the cached id is still read, but it may not
        // consume the old list before the team is known.
        defaults.set(["bot-stale"], forKey: PinnedBotsStorage.key(for: "team-stale"))
        let stale = PinnedBotsStorage.load(teamId: "team-stale", canAdoptLegacy: false, defaults: defaults)
        precondition(stale.ids == ["bot-stale"], "an unverified team did not read its own list")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) != nil,
                     "an unverified team's own list consumed the legacy pins")

        // The list arrives and that id is not in it: still nothing moves.
        pins.adoptLegacyPinsIfPossible(teamIsValid: false, defaults: defaults)
        precondition(pins.order.ids.isEmpty, "a team missing from the list kept the legacy pins")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) != nil,
                     "a team missing from the list deleted the legacy pins")
        precondition(defaults.object(forKey: PinnedBotsStorage.key(for: "team-gone")) == nil,
                     "a team missing from the list received the legacy pins")

        // The server drops the dead team and selects a real one.
        pins.select(teamId: "team-real", canAdoptLegacy: false, defaults: defaults)
        precondition(pins.order.ids.isEmpty)
        pins.adoptLegacyPinsIfPossible(teamIsValid: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-old"], "the real team did not inherit the legacy pins")
        precondition(PinnedBotsStorage.stored(teamId: "team-real", defaults: defaults).ids == ["bot-old"],
                     "the legacy pins were not saved for the real team")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) == nil,
                     "the legacy pins were left behind after the real team took them")
        precondition(defaults.object(forKey: PinnedBotsStorage.key(for: "team-gone")) == nil,
                     "the dead team still holds a key")
    }

    /// An empty id is not a team, so it may never take the legacy list either.
    private static func emptyTeamIdCannotTakeTheLegacyPins() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(["bot-old"], forKey: PinnedBotsStorage.legacyKey)
        let loaded = PinnedBotsStorage.load(teamId: "", canAdoptLegacy: true, defaults: defaults)
        precondition(loaded.ids.isEmpty, "an empty team id took the legacy pins")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) != nil,
                     "an empty team id deleted the legacy pins")
        precondition(defaults.object(forKey: PinnedBotsStorage.key(for: "")) == nil,
                     "an empty team id was written a key")

        var pins = PinnedBotsSession(teamId: "")
        pins.adoptLegacyPinsIfPossible(teamIsValid: true, defaults: defaults)
        precondition(pins.order.ids.isEmpty, "the session adopted the legacy pins for no team")
        precondition(defaults.object(forKey: PinnedBotsStorage.legacyKey) != nil,
                     "the session deleted the legacy pins for no team")
    }

    private static func loadDropsDuplicatesAndEmptyIds() {
        let loaded = PinnedBotsOrder(["bot-b", "", "bot-a", "bot-b"])
        precondition(loaded.ids == ["bot-b", "bot-a"], "load kept a duplicate or an empty id")
    }

    private static func pruneDropsBotsThatNoLongerExist() {
        var pins = PinnedBotsOrder(["bot-b", "bot-a", "bot-c"])
        precondition(pins.prune(keeping: ["bot-c", "bot-b"]))
        precondition(pins.ids == ["bot-b", "bot-c"], "prune dropped a Bot that exists or changed the order")
        precondition(!pins.prune(keeping: ["bot-b", "bot-c"]), "prune reported a change with nothing to drop")
    }

    /// Typing in search replaces `botsList` with the matches. The debounced
    /// prune must not read that filtered list as "these Bots no longer exist".
    private static func searchFilteredListDoesNotDeletePins() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var pins = PinnedBotsSession(teamId: "team-a", order: PinnedBotsOrder(["bot-a"]))
        let searchResults: Set<String> = ["bot-z"]

        let filtered = PinnedBotsPrunePolicy(
            search: "zed", loadedQuery: "zed", botsListIsEmpty: false,
            loadedTeamId: "team-a", currentTeamId: "team-a", pinsTeamId: "team-a",
            listIsComplete: true
        )
        precondition(!filtered.allowsPruning, "a search-filtered list was allowed to prune pins")
        _ = pins.prune(available: searchResults, search: "zed", loadedQuery: "zed",
                       botsListIsEmpty: false, loadedTeamId: "team-a", currentTeamId: "team-a",
                       listIsComplete: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-a"], "a search-filtered list deleted a pin")

        // Clearing the field while the filtered list is still on screen (its
        // reload failed) must not prune against the stale matches either.
        _ = pins.prune(available: searchResults, search: "", loadedQuery: "zed",
                       botsListIsEmpty: false, loadedTeamId: "team-a", currentTeamId: "team-a",
                       listIsComplete: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-a"], "a stale filtered list deleted a pin")

        // An empty list, as during a team switch, must not prune either.
        _ = pins.prune(available: [], search: "", loadedQuery: "",
                       botsListIsEmpty: true, loadedTeamId: "team-a", currentTeamId: "team-a",
                       listIsComplete: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-a"], "an empty list deleted a pin")
    }

    /// `loadChannels` fetches at most 100 rows per scope and does not page, so
    /// a Bot beyond the first 100 is simply not loaded. Pruning that list would
    /// read "not loaded" as "deleted"; only a complete list may prune.
    private static func incompleteListDoesNotDeletePins() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var pins = PinnedBotsSession(teamId: "team-a", order: PinnedBotsOrder(["bot-150"]))
        let truncated: Set<String> = ["bot-001", "bot-002"]

        let policy = PinnedBotsPrunePolicy(
            search: "", loadedQuery: "", botsListIsEmpty: false,
            loadedTeamId: "team-a", currentTeamId: "team-a", pinsTeamId: "team-a",
            listIsComplete: false
        )
        precondition(!policy.allowsPruning, "a truncated list was allowed to prune pins")
        precondition(PinnedBotsListing.pageIsComplete(rowCount: 99, limit: 100, hasMore: false),
                     "a short page was called incomplete")
        precondition(!PinnedBotsListing.pageIsComplete(rowCount: 100, limit: 100, hasMore: false),
                     "a page at the limit was called complete")
        precondition(!PinnedBotsListing.pageIsComplete(rowCount: 3, limit: 100, hasMore: true),
                     "a page the server says has more was called complete")
        _ = pins.prune(available: truncated, search: "", loadedQuery: "",
                       botsListIsEmpty: false, loadedTeamId: "team-a", currentTeamId: "team-a",
                       listIsComplete: false, defaults: defaults)
        precondition(pins.order.ids == ["bot-150"], "a truncated list deleted a pin beyond the page")

        // A complete list of the same rows may drop it: the Bot is really gone.
        _ = pins.prune(available: truncated, search: "", loadedQuery: "",
                       botsListIsEmpty: false, loadedTeamId: "team-a", currentTeamId: "team-a",
                       listIsComplete: true, defaults: defaults)
        precondition(pins.order.ids.isEmpty, "a complete list did not prune a deleted Bot")
    }

    /// Pins are per team on this device: another team neither sees them nor
    /// can delete them, and going back restores them.
    private static func teamSwitchDoesNotDeleteOrShowAnotherTeamsPins() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var pins = PinnedBotsSession()
        pins.select(teamId: "team-a", canAdoptLegacy: true, defaults: defaults)
        precondition(pins.pin("bot-a", defaults: defaults))

        pins.select(teamId: "team-b", canAdoptLegacy: true, defaults: defaults)
        precondition(pins.order.ids.isEmpty, "team B saw team A's pins")
        _ = pins.prune(available: ["bot-b"], search: "", loadedQuery: "",
                       botsListIsEmpty: false, loadedTeamId: "team-b", currentTeamId: "team-b",
                       listIsComplete: true, defaults: defaults)
        precondition(PinnedBotsStorage.stored(teamId: "team-a", defaults: defaults).ids == ["bot-a"],
                     "team B's prune deleted team A's pins")

        pins.select(teamId: "team-a", canAdoptLegacy: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-a"], "team A's pin did not survive the switch")
        precondition(PinnedBotsStorage.stored(teamId: "team-b", defaults: defaults).ids.isEmpty,
                     "team B's pins leaked into team A")
    }

    /// The session's team and the page's team are separate inputs. The page
    /// can show one team while the session still holds another team's pins;
    /// that mix must never prune, however the ids line up.
    private static func sessionTeamMismatchDoesNotDeletePins() {
        let suite = "nuphos.pinnedBots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // The session holds team A's pins while the page already shows team B.
        var pins = PinnedBotsSession(teamId: "team-a", order: PinnedBotsOrder(["bot-a"]))
        PinnedBotsStorage.save(pins.order, teamId: "team-a", defaults: defaults)

        let mismatched = PinnedBotsPrunePolicy(
            search: "", loadedQuery: "", botsListIsEmpty: false,
            loadedTeamId: "team-b", currentTeamId: "team-b", pinsTeamId: "team-a",
            listIsComplete: true
        )
        precondition(!mismatched.allowsPruning,
                     "the list of one team was allowed to prune another team's pins")
        _ = pins.prune(available: ["bot-b"], search: "", loadedQuery: "",
                       botsListIsEmpty: false, loadedTeamId: "team-b", currentTeamId: "team-b",
                       listIsComplete: true, defaults: defaults)
        precondition(pins.order.ids == ["bot-a"], "a mismatched team's list deleted a pin")
        precondition(PinnedBotsStorage.stored(teamId: "team-a", defaults: defaults).ids == ["bot-a"],
                     "a mismatched team's list deleted the saved pin")

        // The same list with both team ids agreeing does prune.
        var agreeing = PinnedBotsSession(teamId: "team-b", order: PinnedBotsOrder(["bot-b-gone"]))
        _ = agreeing.prune(available: ["bot-b"], search: "", loadedQuery: "",
                           botsListIsEmpty: false, loadedTeamId: "team-b", currentTeamId: "team-b",
                           listIsComplete: true, defaults: defaults)
        precondition(agreeing.order.ids.isEmpty, "a matching complete list did not prune a deleted Bot")
    }

    private static func rowIsAbsentWhenNothingIsPinned() {
        let available = [bot("bot-a", "Ada"), bot("bot-b", "Bruce")]
        precondition(!PinnedBotsRowModel(order: PinnedBotsOrder(), available: available).isVisible)
        precondition(PinnedBotsRowModel(order: PinnedBotsOrder(), available: available).count == 0)
        // Saved ids that no longer resolve also leave no row.
        precondition(!PinnedBotsRowModel(order: PinnedBotsOrder(["bot-gone"]), available: available).isVisible)
    }

    /// A pin the loaded list cannot resolve must not be drawn. The row is built
    /// from what resolves, so an unresolved id would otherwise be an anonymous
    /// empty slot; the id itself stays saved, because the list may simply be
    /// incomplete. Pruning, not drawing, is what drops it.
    private static func anUnresolvedPinDrawsNoRowItem() {
        let available = [bot("bot-a", "Ada"), bot("bot-b", "Bruce")]
        let order = PinnedBotsOrder(["bot-a", "bot-gone", "bot-b"])
        let model = PinnedBotsRowModel(order: order, available: available)
        precondition(model.bots.map(\.id) == ["bot-a", "bot-b"],
                     "an unresolved pin was drawn: \(model.bots.map(\.id))")
        precondition(model.count == 2, "the count includes a pin that is not drawn")
        precondition(!model.bots.contains { $0.id == "bot-gone" }, "the unresolved pin has a row item")
        // The stored order is untouched: resolving the row never drops a pin.
        precondition(order.ids == ["bot-a", "bot-gone", "bot-b"],
                     "resolving the row dropped the stored pin")

        // A resolved Bot with no name would draw as an empty circle, so it is
        // not drawn either — and alone it leaves no row at all.
        let nameless = PinnedBot(id: "bot-blank", conversationId: "chat-blank", title: "  ")
        precondition(!PinnedBotsRowModel(order: PinnedBotsOrder(["bot-blank"]), available: [nameless]).isVisible,
                     "a nameless Bot was drawn as an empty circle")
    }


    private static func rowAccessibilityIsAContainerAtOneAndMany() {
        let available = [bot("bot-a", "Ada"), bot("bot-b", "Bruce")]
        let one = PinnedBotsRowModel(order: PinnedBotsOrder(["bot-a"]), available: available)
        let many = PinnedBotsRowModel(order: PinnedBotsOrder(["bot-a", "bot-b"]), available: available)
        let none = PinnedBotsRowModel(order: PinnedBotsOrder(), available: available)
        precondition(one.accessibility == .container(count: 1), "one pin lost its labelled container")
        precondition(many.accessibility == .container(count: 2), "many pins lost their labelled container")
        precondition(none.accessibility == .absent, "zero pins still expose a container")
        precondition(one.isVisible && many.isVisible && !none.isVisible)
    }

    private static func pinnedAvatarAccessibilityNamesTheBotOnce() {
        let selected = PinnedBotAccessibility(title: "Ada", isCurrent: true)
        precondition(selected.label == "Ada", "the pinned avatar's label is not the Bot name")
        precondition(selected.value == String(localized: "Selected"),
                     "the pinned avatar's value is not only the selected wording")
        precondition(!selected.value.contains("Ada"), "VoiceOver says the name twice: \"\(selected.label), \(selected.value)\"")
        precondition(selected.label.components(separatedBy: "Ada").count == 2,
                     "the label does not name the Bot exactly once")

        let idle = PinnedBotAccessibility(title: "Ada", isCurrent: false)
        precondition(idle.label == "Ada" && idle.value.isEmpty,
                     "an unselected pinned avatar reads a selected value")

        // The row must draw exactly these words, not rebuild them beside them.
        guard let row = try? String(contentsOfFile: "nuphos-ios/Views/Home/PinnedBotsRow.swift", encoding: .utf8) else {
            preconditionFailure("PinnedBotsRow.swift not readable from the test")
        }
        precondition(row.contains("PinnedBotAccessibility(title: bot.title, isCurrent: bot.id == currentBotId)"),
                     "the pinned row does not use the tested accessibility wording")
        precondition(row.contains(".accessibilityLabel(Text(verbatim: accessibility.label))"))
        precondition(row.contains(".accessibilityValue(Text(verbatim: accessibility.value))"))
        precondition(!row.contains("\\(bot.title), selected"),
                     "the pinned row still puts the name in the selected value")
    }

    private static func pinnedRowUsesALazyStack() {
        guard let row = try? String(contentsOfFile: "nuphos-ios/Views/Home/PinnedBotsRow.swift", encoding: .utf8) else {
            preconditionFailure("PinnedBotsRow.swift not readable from the test")
        }
        precondition(row.contains("LazyHStack(spacing: Metrics.spacing)"),
                     "the pinned avatars are not in a LazyHStack")
    }

    private static func barClearanceClearsTheListContent() {
        // The row's measured top on iPhone 18 Pro and iPad Pro 13-inch M5:
        // 121.66 + 55 = 176.66 and 91.5 + 55 = 146.5. The first Bots row
        // starts another 52 pt below that, so the row clears the bar and the
        // list's first content.
        let metrics = [(safeAreaTop: 121.66, measuredRowTop: 176.66),
                       (safeAreaTop: 91.5, measuredRowTop: 146.5)]
        for metric in metrics {
            let top = PinnedBotsLayout.rowTop(forSafeAreaTop: metric.safeAreaTop)
            precondition(abs(top - metric.measuredRowTop) < 0.5,
                         "the pinned row is not below the navigation bar at \(metric)")
            precondition(top >= metric.safeAreaTop,
                         "the pinned row starts above the safe area at \(metric)")
        }
    }

    private static func rowResolvesInPinOrder() {
        let available = [bot("bot-a", "Ada"), bot("bot-b", "Bruce"), bot("bot-c", "Cleo")]
        let model = PinnedBotsRowModel(order: PinnedBotsOrder(["bot-c", "bot-a"]), available: available)
        precondition(model.isVisible)
        precondition(model.count == 2)
        precondition(model.bots.map(\.id) == ["bot-c", "bot-a"], "the row does not follow pin order")
        precondition(model.bots.map(\.title) == ["Cleo", "Ada"])
    }

    private static func initialIsTheFirstWordOrFirstCharacter() {
        precondition(PinnedBot.initial(of: "ada lovelace") == "A")
        precondition(PinnedBot.initial(of: "Bruce Wayne") == "B")
        precondition(PinnedBot.initial(of: "维米尔") == "维")
        precondition(PinnedBot.initial(of: "  grace  hopper ") == "G")
        precondition(PinnedBot.initial(of: "") == "")
    }

    /// The pinned row's numbers come from Colo's spec: 44 pt face, a ring 2 pt
    /// clear of it (2.5 pt wide, so a 53 pt slot), 12 pt between two faces, and
    /// the first face's left edge on the list rows' 20 pt inset. The slot is
    /// wider than the face, so the HStack spacing and the row inset are not the
    /// spec's gap and inset directly — deriving them here keeps the two from
    /// drifting apart, which is how the row shipped at 17 pt and 2.5 pt off.
    private static func rowGeometryMatchesTheSpec() {
        let layout = PinnedBotsLayout.self
        precondition(layout.avatar == 44, "the face is not 44 pt")
        precondition(layout.ring == 2.5, "the ring is not 2.5 pt")
        precondition(layout.slot == layout.avatar + 2 * 2 + 2 * layout.ring, "the slot is not face + 2 pt gap + ring")
        precondition(layout.slot == 53, "the slot is not 53 pt")

        let faceGap = layout.spacing + (layout.slot - layout.avatar)
        precondition(faceGap == 12, "two faces are \(faceGap) pt apart, not 12")

        let firstLeftEdge = layout.inset + (layout.slot - layout.avatar) / 2
        precondition(firstLeftEdge == 20, "the first face starts at \(firstLeftEdge) pt, not 20")
        precondition(layout.inset == 15.5, "the row inset is not 15.5 pt")
    }

    private static func bot(_ id: String, _ title: String) -> PinnedBot {
        PinnedBot(id: id, conversationId: "chat-\(id)", title: title)
    }
}
