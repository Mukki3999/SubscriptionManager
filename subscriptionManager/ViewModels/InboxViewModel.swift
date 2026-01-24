//
//  InboxViewModel.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import Foundation
import SwiftUI

/// View state for the inbox/scan flow
enum InboxViewState: Equatable {
    case idle
    case scanning
    case review
    case complete

    static func == (lhs: InboxViewState, rhs: InboxViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning), (.review, .review), (.complete, .complete):
            return true
        default:
            return false
        }
    }
}

/// ViewModel for subscription scanning and review flow
@MainActor
final class InboxViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var viewState: InboxViewState = .idle
    @Published var subscriptions: [Subscription] = []
    @Published var scanProgress: ScanProgress = .initial
    @Published var errorMessage: String?
    @Published var scanDuration: TimeInterval = 0
    @Published var emailsScanned: Int = 0
    @Published var transactionsScanned: Int = 0

    // MARK: - Internal State

    private var gmailSubscriptions: [Subscription] = []
    private var storeKitSubscriptions: [Subscription] = []

    // MARK: - Services

    private let detectionService = SubscriptionDetectionService()
    private let googleOAuthService = GoogleOAuthService()
    private let storeKitService = StoreKitService()
    private let merchantDB = MerchantDatabase.shared

    // MARK: - Storage

    private let subscriptionsKey = "confirmedSubscriptions"

    // MARK: - Computed Properties

    var selectedSubscriptions: [Subscription] {
        subscriptions.filter { $0.isSelected }
    }

    var highConfidenceSubscriptions: [Subscription] {
        subscriptions.filter { $0.confidence == .high }
    }

    var mediumConfidenceSubscriptions: [Subscription] {
        subscriptions.filter { $0.confidence == .medium || $0.confidence == .low }
    }

    var totalMonthlyEstimate: Double {
        selectedSubscriptions.reduce(0) { total, sub in
            switch sub.billingCycle {
            case .weekly:
                return total + (sub.price * 4)
            case .monthly:
                return total + sub.price
            case .quarterly:
                return total + (sub.price / 3)
            case .yearly:
                return total + (sub.price / 12)
            case .unknown:
                return total + sub.price
            }
        }
    }

    var gmailSubscriptionCount: Int {
        subscriptions.filter { $0.detectionSource == .gmail }.count
    }

    var appStoreSubscriptionCount: Int {
        subscriptions.filter { $0.detectionSource == .appStore }.count
    }

    // MARK: - Public Methods

    /// Start manual review flow (skip scanning)
    func startManualEntry() {
        errorMessage = nil
        subscriptions = []
        scanProgress = .initial
        viewState = .review
    }

    /// Start scanning for subscriptions from all connected sources in parallel
    /// - Parameter hasStoreKitAccess: Whether StoreKit transaction access is available
    /// - Parameter hasGmailAccount: Whether a Gmail account is connected
    func startScan(hasGmailAccount: Bool = true, hasStoreKitAccess: Bool = false) async {
        viewState = .scanning
        errorMessage = nil
        gmailSubscriptions = []
        storeKitSubscriptions = []

        let startTime = Date()

        // Initialize progress
        scanProgress = ScanProgress(
            phase: .starting,
            emailsScanned: 0,
            candidatesFound: 0,
            storeKitPhase: hasStoreKitAccess ? .notStarted : .unavailable,
            transactionsScanned: 0,
            storeKitCandidatesFound: 0
        )

        // Run Gmail and StoreKit scans in parallel using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            // Gmail scan task
            if hasGmailAccount {
                group.addTask { @MainActor in
                    await self.scanGmail()
                }
            }

            // StoreKit scan task
            if hasStoreKitAccess {
                group.addTask { @MainActor in
                    await self.scanStoreKit()
                }
            }
        }

        // Merge and deduplicate results from both sources
        subscriptions = mergeAndDeduplicateResults()

        // Update final stats
        scanDuration = Date().timeIntervalSince(startTime)
        emailsScanned = scanProgress.emailsScanned
        transactionsScanned = scanProgress.transactionsScanned

        // Update progress to complete
        scanProgress.phase = .complete
        if hasStoreKitAccess {
            scanProgress.storeKitPhase = .complete
        }

        // Move to review if we have any results or completed scan
        viewState = .review
    }

    /// Scan Gmail for subscriptions
    private func scanGmail() async {
        do {
            // Update progress
            scanProgress.phase = .fetchingMetadata

            // Get valid access token
            let accessToken = try await googleOAuthService.getValidAccessToken()

            // Perform scan
            let result = try await detectionService.scanForSubscriptions(accessToken: accessToken)

            // Store Gmail results
            gmailSubscriptions = result.subscriptions

            // Update progress
            scanProgress.emailsScanned = result.emailsScanned
            scanProgress.candidatesFound = result.subscriptions.count
            scanProgress.phase = .complete

        } catch {
            handleError(error)
            scanProgress.phase = .complete
        }
    }

    /// Scan StoreKit for App Store subscriptions
    private func scanStoreKit() async {
        do {
            // Update progress
            scanProgress.storeKitPhase = .fetchingTransactions

            // Fetch subscriptions from StoreKit
            let storeKitSubs = try await storeKitService.fetchSubscriptions()

            // Update progress
            scanProgress.storeKitPhase = .analyzing

            // Store StoreKit results
            storeKitSubscriptions = storeKitSubs

            // Update progress
            scanProgress.transactionsScanned = storeKitSubs.count
            scanProgress.storeKitCandidatesFound = storeKitSubs.count
            scanProgress.storeKitPhase = .complete

        } catch {
            print("StoreKit scan error: \(error)")
            scanProgress.storeKitPhase = .complete
        }
    }

    /// Merge and deduplicate results from Gmail and StoreKit
    /// Prefers StoreKit results when duplicates are found (higher accuracy)
    private func mergeAndDeduplicateResults() -> [Subscription] {
        var merged: [Subscription] = []
        var usedNames: Set<String> = []

        // Add StoreKit subscriptions first (higher accuracy)
        for sub in storeKitSubscriptions {
            let normalizedName = normalizeNameForMatching(sub.name)
            merged.append(sub)
            usedNames.insert(normalizedName)
        }

        // Add Gmail subscriptions, avoiding duplicates
        for sub in gmailSubscriptions {
            let normalizedName = normalizeNameForMatching(sub.name)

            // Check for fuzzy match with existing StoreKit subscriptions
            let isDuplicate = usedNames.contains { existingName in
                fuzzyMatch(normalizedName, existingName)
            }

            if !isDuplicate {
                merged.append(sub)
                usedNames.insert(normalizedName)
            }
        }

        // Sort by confidence (high first), then by name
        return merged.sorted { lhs, rhs in
            if lhs.confidence.score != rhs.confidence.score {
                return lhs.confidence.score > rhs.confidence.score
            }
            return lhs.name.lowercased() < rhs.name.lowercased()
        }
    }

    /// Normalize subscription name for matching
    private func normalizeNameForMatching(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: "premium", with: "")
            .replacingOccurrences(of: "plus", with: "")
            .replacingOccurrences(of: "pro", with: "")
            .replacingOccurrences(of: "subscription", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Check if two normalized names are similar enough to be considered duplicates
    private func fuzzyMatch(_ name1: String, _ name2: String) -> Bool {
        // Exact match
        if name1 == name2 { return true }

        // One contains the other
        if name1.contains(name2) || name2.contains(name1) { return true }

        // Levenshtein distance for short names
        if name1.count <= 10 && name2.count <= 10 {
            return levenshteinDistance(name1, name2) <= 2
        }

        return false
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        var distances = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)

        for i in 0...s1Array.count { distances[i][0] = i }
        for j in 0...s2Array.count { distances[0][j] = j }

        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                distances[i][j] = min(
                    distances[i - 1][j] + 1,
                    distances[i][j - 1] + 1,
                    distances[i - 1][j - 1] + cost
                )
            }
        }

        return distances[s1Array.count][s2Array.count]
    }

    /// Toggle subscription selection
    func toggleSubscription(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index].isSelected.toggle()
        }
    }

    /// Remove a subscription from the list
    func removeSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
    }

    /// Add a new subscription manually
    func addSubscription(name: String, price: Double, cycle: BillingCycle) {
        let subscription = Subscription(
            merchantId: UUID().uuidString,
            name: name,
            price: price,
            billingCycle: cycle,
            confidence: .high,  // Manual entries are high confidence
            senderEmail: "manual",
            detectionSource: .manual
        )
        subscriptions.append(subscription)
    }

    /// Add a new subscription manually (from the shared add flow)
    func addSubscription(_ subscription: Subscription) {
        subscriptions.append(subscription)
    }

    /// Update subscription details
    func updateSubscription(_ subscription: Subscription, name: String? = nil, price: Double? = nil, cycle: BillingCycle? = nil) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            if let name = name {
                subscriptions[index].name = name
            }
            if let price = price {
                subscriptions[index].price = price
            }
            if let cycle = cycle {
                subscriptions[index].billingCycle = cycle
            }
        }
    }

    /// Confirm selected subscriptions and proceed
    func confirmSubscriptions() {
        // Save only selected subscriptions
        let confirmed = selectedSubscriptions
        saveSubscriptions(confirmed)

        viewState = .complete
    }

    /// Get icon info for a subscription
    func getIconInfo(for subscription: Subscription) -> (name: String, color: Color) {
        if let merchant = merchantDB.findMerchant(bySenderEmail: subscription.senderEmail) {
            return (merchant.iconName, merchant.iconColor)
        }
        if let merchant = merchantDB.findMerchant(byKeyword: subscription.name) {
            return (merchant.iconName, merchant.iconColor)
        }
        return merchantDB.defaultIcon()
    }

    // MARK: - Persistence

    private func saveSubscriptions(_ subscriptions: [Subscription]) {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        } catch {
            print("Failed to save subscriptions: \(error)")
        }
    }

    func loadSavedSubscriptions() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([Subscription].self, from: data)
        } catch {
            print("Failed to load subscriptions: \(error)")
            return []
        }
    }

    // MARK: - Scan Progress Observation

    func observeScanProgress() {
        // Observe detection service progress
        Task {
            for await progress in detectionService.$progress.values {
                self.scanProgress = progress
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let googleError = error as? GoogleOAuthError {
            switch googleError {
            case .notAuthenticated, .noRefreshToken:
                errorMessage = "Please sign in to Gmail again."
            default:
                errorMessage = googleError.localizedDescription
            }
        } else if let gmailError = error as? GmailAPIError {
            errorMessage = gmailError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
