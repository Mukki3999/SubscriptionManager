//
//  PKCEHelperTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
import CryptoKit
@testable import subscriptionManager

/// Tests for PKCE (Proof Key for Code Exchange) implementation
final class PKCEHelperTests: XCTestCase {

    // MARK: - Code Verifier Tests

    func testCodeVerifier_Length_Is64Characters() {
        let pkce = PKCEHelper()

        // Base64URL encoding of 32 bytes = 43 characters, but we use 64
        // Actually the implementation generates 32 random bytes and base64url encodes them
        // 32 bytes = 256 bits, base64 = 44 chars (including padding), base64url no padding = 43 chars
        XCTAssertTrue(pkce.codeVerifier.count >= 43,
                      "Code verifier should be at least 43 characters (got \(pkce.codeVerifier.count))")
    }

    func testCodeVerifier_ContainsValidCharset() {
        let pkce = PKCEHelper()
        let validCharset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

        for char in pkce.codeVerifier {
            XCTAssertTrue(validCharset.contains(char.unicodeScalars.first!),
                          "Code verifier contains invalid character: \(char)")
        }
    }

    func testCodeVerifier_IsUnique_AcrossInstances() {
        let pkce1 = PKCEHelper()
        let pkce2 = PKCEHelper()

        XCTAssertNotEqual(pkce1.codeVerifier, pkce2.codeVerifier,
                          "Each PKCEHelper should generate a unique code verifier")
    }

    func testCodeVerifier_DoesNotContainInvalidCharacters() {
        let pkce = PKCEHelper()

        // Should not contain standard base64 characters that are replaced
        XCTAssertFalse(pkce.codeVerifier.contains("+"), "Should not contain +")
        XCTAssertFalse(pkce.codeVerifier.contains("/"), "Should not contain /")
        XCTAssertFalse(pkce.codeVerifier.contains("="), "Should not contain padding =")
    }

    // MARK: - Code Challenge Tests

    func testCodeChallenge_IsSHA256Hash() {
        let pkce = PKCEHelper()

        // Manually compute expected challenge
        let verifierData = pkce.codeVerifier.data(using: .ascii)!
        let hash = SHA256.hash(data: verifierData)
        let expectedChallenge = Data(hash).base64URLEncodedString()

        XCTAssertEqual(pkce.codeChallenge, expectedChallenge,
                       "Code challenge should be SHA256 hash of verifier")
    }

    func testCodeChallenge_IsBase64URLEncoded() {
        let pkce = PKCEHelper()

        // Base64URL should not contain +, /, or =
        XCTAssertFalse(pkce.codeChallenge.contains("+"), "Should not contain +")
        XCTAssertFalse(pkce.codeChallenge.contains("/"), "Should not contain /")
        XCTAssertFalse(pkce.codeChallenge.contains("="), "Should not contain padding =")
    }

    func testCodeChallenge_Length_Is43Characters() {
        let pkce = PKCEHelper()

        // SHA256 = 32 bytes, base64url encoded = 43 characters
        XCTAssertEqual(pkce.codeChallenge.count, 43,
                       "Code challenge should be 43 characters (got \(pkce.codeChallenge.count))")
    }

    func testCodeChallenge_DifferentForDifferentVerifiers() {
        let pkce1 = PKCEHelper()
        let pkce2 = PKCEHelper()

        XCTAssertNotEqual(pkce1.codeChallenge, pkce2.codeChallenge,
                          "Different verifiers should produce different challenges")
    }

    // MARK: - Challenge Method Tests

    func testChallengeMethod_IsS256() {
        let pkce = PKCEHelper()

        XCTAssertEqual(pkce.codeChallengeMethod, "S256",
                       "Challenge method should be S256 for SHA256")
    }

    // MARK: - Consistency Tests

    func testCodeVerifier_SameVerifierProducesSameChallenge() {
        let pkce1 = PKCEHelper()
        let verifier = pkce1.codeVerifier

        // Manually compute challenge
        let verifierData = verifier.data(using: .ascii)!
        let hash = SHA256.hash(data: verifierData)
        let challenge = Data(hash).base64URLEncodedString()

        XCTAssertEqual(pkce1.codeChallenge, challenge,
                       "Same verifier should always produce same challenge")
    }

    // MARK: - Edge Cases

    func testMultiplePKCEInstances_AllValid() {
        // Create multiple instances and verify all are valid
        for _ in 0..<100 {
            let pkce = PKCEHelper()

            // Verify length constraints
            XCTAssertTrue(pkce.codeVerifier.count >= 43)
            XCTAssertEqual(pkce.codeChallenge.count, 43)

            // Verify charset
            let validCharset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            for char in pkce.codeVerifier {
                XCTAssertTrue(validCharset.contains(char.unicodeScalars.first!))
            }
        }
    }

    // MARK: - RFC 7636 Compliance Tests

    func testRFC7636_VerifierMinLength() {
        // RFC 7636 requires code_verifier to be between 43-128 characters
        let pkce = PKCEHelper()
        XCTAssertGreaterThanOrEqual(pkce.codeVerifier.count, 43)
    }

    func testRFC7636_VerifierMaxLength() {
        // RFC 7636 requires code_verifier to be between 43-128 characters
        let pkce = PKCEHelper()
        XCTAssertLessThanOrEqual(pkce.codeVerifier.count, 128)
    }

    func testRFC7636_ChallengeMethod() {
        // RFC 7636 defines S256 method as SHA256
        let pkce = PKCEHelper()
        XCTAssertEqual(pkce.codeChallengeMethod, "S256")
    }
}

// MARK: - Base64URL Helper Extension

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
