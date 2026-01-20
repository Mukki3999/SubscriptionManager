//
//  GoogleOAuthService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation
import AuthenticationServices

/// A secure service for Google OAuth 2.0 authentication following Apple's best practices.
///
/// This service implements:
/// - PKCE (Proof Key for Code Exchange) for enhanced security
/// - State parameter for CSRF protection
/// - Secure token storage via Keychain
/// - Automatic token refresh
/// - ASWebAuthenticationSession for secure web-based OAuth flow
///
/// ## Usage
/// ```swift
/// let service = GoogleOAuthService()
/// let account = try await service.signIn()
/// ```
///
/// ## Security Features
/// - PKCE prevents authorization code interception attacks
/// - State parameter prevents CSRF attacks
/// - Tokens stored in Keychain (not UserDefaults)
/// - Automatic token refresh before expiration
///
/// - Important: Configure your Client ID in `GoogleOAuthConfig.swift` before use.
@MainActor
final class GoogleOAuthService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isRefreshing = false

    // MARK: - Private Properties

    private let keychain = KeychainService.shared
    private let urlSession: URLSession

    /// Current PKCE helper (created fresh for each auth flow)
    private var currentPKCE: PKCEHelper?

    /// Current state parameter for CSRF protection
    private var currentState: String?

    // MARK: - Initialization

    override init() {
        // Configure URLSession with appropriate timeout and caching
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: configuration)

        super.init()

        // Check if we have valid stored tokens
        isAuthenticated = keychain.hasValidGoogleTokens
    }

    // MARK: - Public Methods

    /// Initiates the Google OAuth sign-in flow
    ///
    /// Opens a secure web view (ASWebAuthenticationSession) for the user to
    /// authenticate with Google and grant permissions.
    ///
    /// - Returns: A `ConnectedAccount` with the authenticated user's information
    /// - Throws: `GoogleOAuthError` if authentication fails
    func signIn() async throws -> ConnectedAccount {
        // Validate configuration first
        try GoogleOAuthConfig.validate()

        // Generate fresh PKCE values for this auth flow
        let pkce = PKCEHelper()
        currentPKCE = pkce

        // Generate state parameter for CSRF protection
        let state = generateState()
        currentState = state

        // Build authorization URL
        let authURL = buildAuthorizationURL(pkce: pkce, state: state)

        // Perform OAuth flow using ASWebAuthenticationSession
        let callbackURL = try await performWebAuthentication(url: authURL)

        // Validate callback and extract authorization code
        let code = try extractAuthorizationCode(from: callbackURL, expectedState: state)

        // Exchange authorization code for tokens
        let tokens = try await exchangeCodeForTokens(code, pkce: pkce)

        // Fetch user information
        let userInfo = try await fetchUserInfo(accessToken: tokens.accessToken)

        // Store tokens securely in Keychain
        try keychain.storeGoogleTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn)),
            email: userInfo.email
        )

        isAuthenticated = true

        // Clear temporary PKCE/state values
        currentPKCE = nil
        currentState = nil

        return ConnectedAccount(
            email: userInfo.email,
            provider: .gmail,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        )
    }

    /// Signs out the user and clears all stored tokens
    func signOut() async throws {
        // Revoke tokens with Google
        if let tokens = keychain.getGoogleTokens() {
            try? await revokeToken(tokens.accessToken)
        }

        // Clear Keychain
        keychain.clearGoogleTokens()

        isAuthenticated = false
    }

    /// Returns a valid access token, refreshing if necessary
    ///
    /// Use this method when making API calls to ensure you have a valid token.
    ///
    /// - Returns: A valid access token
    /// - Throws: `GoogleOAuthError` if no token is available or refresh fails
    func getValidAccessToken() async throws -> String {
        guard let tokens = keychain.getGoogleTokens() else {
            throw GoogleOAuthError.notAuthenticated
        }

        // Check if token needs refresh
        if keychain.googleTokensNeedRefresh {
            guard let refreshToken = tokens.refreshToken else {
                throw GoogleOAuthError.noRefreshToken
            }

            return try await refreshAccessToken(refreshToken: refreshToken)
        }

        return tokens.accessToken
    }

    /// Refreshes the access token using the stored refresh token
    ///
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: The new access token
    /// - Throws: `GoogleOAuthError` if refresh fails
    func refreshAccessToken(refreshToken: String) async throws -> String {
        guard !isRefreshing else {
            throw GoogleOAuthError.refreshInProgress
        }

        isRefreshing = true
        defer { isRefreshing = false }

        var request = URLRequest(url: URL(string: GoogleOAuthConfig.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams: [String: String] = [
            "client_id": GoogleOAuthConfig.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = bodyParams.urlEncodedString.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorInfo = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data)
            throw GoogleOAuthError.tokenRefreshFailed(
                statusCode: httpResponse.statusCode,
                message: errorInfo?.errorDescription ?? "Unknown error"
            )
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Update stored tokens
        if let storedTokens = keychain.getGoogleTokens() {
            try keychain.storeGoogleTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                email: storedTokens.email
            )
        }

        return tokenResponse.accessToken
    }

    // MARK: - Private Methods

    /// Generates a cryptographically secure state parameter
    private func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    /// Builds the authorization URL with all required parameters
    private func buildAuthorizationURL(pkce: PKCEHelper, state: String) -> URL {
        var components = URLComponents(string: GoogleOAuthConfig.authorizationEndpoint)!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleOAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfig.scopeString),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            // PKCE parameters
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod),
            // State parameter for CSRF protection
            URLQueryItem(name: "state", value: state)
        ]

        return components.url!
    }

    /// Performs the web authentication flow
    private func performWebAuthentication(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GoogleOAuthConfig.callbackURLScheme
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError {
                    switch error.code {
                    case .canceledLogin:
                        continuation.resume(throwing: GoogleOAuthError.userCancelled)
                    case .presentationContextNotProvided:
                        continuation.resume(throwing: GoogleOAuthError.presentationError)
                    case .presentationContextInvalid:
                        continuation.resume(throwing: GoogleOAuthError.presentationError)
                    @unknown default:
                        continuation.resume(throwing: GoogleOAuthError.unknown(error))
                    }
                    return
                }

                if let error = error {
                    continuation.resume(throwing: GoogleOAuthError.unknown(error))
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: GoogleOAuthError.invalidCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: GoogleOAuthError.sessionStartFailed)
            }
        }
    }

    /// Extracts the authorization code from the callback URL
    private func extractAuthorizationCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GoogleOAuthError.invalidCallback
        }

        // Check for errors in callback
        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            let description = components.queryItems?.first(where: { $0.name == "error_description" })?.value
            throw GoogleOAuthError.authorizationDenied(error: error, description: description)
        }

        // Validate state parameter (CSRF protection)
        guard let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            throw GoogleOAuthError.stateMismatch
        }

        // Extract authorization code
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleOAuthError.missingAuthorizationCode
        }

        return code
    }

    /// Exchanges the authorization code for access and refresh tokens
    private func exchangeCodeForTokens(_ code: String, pkce: PKCEHelper) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: GoogleOAuthConfig.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams: [String: String] = [
            "code": code,
            "client_id": GoogleOAuthConfig.clientID,
            "redirect_uri": GoogleOAuthConfig.redirectURI,
            "grant_type": "authorization_code",
            // PKCE: Include code verifier
            "code_verifier": pkce.codeVerifier
        ]

        request.httpBody = bodyParams.urlEncodedString.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorInfo = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data)
            throw GoogleOAuthError.tokenExchangeFailed(
                statusCode: httpResponse.statusCode,
                message: errorInfo?.errorDescription ?? "Token exchange failed"
            )
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /// Fetches user information using the access token
    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var request = URLRequest(url: URL(string: GoogleOAuthConfig.userInfoEndpoint)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GoogleOAuthError.userInfoFetchFailed(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(UserInfo.self, from: data)
    }

    /// Revokes an access or refresh token
    private func revokeToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: GoogleOAuthConfig.revokeEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "token=\(token)"
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GoogleOAuthError.tokenRevocationFailed
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleOAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window for presenting the authentication session
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Response Models

/// Token response from Google's OAuth token endpoint
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

/// User information from Google's userinfo endpoint
struct UserInfo: Codable {
    let id: String?
    let email: String
    let verifiedEmail: Bool
    let name: String?
    let picture: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case verifiedEmail = "verified_email"
        case name
        case picture
    }
}

/// Error response from Google's OAuth endpoints
private struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Errors

/// Errors that can occur during Google OAuth authentication
enum GoogleOAuthError: LocalizedError, Equatable {
    case notConfigured
    case notAuthenticated
    case noRefreshToken
    case refreshInProgress
    case userCancelled
    case presentationError
    case sessionStartFailed
    case invalidCallback
    case invalidResponse
    case stateMismatch
    case missingAuthorizationCode
    case authorizationDenied(error: String, description: String?)
    case tokenExchangeFailed(statusCode: Int, message: String)
    case tokenRefreshFailed(statusCode: Int, message: String)
    case tokenRevocationFailed
    case userInfoFetchFailed(statusCode: Int)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google OAuth is not configured. Please update GoogleOAuthConfig.swift."
        case .notAuthenticated:
            return "Not authenticated with Google. Please sign in."
        case .noRefreshToken:
            return "No refresh token available. Please sign in again."
        case .refreshInProgress:
            return "Token refresh already in progress."
        case .userCancelled:
            return "Authentication was cancelled."
        case .presentationError:
            return "Unable to present authentication window."
        case .sessionStartFailed:
            return "Failed to start authentication session."
        case .invalidCallback:
            return "Invalid authentication callback received."
        case .invalidResponse:
            return "Invalid response from server."
        case .stateMismatch:
            return "Security validation failed. Please try again."
        case .missingAuthorizationCode:
            return "No authorization code received from Google."
        case .authorizationDenied(let error, let description):
            return description ?? "Authorization denied: \(error)"
        case .tokenExchangeFailed(let statusCode, let message):
            return "Failed to exchange code for tokens (\(statusCode)): \(message)"
        case .tokenRefreshFailed(let statusCode, let message):
            return "Failed to refresh access token (\(statusCode)): \(message)"
        case .tokenRevocationFailed:
            return "Failed to revoke tokens."
        case .userInfoFetchFailed(let statusCode):
            return "Failed to fetch user information (\(statusCode))."
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }

    static func == (lhs: GoogleOAuthError, rhs: GoogleOAuthError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.notAuthenticated, .notAuthenticated),
             (.noRefreshToken, .noRefreshToken),
             (.refreshInProgress, .refreshInProgress),
             (.userCancelled, .userCancelled),
             (.presentationError, .presentationError),
             (.sessionStartFailed, .sessionStartFailed),
             (.invalidCallback, .invalidCallback),
             (.invalidResponse, .invalidResponse),
             (.stateMismatch, .stateMismatch),
             (.missingAuthorizationCode, .missingAuthorizationCode),
             (.tokenRevocationFailed, .tokenRevocationFailed):
            return true
        case (.authorizationDenied(let e1, let d1), .authorizationDenied(let e2, let d2)):
            return e1 == e2 && d1 == d2
        case (.tokenExchangeFailed(let s1, let m1), .tokenExchangeFailed(let s2, let m2)):
            return s1 == s2 && m1 == m2
        case (.tokenRefreshFailed(let s1, let m1), .tokenRefreshFailed(let s2, let m2)):
            return s1 == s2 && m1 == m2
        case (.userInfoFetchFailed(let s1), .userInfoFetchFailed(let s2)):
            return s1 == s2
        default:
            return false
        }
    }
}

// MARK: - Dictionary Extension

private extension Dictionary where Key == String, Value == String {
    /// Converts dictionary to URL-encoded string
    var urlEncodedString: String {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}
