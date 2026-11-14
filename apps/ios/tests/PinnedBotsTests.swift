import Foundation

@main
enum PinnedBotsTests {
    static func main() {
        pinOrderIsTheOrderTheyWerePinned()
        pinningTwiceDoesNotDuplicate()
        unpinningRemovesAndKeepsOrder()
        storageSurvivesRelaunch()
        loadDropsDuplicatesAndEmptyIds()
        pruneDropsBotsThatNoLongerExist()
        rowIsAbsentWhenNothingIsPinned()
        rowResolvesInPinOrder()
        initialIsTheFirstWordOrFirstCharacter()
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
        PinnedBotsStorage.save(pins, defaults: defaults)
        let reloaded = PinnedBotsStorage.load(defaults: defaults)
        precondition(reloaded == pins, "the pin order did not survive a reload")
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

    private static func rowIsAbsentWhenNothingIsPinned() {
        let available = [bot("bot-a", "Ada"), bot("bot-b", "Bruce")]
        precondition(!PinnedBotsRowModel(order: PinnedBotsOrder(), available: available).isVisible)
        precondition(PinnedBotsRowModel(order: PinnedBotsOrder(), available: available).count == 0)
        // Saved ids that no longer resolve also leave no row.
        precondition(!PinnedBotsRowModel(order: PinnedBotsOrder(["bot-gone"]), available: available).isVisible)
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

    private static func bot(_ id: String, _ title: String) -> PinnedBot {
        PinnedBot(id: id, conversationId: "chat-\(id)", title: title)
    }
}
