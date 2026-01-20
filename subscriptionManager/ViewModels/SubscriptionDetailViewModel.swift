//
//  SubscriptionDetailViewModel.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation
import SwiftUI

// MARK: - Subscription Detail ViewModel

@MainActor
final class SubscriptionDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var managementType: SubscriptionManagementType = .unknown
    @Published private(set) var cancelURL: String?
    @Published private(set) var cancellationSteps: [String]?
    @Published private(set) var relatedEmails: [GmailMessage] = []
    @Published private(set) var isLoadingEmails = false
    @Published private(set) var emailSearchError: String?
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
            return "Find Cancellation Info"
        }
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
            // For unknown, search for related emails
            Task {
                await searchRelatedEmails()
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

    /// Confirm and open the cancel URL after seeing interstitial
    func confirmAndOpenCancelURL() {
        hasSeenWebCancelInterstitial = true
        showWebCancelInterstitial = false
        openCancelURL()
    }

    /// Search for related emails in Gmail
    func searchRelatedEmails() async {
        isLoadingEmails = true
        emailSearchError = nil

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
        } catch {
            emailSearchError = error.localizedDescription
        }

        isLoadingEmails = false
    }

    // MARK: - Private Methods

    private func extractDomain(from email: String) -> String? {
        guard let atIndex = email.firstIndex(of: "@") else { return nil }
        let domain = String(email[email.index(after: atIndex)...])
        return domain.isEmpty ? nil : domain
    }
}
