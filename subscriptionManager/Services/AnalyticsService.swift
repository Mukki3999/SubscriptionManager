//
//  AnalyticsService.swift
//  subscriptionManager
//
//  Created by Codex on 1/22/26.
//

import Foundation
import FirebaseAnalytics

enum AnalyticsService {

    static func screen(_ name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name
        ])
    }

    static func event(_ name: String, params: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: params)
    }

    static func setUserProperty(_ value: String?, for name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
