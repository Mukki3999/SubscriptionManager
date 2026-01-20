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
            return "Free accounts can track up to 5 subscriptions"
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

        do {
            try await purchaseService.purchase(product)
            purchaseSuccessful = true
        } catch let error as PurchaseError {
            if case .purchaseCancelled = error {
                // User cancelled, don't show error
            } else {
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            showError = true
        }

        isProcessing = false
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isProcessing = true
        errorMessage = nil

        do {
            try await purchaseService.restorePurchases()

            if purchaseService.hasActiveSubscription {
                purchaseSuccessful = true
            } else {
                errorMessage = "No active subscription found"
                showError = true
            }
        } catch {
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
}
