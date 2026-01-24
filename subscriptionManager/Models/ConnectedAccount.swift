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

    // Only persist non-sensitive account metadata.
    enum CodingKeys: String, CodingKey {
        case id, email, provider, expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        provider = try container.decode(EmailProvider.self, forKey: .provider)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        accessToken = ""
        refreshToken = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(provider, forKey: .provider)
        try container.encode(expiresAt, forKey: .expiresAt)
    }
}
