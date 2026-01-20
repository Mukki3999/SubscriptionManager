//
//  KeychainService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation
import Security

/// A secure service for storing and retrieving sensitive data using iOS Keychain.
/// Follows Apple's security best practices for credential storage.
final class KeychainService {

    // MARK: - Singleton

    static let shared = KeychainService()

    private init() {}

    // MARK: - Keychain Keys

    enum Key: String {
        case googleAccessToken = "com.subscriptionManager.google.accessToken"
        case googleRefreshToken = "com.subscriptionManager.google.refreshToken"
        case googleTokenExpiry = "com.subscriptionManager.google.tokenExpiry"
        case googleUserEmail = "com.subscriptionManager.google.userEmail"
        case appleIdentityToken = "com.subscriptionManager.apple.identityToken"
        case appleUserEmail = "com.subscriptionManager.apple.userEmail"
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            case .invalidData:
                return "Invalid data retrieved from Keychain"
            case .encodingFailed:
                return "Failed to encode data for Keychain"
            }
        }
    }

    // MARK: - Public Methods

    /// Saves a string value to the Keychain
    /// - Parameters:
    ///   - value: The string to store
    ///   - key: The key to associate with the value
    func save(_ value: String, forKey key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data, forKey: key)
    }

    /// Saves data to the Keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to associate with the data
    func save(_ data: Data, forKey key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves a string value from the Keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The stored string, or nil if not found
    func getString(forKey key: Key) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Retrieves data from the Keychain
    /// - Parameter key: The key associated with the data
    /// - Returns: The stored data, or nil if not found
    func getData(forKey key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Deletes a value from the Keychain
    /// - Parameter key: The key associated with the value to delete
    func delete(forKey key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Deletes all Google OAuth tokens from Keychain
    func clearGoogleTokens() {
        delete(forKey: .googleAccessToken)
        delete(forKey: .googleRefreshToken)
        delete(forKey: .googleTokenExpiry)
        delete(forKey: .googleUserEmail)
    }

    /// Deletes all Apple tokens from Keychain
    func clearAppleTokens() {
        delete(forKey: .appleIdentityToken)
        delete(forKey: .appleUserEmail)
    }

    /// Deletes all stored tokens
    func clearAll() {
        clearGoogleTokens()
        clearAppleTokens()
    }

    // MARK: - Convenience Methods for Token Storage

    /// Stores Google OAuth tokens securely
    /// - Parameters:
    ///   - accessToken: The access token from Google
    ///   - refreshToken: The refresh token from Google (optional)
    ///   - expiresAt: The expiration date of the access token
    ///   - email: The user's email address
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

    /// Retrieves stored Google tokens
    /// - Returns: A tuple containing the access token, refresh token, expiry date, and email
    func getGoogleTokens() -> (accessToken: String, refreshToken: String?, expiresAt: Date, email: String)? {
        guard let accessToken = getString(forKey: .googleAccessToken),
              let expiryString = getString(forKey: .googleTokenExpiry),
              let expiresAt = ISO8601DateFormatter().date(from: expiryString),
              let email = getString(forKey: .googleUserEmail) else {
            return nil
        }

        let refreshToken = getString(forKey: .googleRefreshToken)
        return (accessToken, refreshToken, expiresAt, email)
    }

    /// Checks if Google tokens are stored and valid
    var hasValidGoogleTokens: Bool {
        guard let tokens = getGoogleTokens() else { return false }
        return tokens.expiresAt > Date()
    }

    /// Checks if Google tokens need refresh (expired or expiring within 5 minutes)
    var googleTokensNeedRefresh: Bool {
        guard let tokens = getGoogleTokens() else { return true }
        let bufferTime: TimeInterval = 5 * 60 // 5 minutes
        return tokens.expiresAt.timeIntervalSinceNow < bufferTime
    }
}
