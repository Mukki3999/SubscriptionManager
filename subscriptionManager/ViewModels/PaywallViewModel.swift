//
//  PaywallViewModel.swift
//  subscriptionManager
//
//  Created by Claude on 1/19/26.
//

import Foundation
import RevenueCat
import SwiftUI

// MARK: - Paywall Trigger

/// Describes why the paywall was presented
enum PaywallTrigger {
    case onboarding // After initial scan during onboarding
    case subscriptionLimit // User tried to add 6th subscription
    case featureGate(String) // User tried to access a Pro feature
    case settings // User tapped upgrade in settings
    case rescan // User tried to rescan without Pro

    var headline: String {
        switch self {
        case .onboarding:
            return "Unlock Unlimited Tracking"
        case .subscriptionLimit:
            return "You've Reached the Free Limit"
        case .featureGate(let feature):
            return "Unlock \(feature)"
        case .settings:
            return "Upgrade to Pro"
        case .rescan:
            return "Unlock Unlimited Rescans"
        }
    }

    var subtitle: String {
        switch self {
        case .onboarding:
            return "Track all your subscriptions and never miss a renewal"
        case .subscriptionLimit:
            return "Free accounts can track up to 3 subscriptions"
        case .featureGate:
            return "Get access to all Pro features"
        case .settings:
            return "Get the most out of your subscription tracking"
        case .rescan:
            return "Rescan your accounts anytime to find new subscriptions"
        }
    }
}

// MARK: - Paywall View Model

@MainActor
final class PaywallViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedPlan: PremiumProduct = .annual
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var purchaseSuccessful: Bool = false

    // MARK: - Properties

    let trigger: PaywallTrigger
    let detectedSubscriptionCount: Int?

    // MARK: - Dependencies

    private let purchaseService = RevenueCatPurchaseService.shared

    // MARK: - Computed Properties

    /// Current paywall variant for A/B testing
    var paywallVariant: PaywallVariant {
        purchaseService.currentPaywallVariant
    }

    /// Whether to show RevenueCat's paywall UI
    var shouldShowRevenueCatPaywall: Bool {
        purchaseService.shouldShowRevenueCatPaywall
    }

    /// Available packages from RevenueCat
    var packages: [Package] {
        purchaseService.availablePackages
    }

    var monthlyPackage: Package? {
        purchaseService.monthlyPackage
    }

    var annualPackage: Package? {
        purchaseService.annualPackage
    }

    var selectedPackage: Package? {
        switch selectedPlan {
        case .monthly:
            return monthlyPackage
        case .annual:
            return annualPackage
        }
    }

    var hasFreeTrial: Bool {
        selectedPackage?.storeProduct.hasFreeTrial ?? false
    }

    var freeTrialText: String? {
        selectedPackage?.storeProduct.freeTrialDuration
    }

    var isLoading: Bool {
        purchaseService.isLoading || isProcessing
    }

    /// Check if packages are loaded
    var packagesLoaded: Bool {
        !packages.isEmpty
    }

    // MARK: - Feature List

    let proFeatures: [(icon: String, title: String)] = [
        ("infinity", "Track Unlimited Subscriptions"),
        ("bell.badge", "Custom Renewal Reminders"),
        ("chart.bar", "Spending Insights & Trends"),
        ("square.and.arrow.up", "Export & Sync Across Devices"),
    ]

    // MARK: - Initialization

    init(trigger: PaywallTrigger, detectedSubscriptionCount: Int? = nil) {
        self.trigger = trigger
        self.detectedSubscriptionCount = detectedSubscriptionCount
    }

    // MARK: - Public Methods

    /// Load offerings if not already loaded
    func loadProductsIfNeeded() async {
        if packages.isEmpty {
            await purchaseService.loadOfferings()
        }
    }

    /// Purchase the selected plan
    func purchase() async {
        // Check if packages are loaded first
        guard packagesLoaded else {
            #if DEBUG
            errorMessage = "RevenueCat offerings not loaded. Make sure your API key is configured in Debug.xcconfig"
            #else
            errorMessage = "Unable to load products. Please check your internet connection and try again."
            #endif
            showError = true
            return
        }

        guard let package = selectedPackage else {
            errorMessage = "Please select a plan"
            showError = true
            return
        }

        isProcessing = true
        errorMessage = nil
        AnalyticsService.event("paywall_purchase_start", params: purchaseAnalyticsParams(productID: package.storeProduct.productIdentifier))

        do {
            try await purchaseService.purchase(package: package)
            AnalyticsService.event("paywall_purchase_success", params: purchaseAnalyticsParams(productID: package.storeProduct.productIdentifier))
            purchaseSuccessful = true
        } catch let error as PurchaseError {
            if case .purchaseCancelled = error {
                // User cancelled, don't show error
                AnalyticsService.event("paywall_purchase_cancelled", params: purchaseAnalyticsParams(productID: package.storeProduct.productIdentifier))
            } else {
                AnalyticsService.event("paywall_purchase_failed", params: purchaseAnalyticsParams(productID: package.storeProduct.productIdentifier, error: error.localizedDescription))
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            AnalyticsService.event("paywall_purchase_failed", params: purchaseAnalyticsParams(productID: package.storeProduct.productIdentifier, error: error.localizedDescription))
            errorMessage = "Purchase failed. Please try again."
            showError = true
        }

        isProcessing = false
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isProcessing = true
        errorMessage = nil
        AnalyticsService.event("paywall_restore_start", params: baseAnalyticsParams())

        do {
            try await purchaseService.restorePurchases()

            if purchaseService.hasActiveSubscription {
                AnalyticsService.event("paywall_restore_success", params: baseAnalyticsParams())
                purchaseSuccessful = true
            } else {
                AnalyticsService.event("paywall_restore_failed", params: baseAnalyticsParams())
                errorMessage = "No active subscription found"
                showError = true
            }
        } catch {
            AnalyticsService.event("paywall_restore_failed", params: baseAnalyticsParams())
            errorMessage = "Could not restore purchases. Please try again."
            showError = true
        }

        isProcessing = false
    }

    /// Get formatted price for display (price only, no period suffix)
    func formattedPrice(for plan: PremiumProduct) -> String? {
        switch plan {
        case .monthly:
            return monthlyPackage?.storeProduct.localizedPriceString
        case .annual:
            return annualPackage?.storeProduct.localizedPriceString
        }
    }

    /// Get period suffix for display (e.g., "/year", "/month")
    func periodSuffix(for plan: PremiumProduct) -> String {
        switch plan {
        case .monthly:
            return "/month"
        case .annual:
            return "/year"
        }
    }

    /// Get monthly equivalent for annual plan (annual price / 12, formatted with same locale)
    func formattedMonthlyEquivalent(for plan: PremiumProduct) -> String? {
        guard plan == .annual,
              let annualProduct = annualPackage?.storeProduct else { return nil }

        let monthlyPrice = annualProduct.price / Decimal(12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = annualProduct.priceFormatter?.locale ?? .current
        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    // MARK: - Analytics Helpers

    private func baseAnalyticsParams() -> [String: Any] {
        var params: [String: Any] = [
            "trigger": trigger.analyticsValue,
            "selected_plan": selectedPlan.analyticsValue,
            "variant": paywallVariant.analyticsValue
        ]

        if let detectedSubscriptionCount {
            params["detected_subscription_count"] = detectedSubscriptionCount
        }

        if case .featureGate(let feature) = trigger {
            params["feature"] = feature
        }

        return params
    }

    private func purchaseAnalyticsParams(productID: String, error: String? = nil) -> [String: Any] {
        var params = baseAnalyticsParams()
        params["product_id"] = productID
        if let error {
            params["error"] = error
        }
        return params
    }
}

extension PaywallTrigger {
    var analyticsValue: String {
        switch self {
        case .onboarding:
            return "onboarding"
        case .subscriptionLimit:
            return "subscription_limit"
        case .featureGate:
            return "feature_gate"
        case .settings:
            return "settings"
        case .rescan:
            return "rescan"
        }
    }
}

extension PremiumProduct {
    var analyticsValue: String {
        switch self {
        case .monthly:
            return "monthly"
        case .annual:
            return "annual"
        }
    }
}
