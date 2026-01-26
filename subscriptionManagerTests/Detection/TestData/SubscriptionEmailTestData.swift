//
//  SubscriptionEmailTestData.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Test data for subscription email detection tests
enum SubscriptionEmailTestData {

    // MARK: - Strong Subscription Keywords

    static let strongKeywordSubjects = [
        "Your subscription is confirmed",
        "Your membership has been renewed",
        "Subscription renewal notice",
        "Your auto-renewal is active",
        "Recurring payment processed",
        "Your monthly plan is now active",
        "Annual plan confirmation",
        "Billing cycle update",
        "Thanks for subscribing",
        "Manage your subscription"
    ]

    // MARK: - Medium Subscription Keywords

    static let mediumKeywordSubjects = [
        "Receipt for your payment",
        "Invoice #12345",
        "Payment confirmation",
        "Your payment was successful",
        "Successfully charged"
    ]

    // MARK: - Anti-Keywords (Should Reject)

    static let antiKeywordSubjects = [
        "Your package has shipped",
        "Shipping confirmation",
        "Delivery notification",
        "Track your order",
        "Your order has shipped",
        "Bank statement ready",
        "Your statement is available",
        "Direct deposit received",
        "Transaction alert",
        "Your ride receipt",
        "Trip with Uber"
    ]

    // MARK: - Hard Exclusion Keywords (Should Reject Immediately)

    static let hardExclusionSubjects = [
        "Order confirmation #12345",
        "Order #67890 confirmed",
        "Your order has shipped",
        "Bank statement for December",
        "Account statement ready",
        "Insurance policy renewal",
        "Tracking number: 1Z999AA1",
        "Track your package",
        "Your Thursday evening trip with Uber",
        "Your Friday morning trip with Lyft"
    ]

    // MARK: - Cancellation Keywords (Should Filter Out)

    static let cancellationSubjects = [
        "Your subscription has been cancelled",
        "Cancellation confirmed",
        "Membership cancelled",
        "Successfully cancelled your subscription",
        "Your Netflix subscription has ended",
        "Final payment processed",
        "Service terminated"
    ]

    // MARK: - Price Patterns

    static let validPriceSnippets = [
        "$9.99/mo billed monthly",
        "$9.99/month subscription",
        "$99.99/yr annual plan",
        "$9.99 per month",
        "$99.99 per year",
        "EUR 9,99/mo",
        "billed monthly at $10.99"
    ]

    static let extractablePrices: [(snippet: String, expectedPrice: Double)] = [
        ("Amount: $9.99", 9.99),
        ("Charged $15.99/mo", 15.99),
        ("Your plan costs $10.99 per month", 10.99),
        ("$99.99/year subscription", 99.99),
        ("USD 19.99 charged", 19.99),
        ("€9,99 monthly", 9.99)
    ]

    // MARK: - Payment Processor Patterns

    static let paypalMerchantPatterns: [(snippet: String, expectedMerchant: String)] = [
        ("Payment to Spotify on January 15", "Spotify"),
        ("automatic payment to Notion Labs", "Notion Labs"),
        ("You sent $9.99 to Figma Inc", "Figma Inc")
    ]

    static let stripeMerchantPatterns: [(snippet: String, expectedMerchant: String)] = [
        ("Receipt from Figma", "Figma"),
        ("Statement descriptor: FIGMA INC", "FIGMA INC"),
        ("Merchant: Notion Labs", "Notion Labs")
    ]

    // MARK: - Blocked Domains

    static let blockedBankDomains = [
        "bankofamerica.com",
        "chase.com",
        "wellsfargo.com",
        "citi.com",
        "capitalone.com",
        "schwab.com",
        "fidelity.com"
    ]

    static let blockedPersonalEmailDomains = [
        "gmail.com",
        "yahoo.com",
        "outlook.com",
        "hotmail.com",
        "icloud.com"
    ]

    static let blockedShippingDomains = [
        "ups.com",
        "fedex.com",
        "usps.com",
        "dhl.com"
    ]

    static let hardExcludedDomains = [
        "venmo.com",
        "zelle.com",
        "cashapp.com",
        "klarna.com"
    ]

    // MARK: - Known Subscription Services

    static let knownSubscriptionServices: [(name: String, domain: String, typicalPrice: Double)] = [
        ("Netflix", "netflix.com", 15.99),
        ("Spotify", "spotify.com", 10.99),
        ("Apple Music", "apple.com", 10.99),
        ("Disney+", "disneyplus.com", 7.99),
        ("HBO Max", "hbomax.com", 15.99),
        ("Amazon Prime", "amazon.com", 14.99),
        ("YouTube Premium", "youtube.com", 11.99),
        ("Adobe Creative Cloud", "adobe.com", 54.99),
        ("Microsoft 365", "microsoft.com", 9.99),
        ("Dropbox", "dropbox.com", 11.99)
    ]

    // MARK: - Billing Cycle Test Data

    /// Email dates for monthly billing pattern (30-day intervals)
    static func monthlyBillingDates(count: Int = 6) -> [Date] {
        (0..<count).map { index in
            Calendar.current.date(byAdding: .day, value: -30 * index, to: Date())!
        }.reversed()
    }

    /// Email dates for weekly billing pattern (7-day intervals)
    static func weeklyBillingDates(count: Int = 8) -> [Date] {
        (0..<count).map { index in
            Calendar.current.date(byAdding: .day, value: -7 * index, to: Date())!
        }.reversed()
    }

    /// Email dates for quarterly billing pattern (90-day intervals)
    static func quarterlyBillingDates(count: Int = 4) -> [Date] {
        (0..<count).map { index in
            Calendar.current.date(byAdding: .day, value: -90 * index, to: Date())!
        }.reversed()
    }

    /// Email dates for yearly billing pattern (365-day intervals)
    static func yearlyBillingDates(count: Int = 2) -> [Date] {
        (0..<count).map { index in
            Calendar.current.date(byAdding: .day, value: -365 * index, to: Date())!
        }.reversed()
    }

    // MARK: - Confidence Score Test Cases

    struct ConfidenceTestCase {
        let name: String
        let subject: String
        let snippet: String
        let domain: String
        let emailCount: Int
        let expectedMinScore: Int
        let expectedMaxScore: Int
        let expectedConfidence: String // "high", "medium", "low"

        init(
            name: String,
            subject: String,
            snippet: String,
            domain: String,
            emailCount: Int = 1,
            expectedMinScore: Int,
            expectedMaxScore: Int = 200,
            expectedConfidence: String
        ) {
            self.name = name
            self.subject = subject
            self.snippet = snippet
            self.domain = domain
            self.emailCount = emailCount
            self.expectedMinScore = expectedMinScore
            self.expectedMaxScore = expectedMaxScore
            self.expectedConfidence = expectedConfidence
        }
    }

    static let confidenceTestCases: [ConfidenceTestCase] = [
        // High confidence cases (score >= 70)
        ConfidenceTestCase(
            name: "Netflix with subscription keyword",
            subject: "Your Netflix subscription has renewed",
            snippet: "Your monthly subscription of $15.99/mo has been renewed",
            domain: "netflix.com",
            emailCount: 3,
            expectedMinScore: 70,
            expectedConfidence: "high"
        ),
        ConfidenceTestCase(
            name: "Spotify receipt with price",
            subject: "Your Spotify Premium receipt",
            snippet: "Thanks for your payment of $10.99/month",
            domain: "spotify.com",
            emailCount: 4,
            expectedMinScore: 70,
            expectedConfidence: "high"
        ),
        ConfidenceTestCase(
            name: "Adobe subscription",
            subject: "Your Adobe Creative Cloud subscription",
            snippet: "Monthly subscription renewal - $54.99/mo",
            domain: "adobe.com",
            emailCount: 6,
            expectedMinScore: 70,
            expectedConfidence: "high"
        ),

        // Medium confidence cases (50 <= score < 70)
        ConfidenceTestCase(
            name: "Unknown service with keywords",
            subject: "Your subscription receipt",
            snippet: "Payment of $9.99 processed",
            domain: "unknownservice.com",
            emailCount: 2,
            expectedMinScore: 50,
            expectedMaxScore: 69,
            expectedConfidence: "medium"
        ),
        ConfidenceTestCase(
            name: "PayPal with extracted merchant",
            subject: "Receipt for payment",
            snippet: "Payment to SomeService Inc - $12.99",
            domain: "paypal.com",
            emailCount: 1,
            expectedMinScore: 50,
            expectedMaxScore: 69,
            expectedConfidence: "medium"
        ),

        // Low confidence / rejection cases (score < 50)
        ConfidenceTestCase(
            name: "Bank statement",
            subject: "Your bank statement is ready",
            snippet: "View your monthly statement",
            domain: "bankofamerica.com",
            expectedMinScore: 0,
            expectedMaxScore: 0,
            expectedConfidence: "rejected"
        ),
        ConfidenceTestCase(
            name: "Shipping notification",
            subject: "Your package has shipped",
            snippet: "Track your delivery",
            domain: "amazon.com",
            expectedMinScore: 0,
            expectedMaxScore: 49,
            expectedConfidence: "low"
        )
    ]
}
