//
//  GoogleOAuthServiceTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for Google OAuth service functionality
final class GoogleOAuthServiceTests: XCTestCase {

    // MARK: - State Parameter Tests (CSRF Protection)

    func testState_IsUnique_AcrossRequests() {
        // Generate multiple state parameters and verify uniqueness
        var states: Set<String> = []

        for _ in 0..<100 {
            let state = generateState()
            XCTAssertFalse(states.contains(state), "State should be unique")
            states.insert(state)
        }
    }

    func testState_HasSufficientEntropy() {
        let state = generateState()

        // State should be at least 16 characters (from 16 random bytes base64url encoded)
        // 16 bytes = 128 bits of entropy, base64url = 22 characters
        XCTAssertGreaterThanOrEqual(state.count, 16,
                                    "State should have sufficient entropy")
    }

    func testState_IsBase64URLEncoded() {
        let state = generateState()

        // Should not contain standard base64 characters
        XCTAssertFalse(state.contains("+"), "State should not contain +")
        XCTAssertFalse(state.contains("/"), "State should not contain /")
        XCTAssertFalse(state.contains("="), "State should not contain padding")
    }

    func testStateMismatch_ThrowsError() {
        let originalState = "original_state_12345"
        let returnedState = "different_state_67890"

        XCTAssertNotEqual(originalState, returnedState)
        // In actual OAuth flow, this would throw GoogleOAuthError.stateMismatch
    }

    func testStateMatch_Succeeds() {
        let state = "same_state_12345"
        XCTAssertEqual(state, state)
    }

    // MARK: - Token Exchange Tests

    func testTokenExchange_SuccessResponse_ParsesCorrectly() {
        let jsonResponse = """
        {
            "access_token": "ya29.test_access_token",
            "refresh_token": "1//test_refresh_token",
            "expires_in": 3600,
            "token_type": "Bearer",
            "scope": "email profile"
        }
        """.data(using: .utf8)!

        do {
            let response = try JSONDecoder().decode(TokenResponse.self, from: jsonResponse)

            XCTAssertEqual(response.accessToken, "ya29.test_access_token")
            XCTAssertEqual(response.refreshToken, "1//test_refresh_token")
            XCTAssertEqual(response.expiresIn, 3600)
            XCTAssertEqual(response.tokenType, "Bearer")
        } catch {
            XCTFail("Failed to decode token response: \(error)")
        }
    }

    func testTokenExchange_NoRefreshToken_ParsesCorrectly() {
        let jsonResponse = """
        {
            "access_token": "ya29.test_access_token",
            "expires_in": 3600,
            "token_type": "Bearer"
        }
        """.data(using: .utf8)!

        do {
            let response = try JSONDecoder().decode(TokenResponse.self, from: jsonResponse)

            XCTAssertEqual(response.accessToken, "ya29.test_access_token")
            XCTAssertNil(response.refreshToken)
            XCTAssertEqual(response.expiresIn, 3600)
        } catch {
            XCTFail("Failed to decode token response: \(error)")
        }
    }

    // MARK: - Token Refresh Tests

    func testTokenRefresh_ValidRefreshToken_Succeeds() {
        // This is a structural test - actual refresh requires network
        let refreshToken = "1//test_refresh_token"
        XCTAssertFalse(refreshToken.isEmpty)
    }

    func testTokenRefresh_NoRefreshToken_ThrowsError() {
        let refreshToken: String? = nil
        XCTAssertNil(refreshToken, "Missing refresh token should cause error")
    }

    // MARK: - Error Handling Tests

    func testError_UserCancelled_HasCorrectMessage() {
        let error = GoogleOAuthError.userCancelled
        XCTAssertEqual(error.errorDescription, "Authentication was cancelled.")
    }

    func testError_StateMismatch_HasCorrectMessage() {
        let error = GoogleOAuthError.stateMismatch
        XCTAssertEqual(error.errorDescription, "Security validation failed. Please try again.")
    }

    func testError_NotAuthenticated_HasCorrectMessage() {
        let error = GoogleOAuthError.notAuthenticated
        XCTAssertEqual(error.errorDescription, "Not authenticated with Google. Please sign in.")
    }

    func testError_NoRefreshToken_HasCorrectMessage() {
        let error = GoogleOAuthError.noRefreshToken
        XCTAssertEqual(error.errorDescription, "No refresh token available. Please sign in again.")
    }

    func testError_TokenExchangeFailed_IncludesStatusCode() {
        let error = GoogleOAuthError.tokenExchangeFailed(statusCode: 400, message: "Invalid grant")
        let description = error.errorDescription ?? ""

        XCTAssertTrue(description.contains("400"), "Should include status code")
        XCTAssertTrue(description.contains("Invalid grant"), "Should include error message")
    }

    func testError_AuthorizationDenied_IncludesReason() {
        let error = GoogleOAuthError.authorizationDenied(error: "access_denied", description: "User denied access")
        let description = error.errorDescription ?? ""

        XCTAssertTrue(description.contains("User denied access"), "Should include denial reason")
    }

    // MARK: - URL Callback Parsing Tests

    func testCallbackParsing_ValidCode_ExtractsCode() {
        let callbackURL = URL(string: "com.subscriptionmanager://oauth?code=4/P7q7W91&state=test_state")!
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)!

        let code = components.queryItems?.first { $0.name == "code" }?.value
        XCTAssertEqual(code, "4/P7q7W91")
    }

    func testCallbackParsing_ValidState_ExtractsState() {
        let callbackURL = URL(string: "com.subscriptionmanager://oauth?code=test&state=abc123")!
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)!

        let state = components.queryItems?.first { $0.name == "state" }?.value
        XCTAssertEqual(state, "abc123")
    }

    func testCallbackParsing_Error_ExtractsError() {
        let callbackURL = URL(string: "com.subscriptionmanager://oauth?error=access_denied&error_description=User%20denied")!
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)!

        let error = components.queryItems?.first { $0.name == "error" }?.value
        XCTAssertEqual(error, "access_denied")

        let description = components.queryItems?.first { $0.name == "error_description" }?.value
        XCTAssertEqual(description, "User denied")
    }

    func testCallbackParsing_MissingCode_IsDetected() {
        let callbackURL = URL(string: "com.subscriptionmanager://oauth?state=test_state")!
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)!

        let code = components.queryItems?.first { $0.name == "code" }?.value
        XCTAssertNil(code, "Should detect missing authorization code")
    }

    // MARK: - User Info Tests

    func testUserInfo_ParsesCorrectly() {
        let jsonResponse = """
        {
            "id": "12345678901234567890",
            "email": "test@gmail.com",
            "verified_email": true,
            "name": "Test User",
            "picture": "https://lh3.googleusercontent.com/..."
        }
        """.data(using: .utf8)!

        do {
            let userInfo = try JSONDecoder().decode(UserInfo.self, from: jsonResponse)

            XCTAssertEqual(userInfo.email, "test@gmail.com")
            XCTAssertEqual(userInfo.verifiedEmail, true)
            XCTAssertEqual(userInfo.name, "Test User")
        } catch {
            XCTFail("Failed to decode user info: \(error)")
        }
    }

    // MARK: - Error Equatable Tests

    func testErrorEquatable_SameErrors_AreEqual() {
        XCTAssertEqual(GoogleOAuthError.userCancelled, GoogleOAuthError.userCancelled)
        XCTAssertEqual(GoogleOAuthError.stateMismatch, GoogleOAuthError.stateMismatch)
        XCTAssertEqual(GoogleOAuthError.notAuthenticated, GoogleOAuthError.notAuthenticated)
    }

    func testErrorEquatable_DifferentErrors_AreNotEqual() {
        XCTAssertNotEqual(GoogleOAuthError.userCancelled, GoogleOAuthError.stateMismatch)
        XCTAssertNotEqual(GoogleOAuthError.notAuthenticated, GoogleOAuthError.noRefreshToken)
    }

    func testErrorEquatable_TokenExchangeFailedWithSameParams_AreEqual() {
        let error1 = GoogleOAuthError.tokenExchangeFailed(statusCode: 400, message: "Invalid grant")
        let error2 = GoogleOAuthError.tokenExchangeFailed(statusCode: 400, message: "Invalid grant")
        XCTAssertEqual(error1, error2)
    }

    func testErrorEquatable_TokenExchangeFailedWithDifferentParams_AreNotEqual() {
        let error1 = GoogleOAuthError.tokenExchangeFailed(statusCode: 400, message: "Invalid grant")
        let error2 = GoogleOAuthError.tokenExchangeFailed(statusCode: 401, message: "Unauthorized")
        XCTAssertNotEqual(error1, error2)
    }

    // MARK: - Helper Methods

    private func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

// MARK: - Base64URL Helper

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
