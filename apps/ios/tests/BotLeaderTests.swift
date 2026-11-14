import Foundation

enum BotLeaderTests {
    static func run() {
        aListRowAndAProfileReadTheLeader()
        print("Bot leader passed")
    }

    private static func aListRowAndAProfileReadTheLeader() {
        let decoder = JSONDecoder()
        let row = try! decoder.decode(AgentConversation.self, from: Data(
            #"{"sessionId":"lead","title":"Lead","avatar":"07-ada","isOwner":true,"leader":true}"#.utf8))
        precondition(row.leader == true && row.isBot)
        let plain = try! decoder.decode(AgentConversation.self, from: Data(#"{"sessionId":"bot","avatar":"07-ada"}"#.utf8))
        precondition(plain.leader == nil)

        let profile = try! decoder.decode(BotProfile.self, from: Data(
            #"{"title":"Lead","instructions":"","isOwner":true,"leader":true}"#.utf8))
        precondition(profile.leader && profile.editable)
        // A backend that predates Leaders sends no flag.
        let older = try! decoder.decode(BotProfile.self, from: Data(#"{"title":"Bot","isOwner":true}"#.utf8))
        precondition(!older.leader)
    }
}
