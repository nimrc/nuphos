import Foundation

/// Jira, Trello, Asana and Plaud were removed upstream: their requests and
/// credentials must not lead to a Connectors page that cannot add them.
enum RetiredConnectorTests {
    static func run() {
        hidesTheCardForEveryRemovedConnector()
        keepsTheCardForLiveConnectors()
        neverListsRemovedConnectors()
        print("Retired connector tests passed")
    }

    /// What a request may name: the provider id, its display name, or the
    /// catalogue option / selection key an older record carried.
    private static let removedNames = [
        "jira", "trello", "asana", "plaud",
        "Jira", "Trello", "Asana", "Plaud",
        "jiraSites", "trelloIntegrations", "asanaAccounts", "plaudAccounts",
        "jiraSiteIds", "trelloIntegrationIds", "asanaAccountIds", "plaudAccountIds",
    ]

    private static func integrationRequest(_ providers: [String]) -> ChatPart.ToolPart {
        var part = ChatPart.ToolPart(
            toolCallId: "ask", toolName: "request_user_decision", isDynamic: false, state: .outputAvailable)
        part.input = .object([
            "category": .string("integration"),
            "question": .string("Connect it?"),
            "providers": .array(providers.map(JSONValue.string)),
        ])
        return part
    }

    private static func hidesTheCardForEveryRemovedConnector() {
        for name in removedNames {
            let part = integrationRequest([name])
            precondition(part.isProviderIntegrationRequest, "\(name) should still be an integration request")
            precondition(!part.showsProviderIntegrationRequest, "\(name) must not show a dead-end card")
        }
        // One removed connector in a mixed request hides the card too: its
        // Connectors page cannot add that one.
        precondition(!integrationRequest(["linear", "trello"]).showsProviderIntegrationRequest)
        // Without providers the card is unchanged, and a personal credential
        // request still has its own answers.
        var plain = ChatPart.ToolPart(
            toolCallId: "ask", toolName: "request_user_decision", isDynamic: false, state: .outputAvailable)
        plain.input = .object(["category": .string("integration"), "question": .string("Connect it?")])
        precondition(plain.showsProviderIntegrationRequest)
        var personal = plain
        personal.input = .object([
            "category": .string("integration"), "question": .string("Connect it?"),
            "credentials": .array([.object(["provider": .string("personal"), "id": .string("github")])]),
        ])
        precondition(!personal.showsProviderIntegrationRequest)
    }

    private static func keepsTheCardForLiveConnectors() {
        for name in ["linear", "Linear", "github", "sentry", "aws", "onprem-k8s"] {
            precondition(integrationRequest([name]).showsProviderIntegrationRequest, "\(name) is live")
        }
    }

    private static func neverListsRemovedConnectors() {
        let retiredOptions = JSONValue.parse(#"""
        {"jiraSites":[{"siteId":"j1","label":"Jira site","siteUrl":"https://jira.example"}],
         "trelloIntegrations":[{"integrationId":"t1","label":"Trello","username":"trello"}],
         "asanaAccounts":[{"accountId":"a1","label":"Asana","accountEmail":"a@example.com"}],
         "plaudAccounts":[{"bindingId":"p1","label":"Plaud"}]}
        """#)!
        precondition(CredentialCatalog(json: retiredOptions).isEmpty)

        let liveOptions = JSONValue.parse(#"""
        {"jiraSites":[{"siteId":"j1","label":"Jira site"}],
         "trelloIntegrations":[{"integrationId":"t1","label":"Trello"}],
         "asanaAccounts":[{"accountId":"a1","label":"Asana"}],
         "plaudAccounts":[{"bindingId":"p1","label":"Plaud"}],
         "linearWorkspaces":[{"workspaceId":"l1","label":"Linear"}],
         "githubInstallations":[{"installationId":"g1","accountLogin":"octocat"}]}
        """#)!
        let catalog = CredentialCatalog(json: liveOptions)
        precondition(catalog.allItems.map(\.provider.optionsKey) == ["linearWorkspaces", "githubInstallations"])
        precondition(catalog.allItems.map(\.id) == ["l1", "g1"])

        let removedOptions = Set(["jiraSites", "trelloIntegrations", "asanaAccounts", "plaudAccounts"])
        precondition(CredentialCatalog.providers.allSatisfy { !removedOptions.contains($0.optionsKey) })
        precondition(CredentialCatalog.providers.allSatisfy {
            !CredentialCatalog.retiredSelectionKeys.contains($0.selectionKey)
        })

        // A stored selection naming one of them is absent, not an unknown kind
        // to send back; the live kinds in the same object survive.
        let stored = CredentialSelection(json: JSONValue.parse(
            #"{"jiraSiteIds":["j"],"trelloIntegrationIds":["t"],"asanaAccountIds":["a"],"plaudAccountIds":["p"],"linearWorkspaceIds":["l1"]}"#)!)
        precondition(stored.ids["linearWorkspaceIds"] == ["l1"])
        precondition(stored.ids.keys.allSatisfy { !CredentialCatalog.retiredSelectionKeys.contains($0) })
        precondition((stored.json.objectValue ?? [:]).keys.allSatisfy {
            !CredentialCatalog.retiredSelectionKeys.contains($0)
        })

        var defaults = CredentialSelection()
        defaults.selectDefaults(in: catalog)
        precondition(defaults.ids["linearWorkspaceIds"] == ["l1"])
        precondition(defaults.ids["trelloIntegrationIds"] == nil)
        precondition((defaults.json.objectValue ?? [:])["trelloIntegrationIds"] == nil)
    }
}
