//
//  URLLaunchService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation
import UIKit

// MARK: - URL Launch Service

struct URLLaunchService {

    // MARK: - Constants

    /// URL to open App Store subscription management
    static let appStoreSubscriptionsURL = URL(string: "itms-apps://apps.apple.com/account/subscriptions")!

    // MARK: - Public Methods

    /// Open the App Store subscription management page
    @MainActor
    static func openAppStoreSubscriptions() {
        UIApplication.shared.open(appStoreSubscriptionsURL)
    }

    /// Open a URL in Safari
    /// - Parameter url: The URL to open
    @MainActor
    static func openInSafari(_ url: URL) {
        UIApplication.shared.open(url)
    }

    /// Open a URL string in Safari
    /// - Parameter urlString: The URL string to open
    /// - Returns: True if the URL was valid and opened, false otherwise
    @MainActor
    @discardableResult
    static func openInSafari(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        UIApplication.shared.open(url)
        return true
    }
}
