//
//  CancellationInfoService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation

// MARK: - Cancellation Info Service

final class CancellationInfoService {

    // MARK: - Singleton

    static let shared = CancellationInfoService()

    // MARK: - Properties

    private var cancellationInfoDatabase: [String: CancellationInfo] = [:]

    /// Known Apple service merchant IDs that are managed through App Store
    private let appleServiceIds: Set<String> = [
        "apple_music",
        "icloud",
        "apple_tv",
        "apple_arcade",
        "apple_fitness",
        "apple_news",
        "apple_one"
    ]

    // MARK: - Initialization

    private init() {
        loadCancellationInfo()
    }

    // MARK: - Private Methods

    private func loadCancellationInfo() {
        guard let url = Bundle.main.url(forResource: "cancellation_info", withExtension: "json") else {
            print("CancellationInfoService: Could not find cancellation_info.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(CancellationInfoResponse.self, from: data)

            // Build dictionary for quick lookup
            for info in response.services {
                cancellationInfoDatabase[info.id] = info
            }

            print("CancellationInfoService: Loaded \(response.services.count) cancellation info entries")
        } catch {
            print("CancellationInfoService: Failed to load cancellation info - \(error)")
        }
    }

    // MARK: - Public Methods

    /// Get cancellation info for a subscription
    /// - Parameter subscription: The subscription to get info for
    /// - Returns: CancellationInfo if found, nil otherwise
    func getCancellationInfo(for subscription: Subscription) -> CancellationInfo? {
        // Try merchantId first
        if let info = findByIdentifier(subscription.merchantId) {
            return info
        }

        // Also try by subscription name (important for manually added subscriptions)
        if let info = findByIdentifier(subscription.name) {
            return info
        }

        return nil
    }

    /// Find cancellation info by any identifier (merchantId or name)
    private func findByIdentifier(_ identifier: String) -> CancellationInfo? {
        // Normalize the identifier for lookup
        let normalizedId = identifier.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        // Try exact match first
        if let info = cancellationInfoDatabase[normalizedId] {
            return info
        }

        // Try without common suffixes
        let idWithoutSuffix = normalizedId
            .replacingOccurrences(of: "_plus", with: "")
            .replacingOccurrences(of: "_premium", with: "")
            .replacingOccurrences(of: "+", with: "")

        if let info = cancellationInfoDatabase[idWithoutSuffix] {
            return info
        }

        // Try partial match (e.g., "Disney+" should match "disney_plus")
        for (key, info) in cancellationInfoDatabase {
            let normalizedKey = key.lowercased()
            // Check if the normalized identifier contains or is contained by the key
            if normalizedId.contains(normalizedKey) || normalizedKey.contains(normalizedId.replacingOccurrences(of: "_", with: "")) {
                return info
            }
        }

        return nil
    }

    /// Determine the management type for a subscription
    /// - Parameter subscription: The subscription to check
    /// - Returns: The appropriate management type
    func determineManagementType(for subscription: Subscription) -> SubscriptionManagementType {
        // 1. Check if detected from App Store
        if subscription.detectionSource == .appStore {
            return .appStore
        }

        // 2. Check if it's a known Apple service (by merchantId or name)
        if isAppleService(identifier: subscription.merchantId) ||
           isAppleService(identifier: subscription.name) {
            return .appStore
        }

        // 3. Check database for known info (checks both merchantId and name)
        if let info = getCancellationInfo(for: subscription) {
            return info.type
        }

        // 4. Default to unknown
        return .unknown
    }

    /// Check if an identifier matches a known Apple service
    private func isAppleService(identifier: String) -> Bool {
        let normalizedId = identifier.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "+", with: "")

        // Check exact match
        if appleServiceIds.contains(normalizedId) {
            return true
        }

        // Check partial matches for common Apple service names
        let appleServiceNames = ["apple music", "icloud", "apple tv", "apple arcade",
                                  "apple fitness", "apple news", "apple one"]
        let lowercaseName = identifier.lowercased()
        return appleServiceNames.contains { lowercaseName.contains($0) }
    }

    /// Check if a merchant ID or name is a known Apple service
    /// - Parameter merchantId: The merchant ID or name to check
    /// - Returns: True if it's a known Apple service
    func isAppleService(merchantId: String) -> Bool {
        return isAppleService(identifier: merchantId)
    }

    /// Get cancellation steps for a subscription
    /// - Parameter subscription: The subscription to get steps for
    /// - Returns: Array of step strings, or nil if not available
    func getCancellationSteps(for subscription: Subscription) -> [String]? {
        return getCancellationInfo(for: subscription)?.steps
    }

    /// Get cancel URL for a subscription
    /// - Parameter subscription: The subscription to get URL for
    /// - Returns: Cancel URL string, or nil if not available
    func getCancelURL(for subscription: Subscription) -> String? {
        return getCancellationInfo(for: subscription)?.cancelURL
    }
}
