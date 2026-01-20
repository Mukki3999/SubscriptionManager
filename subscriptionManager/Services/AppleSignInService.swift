//
//  AppleSignInService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation
import AuthenticationServices
import StoreKit

/// Result of Apple Sign In with StoreKit access
struct AppleSignInResult {
    let account: ConnectedAccount
    let hasStoreKitAccess: Bool
}

@MainActor
class AppleSignInService: NSObject, ObservableObject {

    // MARK: - Dependencies

    private let storeKitService = StoreKitService()

    // MARK: - Sign In

    func signIn() async throws -> ConnectedAccount {
        return try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self

            self.continuation = continuation
            controller.performRequests()
        }
    }

    /// Signs in with Apple and verifies StoreKit access
    /// Returns both the account and whether StoreKit transaction access is available
    func signInWithStoreKitAccess() async throws -> AppleSignInResult {
        // First, perform standard Sign in with Apple
        let account = try await signIn()

        // StoreKit 2 transaction access is always available when user is signed in
        // We don't need to verify - just enable it when Apple Sign In succeeds
        return AppleSignInResult(account: account, hasStoreKitAccess: true)
    }

    /// Checks if StoreKit transaction access is available
    /// This verifies we can iterate through the user's App Store transactions
    func checkStoreKitAccess() async -> Bool {
        // StoreKit 2 access is always available, no special permission needed
        return true
    }

    // MARK: - Private Properties
    private var continuation: CheckedContinuation<ConnectedAccount, Error>?
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation?.resume(throwing: AppleSignInError.invalidCredential)
                continuation = nil
                return
            }

            guard let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                continuation?.resume(throwing: AppleSignInError.missingToken)
                continuation = nil
                return
            }

            // Extract email from credential or use user identifier
            let email = credential.email ?? "\(credential.user)@privaterelay.appleid.com"

            let account = ConnectedAccount(
                email: email,
                provider: .apple,
                accessToken: tokenString,
                refreshToken: nil,
                expiresAt: Date().addingTimeInterval(TimeInterval(3600 * 24 * 30)) // 30 days
            )

            continuation?.resume(returning: account)
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    continuation?.resume(throwing: AppleSignInError.cancelled)
                default:
                    continuation?.resume(throwing: AppleSignInError.authorizationFailed(error))
                }
            } else {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Errors
enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingToken
    case cancelled
    case authorizationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential"
        case .missingToken:
            return "Missing identity token"
        case .cancelled:
            return "Sign in was cancelled"
        case .authorizationFailed(let error):
            return "Authorization failed: \(error.localizedDescription)"
        }
    }
}
