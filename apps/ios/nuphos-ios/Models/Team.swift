import Foundation

/// `GET /teams` row (`AtlasTeam` on the desktop). Only what the app reads.
struct Team: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let avatarUrl: String?
    let isOwner: Bool?
    /// The caller's membership role (`ADMINISTRATOR` / `EDITOR` / `VIEWER`).
    let role: String?
    /// What this server and team can do. Absent from older backends, which
    /// means nothing is advertised: voice input stays hidden.
    let capabilities: Capabilities?

    struct Capabilities: Codable, Equatable, Hashable, Sendable {
        /// The deployment has a transcription key and this team may use it.
        let voiceInput: Bool?

        init(voiceInput: Bool? = nil) {
            self.voiceInput = voiceInput
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            voiceInput = try c.decodeIfPresent(Bool.self, forKey: .voiceInput)
        }
    }

    var voiceInputAvailable: Bool { capabilities?.voiceInput == true }

    var isAdministrator: Bool { role == "ADMINISTRATOR" || isOwner == true }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        capabilities = try c.decodeIfPresent(Capabilities.self, forKey: .capabilities)
    }

    init(id: String, name: String, avatarUrl: String? = nil, isOwner: Bool? = nil, role: String? = nil,
         capabilities: Capabilities? = nil) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.isOwner = isOwner
        self.role = role
        self.capabilities = capabilities
    }

    static let preview = Team(id: "64b5f1c2e4b0a1d2c3e4f5a6", name: "Zeabur", isOwner: true)
}
