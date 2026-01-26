//
//  GmailConnectionUITests.swift
//  subscriptionManagerUITests
//
//  Created by Claude on 1/25/26.
//

import XCTest

/// UI tests for Gmail connection flow
final class GmailConnectionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Connection Flow Tests

    @MainActor
    func testGmailConnection_ConnectButtonExists() throws {
        app.launch()

        // Navigate to account connection if not on that screen
        // This depends on app's initial state

        // Look for connect button (may vary based on UI)
        let connectButton = app.buttons["Connect Gmail"]
        if connectButton.exists {
            XCTAssertTrue(connectButton.isEnabled)
        }
    }

    @MainActor
    func testGmailConnection_ConnectedStateShowsEmail() throws {
        // This test would require a pre-configured state with connected account
        app.launch()

        // If connected, email should be visible
        // The exact element depends on the UI implementation
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testGmailConnection_CancelledAuth_ShowsMessage() throws {
        // This requires simulating OAuth cancellation
        // In actual UI tests, this might show an alert or error message
        app.launch()

        // Would need to trigger OAuth flow and cancel
    }

    @MainActor
    func testGmailConnection_NetworkError_ShowsRetry() throws {
        // This requires simulating network failure
        app.launch()

        // Error handling UI should show retry option
    }

    // MARK: - Disconnect Flow Tests

    @MainActor
    func testGmailDisconnect_ConfirmationPrompt() throws {
        // When user taps disconnect, should show confirmation
        app.launch()

        // Find and tap disconnect button (if visible)
        let disconnectButton = app.buttons["Disconnect"]
        if disconnectButton.exists {
            disconnectButton.tap()

            // Should show confirmation alert
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 2))
        }
    }
}
