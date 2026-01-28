//
//  HomeViewModel.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Subscription Provider Protocol

/// Protocol for providing subscription data to the HomeViewModel.
/// This enables dependency injection for testing and modularity.
protocol SubscriptionProviding {
    func loadSubscriptions() -> [Subscription]
    func saveSubscriptions(_ subscriptions: [Subscription])
}

// MARK: - Default Subscription Provider

/// Default implementation using UserDefaults for persistence.
final class DefaultSubscriptionProvider: SubscriptionProviding {

    private let subscriptionsKey = "confirmedSubscriptions"

    func loadSubscriptions() -> [Subscription] {
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

    func saveSubscriptions(_ subscriptions: [Subscription]) {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        } catch {
            print("Failed to save subscriptions: \(error)")
        }
    }
}

// MARK: - Home View Model

/// ViewModel for the home screen managing subscription display state.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var subscriptions: [Subscription] = []
    @Published private(set) var customOrderIds: [UUID] = []
    @Published private(set) var colorIndices: [UUID: Int] = [:]
    @Published var isBalanceHidden: Bool = false
    @Published var userName: String = "User"

    // MARK: - Tier Management

    /// Current subscription count
    var subscriptionCount: Int {
        subscriptions.count
    }

    /// Check if user can add more subscriptions based on their tier
    var canAddSubscription: Bool {
        TierManager.shared.canAddSubscription(currentCount: subscriptionCount)
    }

    /// Check if user has reached their subscription limit
    var hasReachedLimit: Bool {
        TierManager.shared.hasReachedLimit(currentCount: subscriptionCount)
    }

    /// Number of remaining subscription slots for free tier
    var remainingSlots: Int {
        TierManager.shared.remainingSlots(currentCount: subscriptionCount)
    }

    /// Current user tier
    var currentTier: SubscriptionTier {
        TierManager.shared.currentTier
    }

    // MARK: - Dependencies

    private let subscriptionProvider: SubscriptionProviding
    private let orderStorageKey = "subscriptionCustomOrder"
    private let colorIndicesKey = "subscriptionColorIndices"

    // MARK: - Computed Properties

    /// Total monthly balance from all subscriptions
    var totalMonthlyBalance: Double {
        subscriptions.reduce(0) { total, sub in
            switch sub.billingCycle {
            case .weekly:
                return total + (sub.price * 4.33)
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

    /// Subscriptions sorted by next billing date (upcoming first)
    var upcomingBills: [Subscription] {
        subscriptions
            .filter { $0.nextBillingDate != nil }
            .sorted { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }
    }

    /// All subscriptions for the list view, respecting custom order
    var allSubscriptions: [Subscription] {
        guard !customOrderIds.isEmpty else {
            return subscriptions.sorted { $0.name < $1.name }
        }

        // Build ordered list based on customOrderIds
        var ordered: [Subscription] = []
        for id in customOrderIds {
            if let subscription = subscriptions.first(where: { $0.id == id }) {
                ordered.append(subscription)
            }
        }

        // Append any subscriptions not in the custom order (newly added)
        let orderedIds = Set(customOrderIds)
        let newSubscriptions = subscriptions
            .filter { !orderedIds.contains($0.id) }
            .sorted { $0.name < $1.name }
        ordered.append(contentsOf: newSubscriptions)

        return ordered
    }

    /// Current billing period end date formatted
    var billingPeriodEnd: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let endOfMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: Date())
        ).flatMap {
            Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: $0)
        } ?? Date()
        return formatter.string(from: endOfMonth)
    }

    // MARK: - Initializer

    init(subscriptionProvider: SubscriptionProviding = DefaultSubscriptionProvider()) {
        self.subscriptionProvider = subscriptionProvider
        loadOrder()
        loadColorIndices()
        migrateColorsIfNeeded()
    }

    /// Migration key to track if colors have been reassigned
    private let colorMigrationKey = "hasReassignedColorsV1"

    // MARK: - Public Methods

    /// Load subscriptions from the provider
    func loadSubscriptions() {
        subscriptions = subscriptionProvider.loadSubscriptions()
        syncOrderWithSubscriptions()
    }

    /// Toggle balance visibility
    func toggleBalanceVisibility() {
        isBalanceHidden.toggle()
    }

    /// Get card color for subscription at index
    func cardColor(for index: Int) -> Color {
        SubscriptionCardColor.color(for: index).backgroundColor
    }

    /// Preview the next available card color for a newly added subscription
    func nextAvailableCardColor() -> Color {
        SubscriptionCardColors.color(for: nextAvailableColorIndex())
    }

    /// Get the persistent color index for a subscription by its ID
    func colorIndex(for subscriptionId: UUID) -> Int {
        colorIndices[subscriptionId] ?? 0
    }

    /// Calculate days until next billing for a subscription
    func daysUntilBilling(for subscription: Subscription) -> Int {
        guard let nextDate = subscription.nextBillingDate else {
            // If no next billing date, estimate based on billing cycle
            return subscription.billingCycle.approximateDays
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDate)
        return max(0, components.day ?? 0)
    }

    /// Delete a subscription
    func deleteSubscription(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        subscriptionProvider.saveSubscriptions(subscriptions)
    }

    /// Add a new subscription
    func addSubscription(_ subscription: Subscription) {
        subscriptions.append(subscription)
        subscriptionProvider.saveSubscriptions(subscriptions)
        syncOrderWithSubscriptions()
    }

    /// Update an existing subscription
    func updateSubscription(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            subscriptionProvider.saveSubscriptions(subscriptions)
        }
    }

    /// Move a subscription from one position to another
    func moveSubscription(from sourceIndex: Int, to destinationIndex: Int) {
        let orderedSubscriptions = allSubscriptions
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < orderedSubscriptions.count,
              destinationIndex >= 0, destinationIndex < orderedSubscriptions.count else {
            return
        }

        var newOrder = orderedSubscriptions.map { $0.id }
        let movedId = newOrder.remove(at: sourceIndex)
        newOrder.insert(movedId, at: destinationIndex)
        customOrderIds = newOrder
        saveOrder()
    }

    // MARK: - Private Methods

    /// Load custom order from UserDefaults
    private func loadOrder() {
        guard let data = UserDefaults.standard.data(forKey: orderStorageKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return
        }
        customOrderIds = ids
    }

    /// Save custom order to UserDefaults
    private func saveOrder() {
        guard let data = try? JSONEncoder().encode(customOrderIds) else {
            return
        }
        UserDefaults.standard.set(data, forKey: orderStorageKey)
    }

    /// Load color indices from UserDefaults
    private func loadColorIndices() {
        guard let data = UserDefaults.standard.data(forKey: colorIndicesKey),
              let indices = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return
        }
        // Convert String keys back to UUIDs
        colorIndices = indices.reduce(into: [:]) { result, pair in
            if let uuid = UUID(uuidString: pair.key) {
                result[uuid] = pair.value
            }
        }
    }

    /// Save color indices to UserDefaults
    private func saveColorIndices() {
        // Convert UUID keys to Strings for encoding
        let stringKeyedIndices = colorIndices.reduce(into: [String: Int]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        guard let data = try? JSONEncoder().encode(stringKeyedIndices) else {
            return
        }
        UserDefaults.standard.set(data, forKey: colorIndicesKey)
    }

    /// Sync custom order with current subscriptions (remove deleted, keep order for existing)
    private func syncOrderWithSubscriptions() {
        let subscriptionIds = Set(subscriptions.map { $0.id })

        // Remove IDs that no longer exist from order
        customOrderIds = customOrderIds.filter { subscriptionIds.contains($0) }

        // Remove color indices for deleted subscriptions
        colorIndices = colorIndices.filter { subscriptionIds.contains($0.key) }

        // Add any new subscription IDs not in the order and assign colors
        let orderedIds = Set(customOrderIds)
        let newSubscriptions = subscriptions
            .filter { !orderedIds.contains($0.id) }
            .sorted { $0.name < $1.name }

        for subscription in newSubscriptions {
            customOrderIds.append(subscription.id)
            // Assign color based on position - next available color that hasn't been used recently
            colorIndices[subscription.id] = nextAvailableColorIndex()
        }

        saveOrder()
        saveColorIndices()
    }

    /// Get the next available color index, cycling through all colors before repeating
    private func nextAvailableColorIndex() -> Int {
        let totalColors = SubscriptionCardColors.cardRotation.count
        let usedColors = Set(colorIndices.values)

        // If we've used all colors, start from the beginning based on count
        if usedColors.count >= totalColors {
            return colorIndices.count % totalColors
        }

        // Find the first unused color index
        for i in 0..<totalColors {
            if !usedColors.contains(i) {
                return i
            }
        }

        // Fallback: use count-based index
        return colorIndices.count % totalColors
    }

    /// One-time migration to reassign colors sequentially (fixes duplicate colors issue)
    private func migrateColorsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: colorMigrationKey) else {
            return
        }

        // Reassign all colors sequentially based on order
        let totalColors = SubscriptionCardColors.cardRotation.count
        var newColorIndices: [UUID: Int] = [:]

        for (index, subscriptionId) in customOrderIds.enumerated() {
            newColorIndices[subscriptionId] = index % totalColors
        }

        colorIndices = newColorIndices
        saveColorIndices()
        UserDefaults.standard.set(true, forKey: colorMigrationKey)
    }
}

// MARK: - Mock Data Extension

extension HomeViewModel {
    /// Create a view model with mock data for previews
    static func mockViewModel() -> HomeViewModel {
        let viewModel = HomeViewModel(subscriptionProvider: MockSubscriptionProvider())
        viewModel.loadSubscriptions()
        return viewModel
    }
}

// MARK: - Mock Subscription Provider

private final class MockSubscriptionProvider: SubscriptionProviding {
    func loadSubscriptions() -> [Subscription] {
        [
            Subscription(
                merchantId: "spotify",
                name: "Spotify",
                price: 18.00,
                billingCycle: .monthly,
                confidence: .high,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
                senderEmail: "no-reply@spotify.com"
            ),
            Subscription(
                merchantId: "netflix",
                name: "Netflix",
                price: 21.00,
                billingCycle: .monthly,
                confidence: .high,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
                senderEmail: "info@netflix.com"
            ),
            Subscription(
                merchantId: "apple_tv",
                name: "Apple TV",
                price: 12.00,
                billingCycle: .monthly,
                confidence: .high,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
                senderEmail: "no-reply@apple.com"
            ),
            Subscription(
                merchantId: "openai",
                name: "OpenAI",
                price: 20.00,
                billingCycle: .monthly,
                confidence: .high,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                senderEmail: "noreply@openai.com"
            ),
            Subscription(
                merchantId: "anthropic",
                name: "Anthropic",
                price: 20.00,
                billingCycle: .monthly,
                confidence: .high,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 18, to: Date()),
                senderEmail: "billing@anthropic.com"
            )
        ]
    }

    func saveSubscriptions(_ subscriptions: [Subscription]) {
        // No-op for mock
    }
}
