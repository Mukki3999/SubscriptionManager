//
//  RevenueCatConfig.swift
//  subscriptionManager
//
//  Created by Claude on 1/29/26.
//

import Foundation

/// Configuration for RevenueCat SDK
enum RevenueCatConfig {

    /// The RevenueCat API key (read from Info.plist, configured via xcconfig)
    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String,
           !key.isEmpty,
           !key.hasPrefix("$("),
           !key.contains("YOUR_") {
            return key
        }
        #if DEBUG
        assertionFailure("RevenueCat API key not configured. Copy Secrets.xcconfig.template to Debug.xcconfig and add your key.")
        #endif
        return ""
    }

    /// The entitlement identifier for Pro subscription
    static let entitlementID = "Trackit - Subscription Tracker Pro"

    /// Offering identifiers for A/B testing
    enum OfferingID {
        /// Default offering - shows RevenueCat's PaywallView (Control group)
        static let defaultOffering = "default"

        /// Custom paywall offering - shows your custom PaywallView (Variant group)
        static let customPaywall = "custom_paywall"
    }
}
