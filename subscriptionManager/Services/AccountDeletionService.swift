//
//  AccountDeletionService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 2/8/26.
//

import Foundation

/// Service responsible for complete account deletion and data cleanup
/// Implements Apple's account deletion requirements
@MainActor
final class AccountDeletionService {

    // MARK: - Singleton

    static let shared = AccountDeletionService()

    // MARK: - Services

    private let keychain = KeychainService.shared
    private let googleOAuth = GoogleOAuthService()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Deletes all user data from the app
    ///
    /// This includes:
    /// - All connected accounts (Gmail, Apple)
    /// - All OAuth tokens
    /// - Profile images
    /// - Gmail message cache
    /// - Gmail sync state
    /// - All subscriptions
    /// - All UserDefaults data
    ///
    /// - Returns: A result indicating success or failure with error details
    func deleteAllUserData() async -> Result<Void, AccountDeletionError> {
        do {
            // 1. Revoke OAuth tokens (best effort - don't fail if this fails)
            await revokeOAuthTokens()

            // 2. Clear Keychain
            keychain.clearAll()

            // 3. Clear Gmail cache
            await clearGmailCache()

            // 4. Clear Gmail sync state
            await clearGmailSyncState()

            // 5. Clear UserDefaults (this clears subscriptions, accounts, profile, etc.)
            clearUserDefaults()

            // 6. Post notification to reset app to onboarding
            NotificationCenter.default.post(name: .accountDeleted, object: nil)

            return .success(())

        } catch {
            return .failure(.deletionFailed(reason: error.localizedDescription))
        }
    }

    // MARK: - Private Methods

    /// Revokes OAuth tokens with providers (best effort)
    private func revokeOAuthTokens() async {
        // Revoke Google tokens
        do {
            try await googleOAuth.signOut()
        } catch {
            // Continue even if revocation fails
            print("Failed to revoke Google tokens: \(error)")
        }

        // Note: Apple Sign In tokens don't need explicit revocation
    }

    /// Clears all user-related data from UserDefaults
    private func clearUserDefaults() {
        let defaults = UserDefaults.standard

        // Get all keys and remove them
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }

        // Reset the hasLaunchedBefore flag so app behaves as fresh install
        defaults.set(false, forKey: "hasLaunchedBefore")
        defaults.synchronize()
    }

    /// Clears Gmail message cache
    private func clearGmailCache() async {
        await GmailMessageCache.shared.clear()
    }

    /// Clears Gmail sync state
    private func clearGmailSyncState() async {
        await GmailSyncStateManager.shared.clearState()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user account is deleted, signals app to reset to onboarding
    static let accountDeleted = Notification.Name("accountDeleted")
}

// MARK: - Errors

enum AccountDeletionError: LocalizedError {
    case deletionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .deletionFailed(let reason):
            return "Failed to delete account data: \(reason)"
        }
    }
}
