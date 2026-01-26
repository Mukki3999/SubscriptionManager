//
//  subscriptionManagerTests.swift
//  subscriptionManagerTests
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation
import Testing
@testable import subscriptionManager

/// Main test entry point - Individual test files are organized by functionality:
///
/// ## Detection Tests (subscriptionManagerTests/Detection/)
/// - AnalyzeEmailContentTests.swift - Keyword scoring tests
/// - AnalyzeRecurringPatternTests.swift - Billing cycle detection
/// - ExtractPriceTests.swift - Price extraction patterns
/// - ExtractMerchantTests.swift - Merchant name extraction
/// - BlockedDomainTests.swift - False positive prevention
/// - ConfidenceThresholdTests.swift - Scoring boundaries
///
/// ## OAuth Tests (subscriptionManagerTests/OAuth/)
/// - PKCEHelperTests.swift - PKCE implementation
/// - GoogleOAuthServiceTests.swift - OAuth flow tests
///
/// ## Purchase Tests (subscriptionManagerTests/Purchases/)
/// - PurchaseServiceTests.swift - StoreKit integration
///
/// ## Integration Tests (subscriptionManagerTests/Integration/)
/// - RateLimiterTests.swift - Rate limiting infrastructure
/// - GmailAPIIntegrationTests.swift - API behavior tests
///
/// ## Test Helpers (subscriptionManagerTests/TestHelpers/)
/// - TestHelpers.swift - Date/async utilities
/// - GmailMessageFactory.swift - Test message creation
/// - MockURLProtocol.swift - Network mocking
///
/// ## Mocks (subscriptionManagerTests/Mocks/)
/// - MockGmailAPIService.swift - Gmail API mock
/// - MockKeychainService.swift - Keychain mock
struct subscriptionManagerTests {

    @Test func verifyTestInfrastructure() async throws {
        // Verify basic test infrastructure is working
        #expect(true)
    }

    @Test func verifyDateHelpers() async throws {
        // Test date helpers
        let past = Date.daysFromNow(-7)
        let future = Date.daysFromNow(7)

        #expect(past < Date())
        #expect(future > Date())
    }

    @Test func verifyGmailMessageFactory() async throws {
        // Test message factory creates valid messages
        let message = GmailMessageFactory.netflixSubscription()

        #expect(message.subject.contains("Netflix"))
        #expect(message.from.contains("netflix"))
    }

    @Test func verifyMockServices() async throws {
        // Test mock services initialize correctly
        let mockGmail = MockGmailAPIService()
        let mockKeychain = MockKeychainService()

        #expect(mockGmail.messagesToReturn.isEmpty)
        #expect(mockKeychain.hasValidGoogleTokens)
    }
}
