//
//  ConnectedAccount.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation

enum EmailProvider: String, Codable {
    case gmail = "Gmail"
    case apple = "Apple"

    var displayName: String {
        return rawValue
    }

    var iconName: String {
        switch self {
        case .gmail:
            return "envelope.fill"
        case .apple:
            return "applelogo"
        }
    }
}

struct ConnectedAccount: Identifiable, Codable {
    let id: UUID
    let email: String
    let provider: EmailProvider
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    init(email: String, provider: EmailProvider, accessToken: String, refreshToken: String? = nil, expiresAt: Date) {
        self.id = UUID()
        self.email = email
        self.provider = provider
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
