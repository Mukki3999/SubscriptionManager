//
//  PaywallContainerView.swift
//  subscriptionManager
//
//  Created by Claude on 1/29/26.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

// MARK: - Paywall Container View

/// Container view that handles A/B testing between custom and RevenueCat paywalls
struct PaywallContainerView: View {

    // MARK: - Properties

    let trigger: PaywallTrigger
    let detectedSubscriptionCount: Int?
    let onContinueFree: (() -> Void)?
    let onPurchaseSuccess: (() -> Void)?

    @StateObject private var viewModel: PaywallViewModel
    @ObservedObject private var purchaseService = RevenueCatPurchaseService.shared
    @Environment(\.dismiss) private var dismiss


    // MARK: - Initialization

    init(
        trigger: PaywallTrigger,
        detectedSubscriptionCount: Int? = nil,
        onContinueFree: (() -> Void)? = nil,
        onPurchaseSuccess: (() -> Void)? = nil
    ) {
        self.trigger = trigger
        self.detectedSubscriptionCount = detectedSubscriptionCount
        self.onContinueFree = onContinueFree
        self.onPurchaseSuccess = onPurchaseSuccess
        _viewModel = StateObject(wrappedValue: PaywallViewModel(
            trigger: trigger,
            detectedSubscriptionCount: detectedSubscriptionCount
        ))
    }

    // MARK: - Body

    var body: some View {
        paywallForVariant(resolvedVariant)
            .onAppear {
                #if DEBUG
                print("PaywallContainerView: variant=\(purchaseService.currentPaywallVariant?.rawValue ?? "nil"), offering=\(purchaseService.currentOffering?.identifier ?? "nil"), resolved=\(resolvedVariant.rawValue)")
                #endif
                trackPaywallView()
            }
    }

    /// Resolves which paywall variant to show
    private var resolvedVariant: PaywallVariant {
        #if DEBUG
        // Allow forcing a variant in debug builds for testing
        if let forced = debugForceVariant {
            return forced
        }
        #endif

        // Use A/B test assignment from RevenueCat
        if let variant = purchaseService.currentPaywallVariant {
            return variant
        }

        // Fallback: determine variant from current offering if available
        // This handles the case where offerings loaded but variant wasn't set
        if let offering = purchaseService.currentOffering {
            if offering.identifier == RevenueCatConfig.OfferingID.customPaywall {
                return .custom
            } else {
                return .revenueCat
            }
        }

        // Last resort: offerings not loaded yet, default to custom
        // Custom paywall handles product loading gracefully with fallback prices
        return .custom
    }

    // MARK: - Paywall Selection

    @ViewBuilder
    private func paywallForVariant(_ variant: PaywallVariant) -> some View {
        switch variant {
        case .revenueCat:
            if let offering = purchaseService.currentOffering {
                // Use RevenueCat's PaywallView with the current offering
                revenueCatPaywall(offering: offering)
            } else {
                // Edge case: variant is revenueCat but no offering
                // Fall back to custom paywall
                CustomPaywallView(
                    viewModel: viewModel,
                    onContinueFree: onContinueFree,
                    onPurchaseSuccess: onPurchaseSuccess
                )
            }
        case .custom:
            CustomPaywallView(
                viewModel: viewModel,
                onContinueFree: onContinueFree,
                onPurchaseSuccess: onPurchaseSuccess
            )
        }
    }

    // MARK: - Debug Helper
    #if DEBUG
    /// Temporarily force a specific variant for testing
    /// Set to nil to use A/B test assignment
    private var debugForceVariant: PaywallVariant? {
        // Uncomment one of these to force a specific paywall for testing:
        // return .custom      // Force custom Swift paywall
        // return .revenueCat  // Force RevenueCat paywall
        return nil  // Use A/B test assignment
    }
    #endif

    // MARK: - RevenueCat Paywall

    @ViewBuilder
    private func revenueCatPaywall(offering: Offering) -> some View {
        PaywallView(offering: offering)
            .onPurchaseCompleted { customerInfo in
                AnalyticsService.event("paywall_purchase_success", params: analyticsParams(extra: [
                    "source": "revenuecat_ui"
                ]))
                onPurchaseSuccess?()
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                let hasEntitlement = customerInfo.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
                if hasEntitlement {
                    AnalyticsService.event("paywall_restore_success", params: analyticsParams(extra: [
                        "source": "revenuecat_ui"
                    ]))
                    onPurchaseSuccess?()
                    dismiss()
                }
            }
    }

    // MARK: - Analytics

    private func trackPaywallView() {
        AnalyticsService.screen("paywall")
        AnalyticsService.event("paywall_view", params: analyticsParams())
    }

    private func analyticsParams(extra: [String: Any] = [:]) -> [String: Any] {
        var params: [String: Any] = [
            "trigger": trigger.analyticsValue,
            "variant": purchaseService.currentPaywallVariant?.analyticsValue ?? "unknown"
        ]

        if let detectedSubscriptionCount {
            params["detected_subscription_count"] = detectedSubscriptionCount
        }

        if case .featureGate(let feature) = trigger {
            params["feature"] = feature
        }

        // Merge extra params
        for (key, value) in extra {
            params[key] = value
        }

        return params
    }
}

// MARK: - Preview

#Preview {
    PaywallContainerView(
        trigger: .onboarding,
        detectedSubscriptionCount: 12,
        onContinueFree: { print("Continue free") },
        onPurchaseSuccess: { print("Purchase success") }
    )
}
