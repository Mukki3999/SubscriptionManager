//
//  SubscriptionDetailViewModel.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation
import SwiftUI

// MARK: - Related Emails Cache Entry

private struct RelatedEmailsCacheEntry {
    let emails: [GmailMessage]
    let timestamp: Date
}

// MARK: - Subscription Detail ViewModel

@MainActor
final class SubscriptionDetailViewModel: ObservableObject {

    // MARK: - Static Cache

    /// Shared cache for related email results (survives view model lifecycle)
    private static var relatedEmailsCache: [String: RelatedEmailsCacheEntry] = [:]

    /// Cache time-to-live (1 hour)
    private static let cacheTTL: TimeInterval = 3600

    // MARK: - Published Properties

    @Published private(set) var managementType: SubscriptionManagementType = .unknown
    @Published private(set) var cancelURL: String?
    @Published private(set) var cancellationSteps: [String]?
    @Published private(set) var relatedEmails: [GmailMessage] = []
    @Published private(set) var isLoadingEmails = false
    @Published private(set) var emailSearchError: String?
    @Published private(set) var isFromCache = false
    @Published var showWebCancelInterstitial = false

    // MARK: - Private Properties

    private let subscription: Subscription
    private let cancellationInfoService = CancellationInfoService.shared
    private let gmailService = GmailAPIService()
    private let oauthService = GoogleOAuthService()

    // MARK: - AppStorage

    @AppStorage("hasSeenWebCancelInterstitial") private var hasSeenWebCancelInterstitial = false

    // MARK: - Initialization

    init(subscription: Subscription) {
        self.subscription = subscription
        loadCancellationInfo()
    }

    // MARK: - Public Properties

    var subscriptionName: String {
        subscription.name
    }

    var subscriptionPrice: String {
        subscription.formattedPrice
    }

    var subscriptionPriceWithCycle: String {
        subscription.priceWithCycle
    }

    var subscriptionBillingCycle: String {
        subscription.billingCycle.rawValue
    }

    var detectionSourceLabel: String {
        subscription.detectionSource.rawValue
    }

    var nextBillingDateFormatted: String? {
        guard let date = subscription.nextBillingDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var daysUntilNextBilling: Int? {
        subscription.daysUntilNextBilling
    }

    var senderEmail: String {
        subscription.senderEmail
    }

    var merchantId: String {
        subscription.merchantId
    }

    var isAppStoreSubscription: Bool {
        managementType == .appStore
    }

    var isWebSubscription: Bool {
        managementType == .web
    }

    var isUnknownSubscription: Bool {
        managementType == .unknown
    }

    var isManuallyAdded: Bool {
        subscription.detectionSource == .manual
    }

    var hasRelatedEmails: Bool {
        !relatedEmails.isEmpty
    }

    var manageButtonTitle: String {
        switch managementType {
        case .appStore:
            return "Manage in Settings"
        case .web:
            return "Manage Subscription"
        case .unknown:
            // For manually added, go to website; otherwise search emails
            return isManuallyAdded ? "Manage on Website" : "Find Cancellation Info"
        }
    }

    /// Get the fallback website URL from the subscription's domain
    var fallbackAccountURL: String? {
        let domain = subscription.senderEmail
        guard !domain.isEmpty else { return nil }
        let cleanDomain = domain.lowercased()
            .replacingOccurrences(of: "www.", with: "")
        return "https://www.\(cleanDomain)"
    }

    // MARK: - Public Methods

    /// Load cancellation info for the subscription
    func loadCancellationInfo() {
        managementType = cancellationInfoService.determineManagementType(for: subscription)
        cancelURL = cancellationInfoService.getCancelURL(for: subscription)
        cancellationSteps = cancellationInfoService.getCancellationSteps(for: subscription)
    }

    /// Handle the manage subscription button tap
    func handleManageSubscription() {
        switch managementType {
        case .appStore:
            openAppStoreSubscriptions()

        case .web:
            if !hasSeenWebCancelInterstitial {
                showWebCancelInterstitial = true
            } else {
                openCancelURL()
            }

        case .unknown:
            if isManuallyAdded {
                // For manually added subscriptions, go to the company's website
                openFallbackAccountURL()
            } else {
                // For email-detected subscriptions, search for related emails
                Task {
                    await searchRelatedEmails()
                }
            }
        }
    }

    /// Open App Store subscription management
    func openAppStoreSubscriptions() {
        URLLaunchService.openAppStoreSubscriptions()
    }

    /// Open the cancel URL in Safari
    func openCancelURL() {
        guard let urlString = cancelURL else { return }
        URLLaunchService.openInSafari(urlString)
    }

    /// Open the fallback account URL for manually added subscriptions
    func openFallbackAccountURL() {
        guard let urlString = fallbackAccountURL else { return }
        URLLaunchService.openInSafari(urlString)
    }

    /// Confirm and open the cancel URL after seeing interstitial
    func confirmAndOpenCancelURL() {
        hasSeenWebCancelInterstitial = true
        showWebCancelInterstitial = false
        openCancelURL()
    }

    /// Search for related emails in Gmail (with caching)
    func searchRelatedEmails() async {
        // Create cache key from subscription ID
        let cacheKey = subscription.id.uuidString

        // Check cache first
        if let cached = Self.relatedEmailsCache[cacheKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < Self.cacheTTL {
                // Cache hit - use cached results
                relatedEmails = cached.emails
                isFromCache = true
                return
            }
        }

        isLoadingEmails = true
        emailSearchError = nil
        isFromCache = false

        do {
            let accessToken = try await oauthService.getValidAccessToken()

            // Extract domain from sender email
            let senderDomain = extractDomain(from: subscription.senderEmail)

            let emails = try await gmailService.searchRelatedEmails(
                accessToken: accessToken,
                senderDomain: senderDomain,
                merchantName: subscription.name,
                maxResults: 20
            )

            relatedEmails = emails

            // Cache the results
            Self.relatedEmailsCache[cacheKey] = RelatedEmailsCacheEntry(
                emails: emails,
                timestamp: Date()
            )
        } catch {
            emailSearchError = error.localizedDescription
        }

        isLoadingEmails = false
    }

    /// Force refresh related emails (bypasses cache)
    func refreshRelatedEmails() async {
        // Remove from cache
        Self.relatedEmailsCache.removeValue(forKey: subscription.id.uuidString)
        // Fetch fresh
        await searchRelatedEmails()
    }

    /// Clear the entire related emails cache
    static func clearRelatedEmailsCache() {
        relatedEmailsCache.removeAll()
    }

    /// Prune expired entries from cache
    static func pruneRelatedEmailsCache() {
        let now = Date()
        relatedEmailsCache = relatedEmailsCache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) < cacheTTL
        }
    }

    // MARK: - Private Methods

    private func extractDomain(from email: String) -> String? {
        guard let atIndex = email.firstIndex(of: "@") else { return nil }
        let domain = String(email[email.index(after: atIndex)...])
        return domain.isEmpty ? nil : domain
    }
}
