//
//  PKCEHelper.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation
import CryptoKit

/// Helper class for PKCE (Proof Key for Code Exchange) implementation.
///
/// PKCE is an extension to the OAuth 2.0 authorization code flow that provides
/// additional security for public clients (like mobile apps) that cannot securely
/// store client secrets.
///
/// ## How PKCE Works
/// 1. Generate a random `code_verifier` (high-entropy cryptographic string)
/// 2. Create a `code_challenge` by hashing the verifier with SHA256
/// 3. Send the `code_challenge` in the authorization request
/// 4. Send the `code_verifier` when exchanging the authorization code for tokens
/// 5. The server verifies that SHA256(code_verifier) == code_challenge
///
/// This prevents authorization code interception attacks because an attacker
/// who intercepts the authorization code cannot exchange it for tokens without
/// knowing the original code_verifier.
///
/// - SeeAlso: [RFC 7636](https://tools.ietf.org/html/rfc7636)
struct PKCEHelper {

    // MARK: - Properties

    /// The code verifier: a cryptographically random string
    /// Length: 43-128 characters (we use 64)
    let codeVerifier: String

    /// The code challenge: Base64URL-encoded SHA256 hash of the code verifier
    let codeChallenge: String

    /// The challenge method used (always S256 for SHA256)
    let codeChallengeMethod = "S256"

    // MARK: - Initialization

    /// Creates a new PKCE helper with fresh cryptographic values
    init() {
        self.codeVerifier = PKCEHelper.generateCodeVerifier()
        self.codeChallenge = PKCEHelper.generateCodeChallenge(from: codeVerifier)
    }

    // MARK: - Private Methods

    /// Generates a cryptographically secure code verifier
    ///
    /// The code verifier is a high-entropy cryptographic random string using
    /// unreserved characters: [A-Z] / [a-z] / [0-9] / "-" / "." / "_" / "~"
    ///
    /// - Returns: A 64-character random string suitable for use as a code verifier
    private static func generateCodeVerifier() -> String {
        // Generate 32 random bytes (256 bits of entropy)
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        guard result == errSecSuccess else {
            // Fallback to UUID-based generation if SecRandomCopyBytes fails
            return UUID().uuidString.replacingOccurrences(of: "-", with: "") +
                   UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        // Base64URL encode (no padding)
        let data = Data(randomBytes)
        return data.base64URLEncodedString()
    }

    /// Generates a code challenge from the code verifier using SHA256
    ///
    /// The code challenge is computed as:
    /// `BASE64URL(SHA256(code_verifier))`
    ///
    /// - Parameter codeVerifier: The code verifier to hash
    /// - Returns: The Base64URL-encoded SHA256 hash of the code verifier
    private static func generateCodeChallenge(from codeVerifier: String) -> String {
        guard let verifierData = codeVerifier.data(using: .ascii) else {
            fatalError("Code verifier must contain only ASCII characters")
        }

        // Compute SHA256 hash using CryptoKit
        let hash = SHA256.hash(data: verifierData)

        // Convert hash to Data and Base64URL encode
        let hashData = Data(hash)
        return hashData.base64URLEncodedString()
    }
}

// MARK: - Data Extension for Base64URL Encoding

extension Data {
    /// Returns a Base64URL-encoded string (RFC 4648)
    ///
    /// Base64URL differs from standard Base64:
    /// - Uses `-` instead of `+`
    /// - Uses `_` instead of `/`
    /// - No padding (`=`) characters
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
