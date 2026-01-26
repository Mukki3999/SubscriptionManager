//
//  subscriptionManagerUITests.swift
//  subscriptionManagerUITests
//
//  Created by Karthik Khatri on 1/12/26.
//

import XCTest

/// Main UI test entry point - orchestrates UI test execution
/// Individual test files:
/// - GmailConnectionUITests.swift - Gmail OAuth connection flow
/// - ScanningUITests.swift - Subscription scanning UI
/// - PaywallUITests.swift - Paywall and subscription selection
/// - SubscriptionDetailUITests.swift - Subscription detail view
final class subscriptionManagerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Cleanup
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // App should launch without crashing
        XCTAssertTrue(app.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Basic Navigation Tests

    @MainActor
    func testHomeScreenElements() throws {
        let app = XCUIApplication()
        app.launch()

        // Basic home screen elements should exist
        // The exact elements depend on UI implementation
    }

    @MainActor
    func testTabBarNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // If using tab bar, verify navigation works
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            XCTAssertTrue(tabBar.buttons.count > 0)
        }
    }
}
