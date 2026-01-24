//
//  PaywallViewModel.swift
//  subscriptionManager
//
//  Created by Claude on 1/19/26.
//

import Foundation
import StoreKit
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

    private let purchaseService = PurchaseService.shared

    // MARK: - Computed Properties

    var products: [Product] {
        purchaseService.products
    }

    var monthlyProduct: Product? {
        purchaseService.getMonthlyProduct()
    }

    var annualProduct: Product? {
        purchaseService.getAnnualProduct()
    }

    var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly:
            return monthlyProduct
        case .annual:
            return annualProduct
        }
    }

    var hasFreeTrial: Bool {
        selectedProduct?.hasFreeTrial ?? false
    }

    var freeTrialText: String? {
        selectedProduct?.freeTrialDuration
    }

    var isLoading: Bool {
        purchaseService.isLoading || isProcessing
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

    /// Load products if not already loaded
    func loadProductsIfNeeded() async {
        if products.isEmpty {
            await purchaseService.loadProducts()
        }
    }

    /// Purchase the selected plan
    func purchase() async {
        guard let product = selectedProduct else {
            errorMessage = "Please select a plan"
            showError = true
            return
        }

        isProcessing = true
        errorMessage = nil
        AnalyticsService.event("paywall_purchase_start", params: purchaseAnalyticsParams(productID: product.id))

        do {
            try await purchaseService.purchase(product)
            AnalyticsService.event("paywall_purchase_success", params: purchaseAnalyticsParams(productID: product.id))
            purchaseSuccessful = true
        } catch let error as PurchaseError {
            if case .purchaseCancelled = error {
                // User cancelled, don't show error
                AnalyticsService.event("paywall_purchase_cancelled", params: purchaseAnalyticsParams(productID: product.id))
            } else {
                AnalyticsService.event("paywall_purchase_failed", params: purchaseAnalyticsParams(productID: product.id, error: error.localizedDescription))
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            AnalyticsService.event("paywall_purchase_failed", params: purchaseAnalyticsParams(productID: product.id, error: error.localizedDescription))
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

    /// Get formatted price for display
    func formattedPrice(for plan: PremiumProduct) -> String {
        switch plan {
        case .monthly:
            return monthlyProduct?.formattedPriceWithPeriod ?? plan.formattedPrice
        case .annual:
            return annualProduct?.formattedPriceWithPeriod ?? plan.formattedPrice
        }
    }

    /// Get monthly equivalent for annual plan
    func monthlyEquivalent(for plan: PremiumProduct) -> String? {
        guard plan == .annual else { return nil }
        return annualProduct?.monthlyEquivalent.map { "\($0)/mo" }
    }

    // MARK: - Analytics Helpers

    private func baseAnalyticsParams() -> [String: Any] {
        var params: [String: Any] = [
            "trigger": trigger.analyticsValue,
            "selected_plan": selectedPlan.analyticsValue
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
