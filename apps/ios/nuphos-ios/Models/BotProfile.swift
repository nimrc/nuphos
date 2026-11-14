import Foundation

/// What a Bot's profile shows: its name, face and personality (standing instructions).
struct BotProfile: Decodable, Equatable {
    let title: String
    let avatar: String?
    let instructions: String
    /// Only the owner edits a Bot; anyone else who can open it reads it.
    let editable: Bool
    /// Leads its owner's other Bots: hands them work and manages them.
    var leader: Bool

    private enum CodingKeys: String, CodingKey { case title, avatar, instructions, isOwner, readOnly, leader }

    init(title: String, avatar: String?, instructions: String, editable: Bool, leader: Bool = false) {
        self.title = title
        self.avatar = avatar
        self.instructions = instructions
        self.editable = editable
        self.leader = leader
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        avatar = try? c.decodeIfPresent(String.self, forKey: .avatar)
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        let owner = (try? c.decodeIfPresent(Bool.self, forKey: .isOwner)) ?? false
        let readOnly = (try? c.decodeIfPresent(Bool.self, forKey: .readOnly)) ?? false
        editable = owner && !readOnly
        leader = (try? c.decodeIfPresent(Bool.self, forKey: .leader)) ?? false
    }
}
