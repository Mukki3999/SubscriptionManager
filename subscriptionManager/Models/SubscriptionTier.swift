//
//  SubscriptionTier.swift
//  subscriptionManager
//
//  Created by Claude on 1/19/26.
//

import Foundation

// MARK: - Subscription Tier

/// User subscription tier for the app
enum SubscriptionTier: String, Codable {
    case free
    case pro

    // MARK: - Feature Limits

    /// Maximum number of subscriptions allowed
    var maxSubscriptions: Int {
        switch self {
        case .free: return 3
        case .pro: return .max
        }
    }

    /// Whether user can customize notification reminder days
    var canCustomizeNotifications: Bool {
        self == .pro
    }

    /// Whether user can export subscriptions to CSV/PDF
    var canExport: Bool {
        self == .pro
    }

    /// Whether user can view insights (category breakdown, trends, projections)
    var canViewInsights: Bool {
        self == .pro
    }

    /// Whether user can use home screen widgets
    var canUseWidgets: Bool {
        self == .pro
    }

    /// Whether user can sync across devices via iCloud
    var canUseiCloudSync: Bool {
        self == .pro
    }

    /// Whether user can share with family members
    var canUseFamilySharing: Bool {
        self == .pro
    }

    /// Available notification reminder day options
    var availableReminderDays: [Int] {
        switch self {
        case .free: return [3] // Basic: only 3 days before
        case .pro: return [7, 3, 1] // Custom: 7, 3, or 1 day options
        }
    }
}

// MARK: - Product Identifiers

/// StoreKit product identifiers for premium subscriptions
enum PremiumProduct: String, CaseIterable {
    case monthly = "com.subscriptionmanager.pro.monthly"
    case annual = "com.subscriptionmanager.pro.annual"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        }
    }

    var price: Decimal {
        switch self {
        case .monthly: return 4.99
        case .annual: return 39.99
        }
    }

    var formattedPrice: String {
        switch self {
        case .monthly: return "$4.99/mo"
        case .annual: return "$39.99/yr"
        }
    }

    var savingsDescription: String? {
        switch self {
        case .monthly: return nil
        case .annual: return "Save 33%"
        }
    }

    var monthlyEquivalent: String {
        switch self {
        case .monthly: return "$4.99/mo"
        case .annual: return "$3.33/mo"
        }
    }
}

// MARK: - Tier Manager

/// Manages the current user's subscription tier
@MainActor
final class TierManager: ObservableObject {

    static let shared = TierManager()

    // MARK: - Published Properties

    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var hasUsedFreeScan: Bool = false

    // MARK: - Private Properties

    private let tierStorageKey = "userSubscriptionTier"
    private let freeScanUsedKey = "hasUsedFreeScan"

    // MARK: - Initialization

    private init() {
        loadTierStatus()
    }

    // MARK: - Public Methods

    /// Check if user can add more subscriptions
    func canAddSubscription(currentCount: Int) -> Bool {
        currentCount < currentTier.maxSubscriptions
    }

    /// Get number of remaining subscription slots for free tier
    func remainingSlots(currentCount: Int) -> Int {
        max(0, currentTier.maxSubscriptions - currentCount)
    }

    /// Check if user has reached their subscription limit
    func hasReachedLimit(currentCount: Int) -> Bool {
        currentCount >= currentTier.maxSubscriptions
    }

    /// Mark that user has used their free scan
    func markFreeScanUsed() {
        hasUsedFreeScan = true
        UserDefaults.standard.set(true, forKey: freeScanUsedKey)
    }

    /// Check if user can perform a rescan (Pro only after initial scan)
    func canRescan() -> Bool {
        if currentTier == .pro {
            return true
        }
        return !hasUsedFreeScan
    }

    /// Update user tier (called by PurchaseService)
    func updateTier(_ tier: SubscriptionTier) {
        currentTier = tier
        saveTierStatus()
    }

    // MARK: - Private Methods

    private func loadTierStatus() {
        // Load tier from UserDefaults (will be overridden by PurchaseService on launch)
        if let tierString = UserDefaults.standard.string(forKey: tierStorageKey),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
        }

        hasUsedFreeScan = UserDefaults.standard.bool(forKey: freeScanUsedKey)
    }

    private func saveTierStatus() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: tierStorageKey)
    }
}
