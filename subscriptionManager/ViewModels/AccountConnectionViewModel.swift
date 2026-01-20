//
//  AccountConnectionViewModel.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation
import SwiftUI

/// ViewModel for managing email account connections.
///
/// Handles authentication flows for Google and Apple accounts,
/// manages connected account state, and provides access to Gmail API.
@MainActor
class AccountConnectionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var connectedAccounts: [ConnectedAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasStoreKitAccess = false

    // MARK: - Services

    private let googleOAuthService = GoogleOAuthService()
    private let appleSignInService = AppleSignInService()
    private let gmailAPIService = GmailAPIService()
    private let storeKitService = StoreKitService()
    private let keychain = KeychainService.shared

    // MARK: - Storage Key

    private let accountsStorageKey = "connectedAccounts"
    private let storeKitAccessKey = "hasStoreKitAccess"

    // MARK: - Initialization

    init() {
        loadSavedAccounts()
        syncWithKeychain()
        loadStoreKitAccessStatus()
    }

    // MARK: - Computed Properties

    var hasConnectedAccounts: Bool {
        !connectedAccounts.isEmpty
    }

    var gmailAccount: ConnectedAccount? {
        connectedAccounts.first { $0.provider == .gmail }
    }

    var appleAccount: ConnectedAccount? {
        connectedAccounts.first { $0.provider == .apple }
    }

    /// Checks if Gmail account needs token refresh
    var gmailNeedsRefresh: Bool {
        keychain.googleTokensNeedRefresh
    }

    /// Checks if we can scan StoreKit (Apple account connected with StoreKit access)
    var canScanStoreKit: Bool {
        appleAccount != nil && hasStoreKitAccess
    }

    // MARK: - Authentication Methods

    /// Initiates Google OAuth sign-in flow
    func connectGmail() async {
        isLoading = true
        errorMessage = nil

        do {
            let account = try await googleOAuthService.signIn()
            addAccount(account)
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    /// Initiates Apple Sign-In flow with StoreKit access verification
    func connectApple() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await appleSignInService.signInWithStoreKitAccess()
            addAccount(result.account)
            hasStoreKitAccess = result.hasStoreKitAccess
            saveStoreKitAccessStatus()
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    /// Signs out from Gmail and removes the account
    func disconnectGmail() async {
        isLoading = true

        do {
            try await googleOAuthService.signOut()

            if let account = gmailAccount {
                removeAccount(account)
            }
        } catch {
            // Still remove local account even if revocation fails
            if let account = gmailAccount {
                removeAccount(account)
            }
        }

        isLoading = false
    }

    // MARK: - Account Management

    func removeAccount(_ account: ConnectedAccount) {
        connectedAccounts.removeAll { $0.id == account.id }

        // Clear Keychain for the provider
        if account.provider == .gmail {
            keychain.clearGoogleTokens()
        } else if account.provider == .apple {
            keychain.clearAppleTokens()
        }

        saveAccounts()
    }

    private func addAccount(_ account: ConnectedAccount) {
        // Remove existing account for same provider
        connectedAccounts.removeAll { $0.provider == account.provider }

        // Add new account
        connectedAccounts.append(account)
        saveAccounts()
    }

    // MARK: - Token Management

    /// Returns a valid access token for Gmail API calls, refreshing if necessary
    func getValidGmailToken() async throws -> String {
        return try await googleOAuthService.getValidAccessToken()
    }

    /// Refreshes the Gmail access token if needed
    func refreshGmailTokenIfNeeded() async throws {
        guard gmailNeedsRefresh else { return }

        guard let tokens = keychain.getGoogleTokens(),
              let refreshToken = tokens.refreshToken else {
            throw AccountError.noRefreshToken
        }

        _ = try await googleOAuthService.refreshAccessToken(refreshToken: refreshToken)

        // Update the stored account with new token
        if let updatedTokens = keychain.getGoogleTokens() {
            let updatedAccount = ConnectedAccount(
                email: updatedTokens.email,
                provider: .gmail,
                accessToken: updatedTokens.accessToken,
                refreshToken: updatedTokens.refreshToken,
                expiresAt: updatedTokens.expiresAt
            )
            addAccount(updatedAccount)
        }
    }

    // MARK: - Persistence

    private func loadSavedAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsStorageKey) else { return }

        do {
            connectedAccounts = try JSONDecoder().decode([ConnectedAccount].self, from: data)
        } catch {
            print("Failed to load saved accounts: \(error)")
        }
    }

    private func saveAccounts() {
        do {
            let data = try JSONEncoder().encode(connectedAccounts)
            UserDefaults.standard.set(data, forKey: accountsStorageKey)
        } catch {
            print("Failed to save accounts: \(error)")
        }
    }

    private func loadStoreKitAccessStatus() {
        // If Apple account is connected, StoreKit access is always available
        if appleAccount != nil {
            hasStoreKitAccess = true
            saveStoreKitAccessStatus()
        } else {
            hasStoreKitAccess = UserDefaults.standard.bool(forKey: storeKitAccessKey)
        }
    }

    private func saveStoreKitAccessStatus() {
        UserDefaults.standard.set(hasStoreKitAccess, forKey: storeKitAccessKey)
    }

    /// Syncs account state with Keychain tokens
    private func syncWithKeychain() {
        // Check if we have Keychain tokens but no account
        if let tokens = keychain.getGoogleTokens(), gmailAccount == nil {
            let account = ConnectedAccount(
                email: tokens.email,
                provider: .gmail,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresAt: tokens.expiresAt
            )
            addAccount(account)
        }

        // Remove account if Keychain tokens are missing
        if keychain.getGoogleTokens() == nil, let account = gmailAccount {
            connectedAccounts.removeAll { $0.id == account.id }
            saveAccounts()
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        // Don't show error for user cancellation
        if let googleError = error as? GoogleOAuthError {
            switch googleError {
            case .userCancelled:
                return
            default:
                break
            }
        }

        if let appleError = error as? AppleSignInError {
            switch appleError {
            case .cancelled:
                return
            default:
                break
            }
        }

        errorMessage = error.localizedDescription
    }

    // MARK: - Gmail API Methods

    /// Searches Gmail messages with automatic token refresh
    func searchGmailMessages(query: String) async throws -> [GmailMessage] {
        let token = try await getValidGmailToken()
        return try await gmailAPIService.searchMessages(accessToken: token, query: query)
    }

    /// Lists Gmail messages with automatic token refresh
    func listGmailMessages(maxResults: Int = 100) async throws -> [GmailMessage] {
        let token = try await getValidGmailToken()
        return try await gmailAPIService.listMessages(accessToken: token, maxResults: maxResults)
    }
}

// MARK: - Errors

enum AccountError: LocalizedError {
    case noGmailAccount
    case noRefreshToken
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .noGmailAccount:
            return "No Gmail account connected"
        case .noRefreshToken:
            return "No refresh token available. Please sign in again."
        case .tokenExpired:
            return "Session expired. Please sign in again."
        }
    }
}
