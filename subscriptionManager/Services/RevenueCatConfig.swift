//
//  RevenueCatConfig.swift
//  subscriptionManager
//
//  Created by Claude on 1/29/26.
//

import Foundation

/// Configuration for RevenueCat SDK
enum RevenueCatConfig {

    /// The RevenueCat public API key
    /// Note: Public SDK keys (appl_, test_) are safe to embed - they're designed for
    /// client apps and only work with your specific bundle ID
    static var apiKey: String {
        #if DEBUG
        return "test_FmFzWpNTEGcUBePMXlcDlKfOIKj"
        #else
        return "appl_AqGPpgCVWDZnZwBDTlCXLgAJBrB"
        #endif
    }

    /// The entitlement identifier for Pro subscription.
    /// ⚠️ This string must be copy-pasted directly from the RevenueCat dashboard
    /// Identifier field using the copy button. Do NOT retype it manually.
    /// Current value needs to be verified — paste from dashboard copy button to confirm.
    static let entitlementID = "Trackit -  Subscription Tracker Pro"

    /// Offering identifiers for A/B testing
    enum OfferingID {
        /// Default offering - shows RevenueCat's PaywallView (Control group)
        static let defaultOffering = "default"

        /// Custom paywall offering - shows your custom PaywallView (Variant group)
        static let customPaywall = "custom_paywall"
    }
}
