import XCTest

/// Offline integration request in an ordinary conversation, using only synthetic accounts.
final class IntegrationQuestionUITests: XCTestCase {
    func testQuestionOpensTheExistingCredentialPicker() throws {
        continueAfterFailure = false
        let fixture = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "tests/fixtures/push-responses.json")
        let live = FileManager.default.temporaryDirectory.appending(path: "integration-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: live) }
        var responses = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
        var conversation = try XCTUnwrap(responses["GET /agent/conversations/push-a"] as? [String: Any])
        var body = try XCTUnwrap(conversation["body"] as? [String: Any])
        body["credentialAccess"] = ["linearWorkspaceIds": []]
        body["messages"] = [["id": "integration", "role": "assistant", "parts": [[
            "type": "dynamic-tool", "toolCallId": "ask-trello", "toolName": "request_user_decision",
            "state": "output-available", "input": ["label": "Request a Linear connection", "category": "integration", "providers": ["linear"],
                "question": "Connect Linear for this conversation?"], "output": ["requestId": "ask-trello"]
        ]]]]
        conversation["body"] = body
        responses["GET /agent/conversations/push-a"] = conversation
        responses["GET /agent/conversations?kind=channel"] = ["status": 200, "body": ["conversations": []]]
        responses["GET /agent/credential-options"] = ["status": 200, "body": ["options": [
            "linearWorkspaces": [["workspaceId": "preview-linear", "label": "Preview Linear", "workspaceName": "preview"]]
        ]]]
        responses["PATCH /agent/conversations/push-a/credentials"] = ["status": 200, "body": [:]]
        try JSONSerialization.data(withJSONObject: responses).write(to: live)

        let app = XCUIApplication()
        app.launchArguments = ["-preview-home", "-preview-no-push", "-page", "agent", "-open-links",
            "https://nuphos.ai/teams/64b5f1c2e4b0a1d2c3e4f5a6/agent/push-a"]
        app.launchEnvironment = ["NUPHOS_PREVIEW_RESPONSES": live.path]
        app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Request a Linear connection")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.staticTexts["Connect Linear for this conversation?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["integration.openConnectors"].exists)
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "Integration question · fixture · light"
        detail.lifetime = .keepAlways
        add(detail)
        app.buttons["integration.chooseCredentials"].tap()
        XCTAssertTrue(app.staticTexts["Preview Linear"].waitForExistence(timeout: 5))
        app.staticTexts["Preview Linear"].tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["integration.chooseCredentials"].waitForExistence(timeout: 5))
        app.buttons["integration.openConnectors"].tap()
        let connectors = app.navigationBars["Connectors"]
        XCTAssertTrue(connectors.waitForExistence(timeout: 5), "The inherited ConnectorsStore must be available in the sheet")
        connectors.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["integration.chooseCredentials"].waitForExistence(timeout: 5))
    }
}
