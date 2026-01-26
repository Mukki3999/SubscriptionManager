//
//  MockKeychainService.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation
@testable import subscriptionManager

/// Mock keychain service for testing OAuth flows
final class MockKeychainService {

    // MARK: - Storage

    private var storage: [String: Data] = [:]

    // MARK: - Token State Configuration

    enum TokenState {
        case valid
        case expired
        case expiringSoon
        case missing
        case noRefreshToken
    }

    var googleTokenState: TokenState = .valid

    // MARK: - Test Data

    private let testAccessToken = "mock_access_token_12345"
    private let testRefreshToken = "mock_refresh_token_67890"
    private let testEmail = "test@gmail.com"

    // MARK: - Initialization

    init(tokenState: TokenState = .valid) {
        self.googleTokenState = tokenState
        setupTokens()
    }

    // MARK: - Public Methods

    /// Save a string value
    func save(_ value: String, forKey key: KeychainService.Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainService.KeychainError.encodingFailed
        }
        storage[key.rawValue] = data
    }

    /// Save data
    func save(_ data: Data, forKey key: KeychainService.Key) throws {
        storage[key.rawValue] = data
    }

    /// Get a string value
    func getString(forKey key: KeychainService.Key) -> String? {
        guard let data = storage[key.rawValue] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Get data
    func getData(forKey key: KeychainService.Key) -> Data? {
        storage[key.rawValue]
    }

    /// Delete a value
    func delete(forKey key: KeychainService.Key) {
        storage.removeValue(forKey: key.rawValue)
    }

    /// Clear all Google tokens
    func clearGoogleTokens() {
        delete(forKey: .googleAccessToken)
        delete(forKey: .googleRefreshToken)
        delete(forKey: .googleTokenExpiry)
        delete(forKey: .googleUserEmail)
    }

    /// Clear all tokens
    func clearAll() {
        storage.removeAll()
    }

    /// Store Google tokens
    func storeGoogleTokens(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date,
        email: String
    ) throws {
        try save(accessToken, forKey: .googleAccessToken)

        if let refreshToken = refreshToken {
            try save(refreshToken, forKey: .googleRefreshToken)
        }

        let expiryString = ISO8601DateFormatter().string(from: expiresAt)
        try save(expiryString, forKey: .googleTokenExpiry)
        try save(email, forKey: .googleUserEmail)
    }

    /// Get Google tokens
    func getGoogleTokens() -> (accessToken: String, refreshToken: String?, expiresAt: Date, email: String)? {
        switch googleTokenState {
        case .missing:
            return nil

        case .valid:
            return (
                testAccessToken,
                testRefreshToken,
                Date().addingTimeInterval(3600), // 1 hour from now
                testEmail
            )

        case .expired:
            return (
                testAccessToken,
                testRefreshToken,
                Date().addingTimeInterval(-3600), // 1 hour ago
                testEmail
            )

        case .expiringSoon:
            return (
                testAccessToken,
                testRefreshToken,
                Date().addingTimeInterval(120), // 2 minutes from now
                testEmail
            )

        case .noRefreshToken:
            return (
                testAccessToken,
                nil,
                Date().addingTimeInterval(-3600),
                testEmail
            )
        }
    }

    /// Check if tokens are valid
    var hasValidGoogleTokens: Bool {
        switch googleTokenState {
        case .valid, .expiringSoon:
            return true
        case .expired, .missing, .noRefreshToken:
            return false
        }
    }

    /// Check if tokens need refresh
    var googleTokensNeedRefresh: Bool {
        switch googleTokenState {
        case .valid:
            return false
        case .expired, .expiringSoon, .noRefreshToken:
            return true
        case .missing:
            return true
        }
    }

    // MARK: - Private Methods

    private func setupTokens() {
        guard googleTokenState != .missing else { return }

        try? save(testAccessToken, forKey: .googleAccessToken)
        try? save(testEmail, forKey: .googleUserEmail)

        if googleTokenState != .noRefreshToken {
            try? save(testRefreshToken, forKey: .googleRefreshToken)
        }

        let expiryDate: Date
        switch googleTokenState {
        case .valid:
            expiryDate = Date().addingTimeInterval(3600)
        case .expired:
            expiryDate = Date().addingTimeInterval(-3600)
        case .expiringSoon:
            expiryDate = Date().addingTimeInterval(120)
        default:
            expiryDate = Date()
        }

        let expiryString = ISO8601DateFormatter().string(from: expiryDate)
        try? save(expiryString, forKey: .googleTokenExpiry)
    }

    // MARK: - Test Helpers

    /// Reset to initial state
    func reset(tokenState: TokenState = .valid) {
        storage.removeAll()
        self.googleTokenState = tokenState
        setupTokens()
    }

    /// Simulate token expiration
    func expireTokens() {
        googleTokenState = .expired
        let expiryString = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        try? save(expiryString, forKey: .googleTokenExpiry)
    }

    /// Simulate successful token refresh
    func simulateTokenRefresh() {
        googleTokenState = .valid
        let expiryString = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        try? save(expiryString, forKey: .googleTokenExpiry)
    }
}
