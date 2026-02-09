//
//  InsightsViewModel.swift
//  subscriptionManager
//
//  Created by Claude on 1/20/26.
//

import Foundation
import SwiftUI

// MARK: - Category Spending

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: CompanyCategory
    let totalMonthly: Double
    let subscriptions: [Subscription]

    var subscriptionCount: Int {
        subscriptions.count
    }

    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalMonthly)) ?? "$\(totalMonthly)"
    }
}

// MARK: - Insights View Model

@MainActor
final class InsightsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var categoryBreakdown: [CategorySpending] = []
    @Published private(set) var totalMonthlySpending: Double = 0

    // MARK: - Properties

    private var subscriptions: [Subscription]
    private var selectedMonth: Date = Date()

    /// Subscriptions filtered by selectedMonth: only includes subscriptions detected on or before the end of the selected month
    private var filteredSubscriptions: [Subscription] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let startOfMonth = calendar.date(from: components),
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return subscriptions
        }
        // End of selected month = one second before start of next month
        let endOfMonth = startOfNextMonth.addingTimeInterval(-1)
        return subscriptions.filter { $0.detectedAt <= endOfMonth }
    }

    // MARK: - Initialization

    init(subscriptions: [Subscription]) {
        self.subscriptions = subscriptions
        calculateBreakdown()
    }

    // MARK: - Update Methods

    /// Update with new subscriptions data
    func updateSubscriptions(_ newSubscriptions: [Subscription]) {
        self.subscriptions = newSubscriptions
        calculateBreakdown()
    }

    /// Update the selected month and recalculate
    func updateSelectedMonth(_ month: Date) {
        self.selectedMonth = month
        calculateBreakdown()
    }

    // MARK: - Computed Properties

    var formattedTotalMonthly: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalMonthlySpending)) ?? "$\(totalMonthlySpending)"
    }

    var subscriptionCount: Int {
        filteredSubscriptions.count
    }

    var topCategory: CategorySpending? {
        categoryBreakdown.first
    }

    var averageMonthlyPerSubscription: Double {
        guard subscriptionCount > 0 else { return 0 }
        return totalMonthlySpending / Double(subscriptionCount)
    }

    var topSubscription: Subscription? {
        filteredSubscriptions.max { monthlyEquivalent(for: $0) < monthlyEquivalent(for: $1) }
    }

    var topSubscriptionMonthly: Double {
        guard let topSubscription else { return 0 }
        return monthlyEquivalent(for: topSubscription)
    }

    /// Yearly spending projection
    var yearlyProjection: Double {
        totalMonthlySpending * 12
    }

    /// Daily cost (monthly / 30)
    var dailyCost: Double {
        totalMonthlySpending / 30
    }

    /// Next subscription to bill
    var nextBillingSubscription: Subscription? {
        filteredSubscriptions
            .filter { $0.nextBillingDate != nil }
            .min { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }
    }

    /// Days until next billing
    var daysUntilNextBilling: Int? {
        guard let nextSub = nextBillingSubscription,
              let nextDate = nextSub.nextBillingDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day
        return max(0, days ?? 0)
    }

    /// All subscriptions sorted by monthly spend (descending)
    var allSubscriptionsSortedBySpend: [Subscription] {
        filteredSubscriptions.sorted { monthlyEquivalent(for: $0) > monthlyEquivalent(for: $1) }
    }

    /// Billing cycle breakdown for display
    var billingCycleBreakdown: [(cycle: BillingCycle, count: Int, total: Double)] {
        var cycleMap: [BillingCycle: [Subscription]] = [:]

        for subscription in filteredSubscriptions {
            let cycle = subscription.billingCycle
            if cycleMap[cycle] == nil {
                cycleMap[cycle] = []
            }
            cycleMap[cycle]?.append(subscription)
        }

        return cycleMap.map { cycle, subs in
            let total = subs.reduce(0) { $0 + $1.price }
            return (cycle: cycle, count: subs.count, total: total)
        }
        .sorted { $0.count > $1.count }
    }

    /// Get category for a subscription
    func category(for subscription: Subscription) -> CompanyCategory {
        lookupCategory(for: subscription)
    }

    // MARK: - Methods

    /// Calculate category breakdown from filtered subscriptions
    private func calculateBreakdown() {
        // Group filtered subscriptions by category
        var categoryMap: [CompanyCategory: [Subscription]] = [:]

        for subscription in filteredSubscriptions {
            let category = lookupCategory(for: subscription)
            if categoryMap[category] == nil {
                categoryMap[category] = []
            }
            categoryMap[category]?.append(subscription)
        }

        // Calculate monthly totals and create CategorySpending items
        var breakdown: [CategorySpending] = []
        var total: Double = 0

        for (category, subs) in categoryMap {
            let monthlyTotal = subs.reduce(0) { sum, sub in
                sum + monthlyEquivalent(for: sub)
            }
            total += monthlyTotal

            breakdown.append(CategorySpending(
                category: category,
                totalMonthly: monthlyTotal,
                subscriptions: subs
            ))
        }

        // Sort by total monthly spending (descending)
        breakdown.sort { $0.totalMonthly > $1.totalMonthly }

        self.categoryBreakdown = breakdown
        self.totalMonthlySpending = total
    }

    /// Look up category for a subscription using CompanyLogoService with fallback mapping
    private func lookupCategory(for subscription: Subscription) -> CompanyCategory {
        // First try CompanyLogoService
        if let company = CompanyLogoService.shared.findCompany(for: subscription.name) {
            return company.category
        }

        // Fallback category mapping for common subscriptions
        let name = subscription.name.lowercased()

        // Streaming
        let streamingServices = ["netflix", "disney+", "disneyplus", "disney plus", "hulu", "max", "hbo",
                                  "youtube premium", "youtube", "amazon prime", "prime video", "apple tv",
                                  "peacock", "paramount+", "paramount plus", "crunchyroll", "funimation"]
        if streamingServices.contains(where: { name.contains($0) }) {
            return .streaming
        }

        // Music
        let musicServices = ["spotify", "apple music", "tidal", "pandora", "deezer", "soundcloud", "audible"]
        if musicServices.contains(where: { name.contains($0) }) {
            return .music
        }

        // Gaming
        let gamingServices = ["xbox", "playstation", "nintendo", "ea play", "game pass", "twitch"]
        if gamingServices.contains(where: { name.contains($0) }) {
            return .gaming
        }

        // Productivity
        let productivityServices = ["adobe", "figma", "notion", "slack", "canva", "microsoft 365", "office",
                                     "google workspace", "asana", "trello", "linear", "todoist", "evernote"]
        if productivityServices.contains(where: { name.contains($0) }) {
            return .productivity
        }

        // Cloud Storage
        let cloudServices = ["dropbox", "icloud", "google one", "google drive", "onedrive"]
        if cloudServices.contains(where: { name.contains($0) }) {
            return .cloud
        }

        // VPN/Security
        let vpnServices = ["1password", "nordvpn", "expressvpn", "surfshark", "bitwarden", "dashlane",
                           "lastpass", "proton"]
        if vpnServices.contains(where: { name.contains($0) }) {
            return .vpn
        }

        // Fitness
        let fitnessServices = ["strava", "headspace", "calm", "peloton", "myfitnesspal", "fitbit"]
        if fitnessServices.contains(where: { name.contains($0) }) {
            return .fitness
        }

        // AI
        let aiServices = ["chatgpt", "openai", "claude", "anthropic", "midjourney", "grammarly"]
        if aiServices.contains(where: { name.contains($0) }) {
            return .ai
        }

        return .other
    }

    /// Convert subscription price to monthly equivalent
    func monthlyEquivalent(for subscription: Subscription) -> Double {
        switch subscription.billingCycle {
        case .weekly:
            return subscription.price * 4.33 // ~4.33 weeks per month
        case .monthly:
            return subscription.price
        case .quarterly:
            return subscription.price / 3
        case .yearly:
            return subscription.price / 12
        case .unknown:
            return subscription.price // Assume monthly if unknown
        }
    }

    // MARK: - Export

    /// Generate export bundle for sharing
    func exportForShare() -> [URL]? {
        let includeReport = TierManager.shared.currentTier == .pro
        return ExportService.shared.exportBundle(subscriptions, includeReport: includeReport)
    }
}
