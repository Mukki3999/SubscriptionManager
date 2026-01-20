//
//  CancellationInfo.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation

// MARK: - Subscription Management Type

enum SubscriptionManagementType: String, Codable {
    case appStore = "app_store"
    case web = "web"
    case unknown = "unknown"
}

// MARK: - Cancellation Info Model

struct CancellationInfo: Identifiable, Codable {
    let id: String  // matches merchantId
    let type: SubscriptionManagementType
    let cancelURL: String?
    let steps: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case cancelURL = "cancel_url"
        case steps
    }
}

// MARK: - Cancellation Info Response

struct CancellationInfoResponse: Codable {
    let services: [CancellationInfo]
}
