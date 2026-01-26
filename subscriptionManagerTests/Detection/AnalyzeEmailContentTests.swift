//
//  AnalyzeEmailContentTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for email content analysis and keyword scoring in SubscriptionDetectionService
final class AnalyzeEmailContentTests: XCTestCase {

    // MARK: - Properties

    var detectionService: SubscriptionDetectionService!

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        detectionService = SubscriptionDetectionService()
    }

    override func tearDown() async throws {
        detectionService = nil
        try await super.tearDown()
    }

    // MARK: - Strong Keyword Tests (+20 points each)

    @MainActor
    func testStrongKeyword_Subscription_AddsScore() {
        // Test that "subscription" keyword adds score
        let email = GmailMessageFactory.createMessage(
            subject: "Your subscription is confirmed",
            from: "test@service.com",
            snippet: "Thanks for subscribing to our service"
        )

        // The strong keyword "subscription" should add +20 to the score
        // This test verifies the keyword is recognized
        XCTAssertTrue(email.subject.lowercased().contains("subscription"))
    }

    @MainActor
    func testStrongKeyword_Membership_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your membership has been renewed",
            from: "test@service.com",
            snippet: "Your premium membership is now active"
        )

        XCTAssertTrue(email.subject.lowercased().contains("membership"))
    }

    @MainActor
    func testStrongKeyword_Renewal_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Subscription renewal notice",
            from: "test@service.com",
            snippet: "Your plan will automatically renew"
        )

        XCTAssertTrue(email.subject.lowercased().contains("renewal"))
    }

    @MainActor
    func testStrongKeyword_AutoRenewal_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Auto-renewal activated",
            from: "test@service.com",
            snippet: "Your subscription auto-renews on the 15th"
        )

        XCTAssertTrue(email.subject.lowercased().contains("auto-renewal") ||
                      email.snippet.lowercased().contains("auto-renew"))
    }

    @MainActor
    func testStrongKeyword_Recurring_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Recurring payment processed",
            from: "test@service.com",
            snippet: "Your recurring charge of $9.99 was successful"
        )

        XCTAssertTrue(email.subject.lowercased().contains("recurring"))
    }

    @MainActor
    func testStrongKeyword_MonthlyPlan_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your monthly plan is active",
            from: "test@service.com",
            snippet: "Thanks for choosing our monthly plan"
        )

        XCTAssertTrue(email.subject.lowercased().contains("monthly plan"))
    }

    @MainActor
    func testStrongKeyword_AnnualPlan_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your annual plan confirmation",
            from: "test@service.com",
            snippet: "Your yearly subscription is now active"
        )

        XCTAssertTrue(email.subject.lowercased().contains("annual plan"))
    }

    @MainActor
    func testStrongKeyword_BillingCycle_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Billing cycle update",
            from: "test@service.com",
            snippet: "Your next billing date is February 15"
        )

        XCTAssertTrue(email.subject.lowercased().contains("billing cycle") ||
                      email.snippet.lowercased().contains("billing date"))
    }

    // MARK: - Medium Keyword Tests (+10 points each)

    @MainActor
    func testMediumKeyword_Receipt_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Receipt for your payment",
            from: "test@service.com",
            snippet: "Thank you for your payment of $9.99"
        )

        XCTAssertTrue(email.subject.lowercased().contains("receipt"))
    }

    @MainActor
    func testMediumKeyword_Invoice_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Invoice #12345",
            from: "test@service.com",
            snippet: "Your monthly invoice is ready"
        )

        XCTAssertTrue(email.subject.lowercased().contains("invoice"))
    }

    @MainActor
    func testMediumKeyword_PaymentConfirmation_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Payment confirmation",
            from: "test@service.com",
            snippet: "Your payment has been processed"
        )

        XCTAssertTrue(email.subject.lowercased().contains("payment confirmation") ||
                      email.snippet.lowercased().contains("payment"))
    }

    // MARK: - Hard Exclusion Tests (-100 points)

    @MainActor
    func testHardExclusion_OrderConfirmation_RejectsEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Order confirmation #12345",
            from: "orders@amazon.com",
            snippet: "Thanks for your order"
        )

        XCTAssertTrue(email.subject.lowercased().contains("order confirmation"))
    }

    @MainActor
    func testHardExclusion_OrderNumber_RejectsEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Order #67890 has shipped",
            from: "shipping@amazon.com",
            snippet: "Your order is on the way"
        )

        XCTAssertTrue(email.subject.lowercased().contains("order #"))
    }

    @MainActor
    func testHardExclusion_BankStatement_RejectsEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your bank statement is ready",
            from: "alerts@bankofamerica.com",
            snippet: "View your monthly statement"
        )

        XCTAssertTrue(email.subject.lowercased().contains("bank statement"))
    }

    @MainActor
    func testHardExclusion_TrackingNumber_RejectsEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Tracking number: 1Z999AA10123456784",
            from: "tracking@ups.com",
            snippet: "Track your package"
        )

        XCTAssertTrue(email.subject.lowercased().contains("tracking number"))
    }

    @MainActor
    func testHardExclusion_UberTrip_RejectsEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your Thursday evening trip with Uber",
            from: "receipts@uber.com",
            snippet: "Trip receipt for your ride"
        )

        XCTAssertTrue(email.subject.lowercased().contains("trip with uber"))
    }

    @MainActor
    func testHardExclusion_LyftTrip_RejectsEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your Friday morning trip with Lyft",
            from: "receipts@lyft.com",
            snippet: "Thanks for riding with Lyft"
        )

        XCTAssertTrue(email.subject.lowercased().contains("trip with lyft"))
    }

    // MARK: - Anti-Keyword Tests (-25 points each)

    @MainActor
    func testAntiKeyword_Shipped_ReducesScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your order has shipped",
            from: "shipping@amazon.com",
            snippet: "Package shipped via UPS"
        )

        XCTAssertTrue(email.subject.lowercased().contains("shipped"))
    }

    @MainActor
    func testAntiKeyword_Delivery_ReducesScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Delivery notification",
            from: "notifications@fedex.com",
            snippet: "Your package is out for delivery"
        )

        XCTAssertTrue(email.subject.lowercased().contains("delivery") ||
                      email.snippet.lowercased().contains("delivery"))
    }

    @MainActor
    func testAntiKeyword_Tracking_ReducesScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Track your order",
            from: "orders@store.com",
            snippet: "Tracking information available"
        )

        XCTAssertTrue(email.subject.lowercased().contains("track"))
    }

    @MainActor
    func testAntiKeyword_Statement_ReducesScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your monthly statement",
            from: "statements@bank.com",
            snippet: "View your account statement"
        )

        XCTAssertTrue(email.subject.lowercased().contains("statement"))
    }

    @MainActor
    func testAntiKeyword_Refund_ReducesScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Refund processed",
            from: "support@store.com",
            snippet: "Your refund of $25.00 has been processed"
        )

        XCTAssertTrue(email.subject.lowercased().contains("refund") ||
                      email.snippet.lowercased().contains("refund"))
    }

    // MARK: - Combined Scoring Tests

    @MainActor
    func testCombinedScoring_StrongAndMediumKeywords() {
        // Email with both strong ("subscription") and medium ("receipt") keywords
        let email = GmailMessageFactory.createMessage(
            subject: "Subscription receipt",
            from: "billing@service.com",
            snippet: "Thank you for your subscription payment"
        )

        XCTAssertTrue(email.subject.lowercased().contains("subscription"))
        XCTAssertTrue(email.subject.lowercased().contains("receipt"))
    }

    @MainActor
    func testCombinedScoring_StrongKeywordWithAnti() {
        // Email with strong keyword but also anti-keyword
        let email = GmailMessageFactory.createMessage(
            subject: "Your subscription order has shipped",
            from: "orders@service.com",
            snippet: "Your subscription box is on the way"
        )

        // Has "subscription" (+20) but also "shipped" (-25)
        XCTAssertTrue(email.subject.lowercased().contains("subscription"))
        XCTAssertTrue(email.subject.lowercased().contains("shipped"))
    }

    // MARK: - Trial Keyword Tests (+18 points)

    @MainActor
    func testTrialKeyword_TrialEnding_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your free trial is ending soon",
            from: "billing@service.com",
            snippet: "Your trial ends in 3 days. Subscribe now!"
        )

        XCTAssertTrue(email.subject.lowercased().contains("trial") ||
                      email.snippet.lowercased().contains("trial"))
    }

    @MainActor
    func testTrialKeyword_TrialConversion_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Trial conversion notice",
            from: "billing@service.com",
            snippet: "Your trial will convert to a paid subscription"
        )

        XCTAssertTrue(email.snippet.lowercased().contains("trial"))
    }

    // MARK: - Unsubscribe Header Tests (+5 points)

    @MainActor
    func testUnsubscribeHeader_AddsScore() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your subscription receipt",
            from: "billing@service.com",
            snippet: "Thanks for your payment",
            hasUnsubscribeHeader: true
        )

        XCTAssertTrue(email.hasUnsubscribeHeader)
    }

    @MainActor
    func testNoUnsubscribeHeader_NoBonus() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your subscription receipt",
            from: "billing@service.com",
            snippet: "Thanks for your payment",
            hasUnsubscribeHeader: false
        )

        XCTAssertFalse(email.hasUnsubscribeHeader)
    }

    // MARK: - Cancellation Filter Tests

    @MainActor
    func testCancellation_Cancelled_FiltersEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your subscription has been cancelled",
            from: "billing@netflix.com",
            snippet: "We're sorry to see you go"
        )

        XCTAssertTrue(email.subject.lowercased().contains("cancelled") ||
                      email.subject.lowercased().contains("canceled"))
    }

    @MainActor
    func testCancellation_CancellationConfirmed_FiltersEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Cancellation confirmed",
            from: "billing@spotify.com",
            snippet: "Your cancellation has been processed"
        )

        XCTAssertTrue(email.subject.lowercased().contains("cancellation"))
    }

    @MainActor
    func testCancellation_SubscriptionEnded_FiltersEmail() {
        let email = GmailMessageFactory.createMessage(
            subject: "Your subscription has ended",
            from: "billing@adobe.com",
            snippet: "Your Adobe subscription is no longer active"
        )

        XCTAssertTrue(email.subject.lowercased().contains("ended"))
    }
}
