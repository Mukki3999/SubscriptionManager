//
//  Subscription.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import Foundation
import SwiftUI

// MARK: - Detection Source

enum DetectionSource: String, Codable {
    case gmail = "Gmail"
    case appStore = "App Store"
    case manual = "Manual"
}

// MARK: - Billing Cycle

enum BillingCycle: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    case unknown = "Unknown"

    var shortLabel: String {
        switch self {
        case .weekly: return "/wk"
        case .monthly: return "/mo"
        case .quarterly: return "/qtr"
        case .yearly: return "/yr"
        case .unknown: return ""
        }
    }

    /// Approximate days between charges
    var approximateDays: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        case .yearly: return 365
        case .unknown: return 0
        }
    }
}

// MARK: - Confidence Level

enum SubscriptionConfidence: String, Codable {
    case high = "Likely"
    case medium = "Maybe"
    case low = "Unlikely"

    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .gray
        }
    }

    var score: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

// MARK: - Subscription Model

struct Subscription: Identifiable, Codable, Equatable {
    let id: UUID
    var merchantId: String
    var name: String
    var price: Double
    var billingCycle: BillingCycle
    var confidence: SubscriptionConfidence
    var nextBillingDate: Date?
    var lastChargeDate: Date?
    var emailCount: Int
    var senderEmail: String
    var detectedAt: Date
    var detectionSource: DetectionSource
    var productId: String?

    // Non-persisted UI state
    var isSelected: Bool = true

    init(
        id: UUID = UUID(),
        merchantId: String,
        name: String,
        price: Double,
        billingCycle: BillingCycle = .monthly,
        confidence: SubscriptionConfidence = .medium,
        nextBillingDate: Date? = nil,
        lastChargeDate: Date? = nil,
        emailCount: Int = 1,
        senderEmail: String,
        detectedAt: Date = Date(),
        detectionSource: DetectionSource = .gmail,
        productId: String? = nil
    ) {
        self.id = id
        self.merchantId = merchantId
        self.name = name
        self.price = price
        self.billingCycle = billingCycle
        self.confidence = confidence
        self.nextBillingDate = nextBillingDate
        self.lastChargeDate = lastChargeDate
        self.emailCount = emailCount
        self.senderEmail = senderEmail
        self.detectedAt = detectedAt
        self.detectionSource = detectionSource
        self.productId = productId
    }

    // Custom coding to exclude isSelected
    enum CodingKeys: String, CodingKey {
        case id, merchantId, name, price, billingCycle, confidence
        case nextBillingDate, lastChargeDate, emailCount, senderEmail, detectedAt
        case detectionSource, productId
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    var priceWithCycle: String {
        "\(formattedPrice)\(billingCycle.shortLabel)"
    }

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Detection Result

struct DetectionResult {
    let subscriptions: [Subscription]
    let emailsScanned: Int
    let scanDuration: TimeInterval

    var highConfidenceCount: Int {
        subscriptions.filter { $0.confidence == .high }.count
    }

    var mediumConfidenceCount: Int {
        subscriptions.filter { $0.confidence == .medium }.count
    }
}

// MARK: - Scan Progress

struct ScanProgress {
    var phase: ScanPhase
    var emailsScanned: Int
    var candidatesFound: Int
    var currentMerchant: String?

    // StoreKit scanning progress
    var storeKitPhase: StoreKitScanPhase
    var transactionsScanned: Int
    var storeKitCandidatesFound: Int

    enum ScanPhase: String {
        case starting = "Starting scan..."
        case fetchingMetadata = "Scanning emails..."
        case analyzingCandidates = "Analyzing subscriptions..."
        case complete = "Complete!"
    }

    enum StoreKitScanPhase: String {
        case notStarted = "Not started"
        case fetchingTransactions = "Fetching transactions..."
        case analyzing = "Analyzing purchases..."
        case complete = "Complete!"
        case unavailable = "Not available"
    }

    static var initial: ScanProgress {
        ScanProgress(
            phase: .starting,
            emailsScanned: 0,
            candidatesFound: 0,
            storeKitPhase: .notStarted,
            transactionsScanned: 0,
            storeKitCandidatesFound: 0
        )
    }
}
