import Foundation

enum HandoffTests {
    static func run() {
        decodesAHandoffAndKnowsWhenItIsLate()
        print("Handoffs passed")
    }

    private static func decodesAHandoffAndKnowsWhenItIsLate() {
        let json = """
        {"handoffs":[
         {"id":"h1","fromSessionId":"lead","toSessionId":"writer","task":"Draft","status":"open","dueAt":"2026-11-14T10:00:00.000Z","nudges":0},
         {"id":"h2","fromSessionId":"lead","toSessionId":"tester","task":"Test","status":"later","report":"x"}
        ]}
        """
        struct Envelope: Decodable { let handoffs: [Handoff] }
        let rows = try! JSONDecoder().decode(Envelope.self, from: Data(json.utf8)).handoffs
        precondition(rows.count == 2)
        precondition(rows[0].dueAt == ISO8601DateFormatter().date(from: "2026-11-14T10:00:00Z"))
        precondition(rows[0].overdue(at: ISO8601DateFormatter().date(from: "2026-11-14T11:00:00Z")!))
        precondition(!rows[0].overdue(at: ISO8601DateFormatter().date(from: "2026-11-14T09:00:00Z")!))
        precondition(rows[1].status == .open && rows[1].dueAt == nil && !rows[1].overdue())
    }
}
