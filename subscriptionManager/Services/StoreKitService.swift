//
//  StoreKitService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/16/26.
//

import Foundation
import StoreKit

/// Service for fetching App Store subscriptions using StoreKit 2
@MainActor
final class StoreKitService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isScanning = false

    // MARK: - Product ID Mappings

    /// Maps known product ID patterns to merchant names
    private let productIdMappings: [String: String] = [
        // Apple Services
        "com.apple.music": "Apple Music",
        "apple.music": "Apple Music",
        "com.apple.tvplus": "Apple TV+",
        "apple.tv": "Apple TV+",
        "com.apple.arcade": "Apple Arcade",
        "apple.arcade": "Apple Arcade",
        "com.apple.icloud": "iCloud+",
        "icloud": "iCloud+",
        "com.apple.news": "Apple News+",
        "apple.news": "Apple News+",
        "com.apple.fitness": "Apple Fitness+",
        "apple.fitness": "Apple Fitness+",
        "com.apple.one": "Apple One",
        "apple.one": "Apple One",

        // Streaming
        "com.spotify": "Spotify",
        "spotify": "Spotify",
        "com.netflix": "Netflix",
        "netflix": "Netflix",
        "com.hbo": "HBO Max",
        "hbomax": "HBO Max",
        "com.disney": "Disney+",
        "disneyplus": "Disney+",
        "com.hulu": "Hulu",
        "hulu": "Hulu",
        "com.paramount": "Paramount+",
        "paramountplus": "Paramount+",
        "com.peacock": "Peacock",
        "peacock": "Peacock",
        "com.amazon.prime": "Amazon Prime Video",
        "primevideo": "Amazon Prime Video",

        // Productivity
        "com.notion": "Notion",
        "notion": "Notion",
        "com.todoist": "Todoist",
        "todoist": "Todoist",
        "com.1password": "1Password",
        "1password": "1Password",
        "com.dropbox": "Dropbox",
        "dropbox": "Dropbox",
        "com.evernote": "Evernote",
        "evernote": "Evernote",

        // Fitness & Health
        "com.strava": "Strava",
        "strava": "Strava",
        "com.headspace": "Headspace",
        "headspace": "Headspace",
        "com.calm": "Calm",
        "calm": "Calm",
        "com.noom": "Noom",
        "noom": "Noom",
        "com.myfitnesspal": "MyFitnessPal",
        "myfitnesspal": "MyFitnessPal",

        // Creative
        "com.canva": "Canva",
        "canva": "Canva",
        "com.adobe": "Adobe Creative Cloud",
        "adobe": "Adobe Creative Cloud",
        "com.figma": "Figma",
        "figma": "Figma",

        // News & Reading
        "com.nytimes": "New York Times",
        "nytimes": "New York Times",
        "com.washingtonpost": "Washington Post",
        "washingtonpost": "Washington Post",
        "com.medium": "Medium",
        "medium": "Medium",

        // Dating
        "com.tinder": "Tinder",
        "tinder": "Tinder",
        "com.bumble": "Bumble",
        "bumble": "Bumble",
        "com.hinge": "Hinge",
        "hinge": "Hinge",

        // Gaming
        "com.playstation": "PlayStation Plus",
        "playstation": "PlayStation Plus",
        "com.xbox": "Xbox Game Pass",
        "xbox": "Xbox Game Pass",

        // Language Learning
        "com.duolingo": "Duolingo",
        "duolingo": "Duolingo",
        "com.babbel": "Babbel",
        "babbel": "Babbel",

        // VPN
        "com.nordvpn": "NordVPN",
        "nordvpn": "NordVPN",
        "com.expressvpn": "ExpressVPN",
        "expressvpn": "ExpressVPN",
        "com.surfshark": "Surfshark",
        "surfshark": "Surfshark"
    ]

    // MARK: - Public Methods

    /// Fetches all auto-renewable subscriptions from StoreKit 2
    func fetchSubscriptions() async throws -> [Subscription] {
        isScanning = true
        defer { isScanning = false }

        var subscriptions: [Subscription] = []
        var transactionCount = 0

        // Iterate through all transactions
        for await result in Transaction.all {
            transactionCount += 1

            // Only process verified transactions
            guard case .verified(let transaction) = result else { continue }

            // Only include auto-renewable subscriptions
            guard transaction.productType == .autoRenewable else { continue }

            // Convert to our Subscription model
            if let subscription = await convertToSubscription(transaction) {
                subscriptions.append(subscription)
            }
        }

        // Deduplicate by product ID, keeping the most recent transaction
        let deduped = Dictionary(grouping: subscriptions) { $0.productId ?? $0.merchantId }
            .compactMapValues { $0.max { ($0.lastChargeDate ?? .distantPast) < ($1.lastChargeDate ?? .distantPast) } }
            .values
            .map { $0 }

        return Array(deduped)
    }

    /// Gets currently active subscription product IDs
    func getActiveSubscriptionProductIds() async -> Set<String> {
        var activeProductIds: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productType == .autoRenewable {
                activeProductIds.insert(transaction.productID)
            }
        }

        return activeProductIds
    }

    /// Checks if StoreKit transaction access is available
    func checkStoreKitAccess() async -> Bool {
        // Try to access transactions - if we can iterate, we have access
        var hasAccess = false

        for await result in Transaction.all {
            // If we can get even one transaction, we have access
            if case .verified = result {
                hasAccess = true
                break
            }
        }

        return hasAccess
    }

    /// Gets the count of transactions for progress tracking
    func getTransactionCount() async -> Int {
        var count = 0
        for await _ in Transaction.all {
            count += 1
        }
        return count
    }

    // MARK: - Private Methods

    /// Converts a StoreKit transaction to our Subscription model
    private func convertToSubscription(_ transaction: Transaction) async -> Subscription? {
        let productId = transaction.productID
        let merchantName = inferMerchantName(from: productId)
        let billingCycle = inferBillingCycle(from: productId)

        // Get product info for price
        var price: Double = 0
        if let product = try? await Product.products(for: [productId]).first {
            price = NSDecimalNumber(decimal: product.price).doubleValue
        }

        // Check if this subscription is currently active
        let isActive = await isSubscriptionActive(productId: productId)

        // Only include active subscriptions
        guard isActive else { return nil }

        return Subscription(
            merchantId: productId,
            name: merchantName,
            price: price,
            billingCycle: billingCycle,
            confidence: .high, // StoreKit data is highly accurate
            nextBillingDate: transaction.expirationDate,
            lastChargeDate: transaction.purchaseDate,
            emailCount: 0,
            senderEmail: "",
            detectionSource: .appStore,
            productId: productId
        )
    }

    /// Infers merchant name from product ID
    private func inferMerchantName(from productId: String) -> String {
        let lowercasedId = productId.lowercased()

        // Check against known mappings
        for (pattern, name) in productIdMappings {
            if lowercasedId.contains(pattern.lowercased()) {
                return name
            }
        }

        // Try to extract a meaningful name from the product ID
        // Product IDs often follow patterns like: com.company.product.plan
        let components = productId.split(separator: ".")
        if components.count >= 2 {
            // Try to get the company name (usually second component after "com")
            let companyIndex = components.first?.lowercased() == "com" ? 1 : 0
            if companyIndex < components.count {
                let companyName = String(components[companyIndex])
                return formatProductIdAsName(companyName)
            }
        }

        return formatProductIdAsName(productId)
    }

    /// Infers billing cycle from product ID patterns
    private func inferBillingCycle(from productId: String) -> BillingCycle {
        let lowercasedId = productId.lowercased()

        // Check for common billing cycle indicators in product ID
        if lowercasedId.contains("weekly") || lowercasedId.contains("week") || lowercasedId.contains("_w_") {
            return .weekly
        } else if lowercasedId.contains("monthly") || lowercasedId.contains("month") || lowercasedId.contains("_m_") {
            return .monthly
        } else if lowercasedId.contains("quarterly") || lowercasedId.contains("quarter") || lowercasedId.contains("3month") {
            return .quarterly
        } else if lowercasedId.contains("yearly") || lowercasedId.contains("annual") || lowercasedId.contains("year") || lowercasedId.contains("_y_") {
            return .yearly
        }

        // Default to monthly as it's most common
        return .monthly
    }

    /// Checks if a subscription is currently active
    private func isSubscriptionActive(productId: String) async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == productId {
                return true
            }
        }
        return false
    }

    /// Formats a product ID component as a display name
    private func formatProductIdAsName(_ component: String) -> String {
        // Remove common prefixes/suffixes
        var name = component
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "premium", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "subscription", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "sub", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        // Capitalize first letter of each word
        name = name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")

        return name.isEmpty ? component : name
    }
}

// MARK: - StoreKit Errors

enum StoreKitServiceError: LocalizedError {
    case noTransactionsAvailable
    case productNotFound(String)
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .noTransactionsAvailable:
            return "No App Store transactions available"
        case .productNotFound(let productId):
            return "Product not found: \(productId)"
        case .verificationFailed:
            return "Transaction verification failed"
        }
    }
}
