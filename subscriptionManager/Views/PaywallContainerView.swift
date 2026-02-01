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
    @StateObject private var purchaseService = RevenueCatPurchaseService.shared
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
        Group {
            if purchaseService.shouldShowRevenueCatPaywall,
               let offering = purchaseService.currentOffering {
                // RevenueCat Paywall (Variant B)
                revenueCatPaywall(offering: offering)
            } else {
                // Custom Paywall (Control / Variant A)
                CustomPaywallView(
                    viewModel: viewModel,
                    onContinueFree: onContinueFree,
                    onPurchaseSuccess: onPurchaseSuccess
                )
            }
        }
        .onAppear {
            trackPaywallView()
        }
    }

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
            "variant": purchaseService.currentPaywallVariant.analyticsValue
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
