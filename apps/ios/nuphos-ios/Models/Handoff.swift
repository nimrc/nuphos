import Foundation

/// Work one Bot handed another, tracked until it is reported (`GET …/handoffs`).
struct Handoff: Decodable, Identifiable, Equatable, Sendable {
    enum Status: String, Decodable, Sendable { case open, blocked, done, cancelled }

    let id: String
    let fromSessionId: String
    let toSessionId: String
    let task: String
    let status: Status
    let report: String?
    let dueAt: Date?

    private enum CodingKeys: String, CodingKey { case id, fromSessionId, toSessionId, task, status, report, dueAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fromSessionId = try c.decode(String.self, forKey: .fromSessionId)
        toSessionId = try c.decode(String.self, forKey: .toSessionId)
        task = try c.decodeIfPresent(String.self, forKey: .task) ?? ""
        // A status this build doesn't know reads as still open.
        status = (try? c.decode(Status.self, forKey: .status)) ?? .open
        report = try? c.decodeIfPresent(String.self, forKey: .report)
        dueAt = (try? c.decodeIfPresent(String.self, forKey: .dueAt)).flatMap(Self.date)
    }

    /// Past its due time with no report yet.
    func overdue(at now: Date = .now) -> Bool {
        guard status == .open || status == .blocked, let dueAt else { return false }
        return dueAt < now
    }

    private static func date(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}
