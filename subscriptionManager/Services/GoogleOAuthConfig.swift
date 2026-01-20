//
//  GoogleOAuthConfig.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation

/// Configuration for Google OAuth 2.0 authentication.
///
/// # Setup Instructions
///
/// ## Step 1: Create Google Cloud Project
/// 1. Go to https://console.cloud.google.com
/// 2. Create a new project or select an existing one
/// 3. Enable the Gmail API:
///    - Navigate to "APIs & Services" → "Library"
///    - Search for "Gmail API" and enable it
///
/// ## Step 2: Configure OAuth Consent Screen
/// 1. Go to "APIs & Services" → "OAuth consent screen"
/// 2. Select "External" user type
/// 3. Fill in required fields:
///    - App name: subscriptionManager
///    - User support email: your email
///    - Developer contact: your email
/// 4. Add scopes:
///    - `.../auth/gmail.readonly`
///    - `.../auth/userinfo.email`
///
/// ## Step 3: Create OAuth 2.0 Credentials
/// 1. Go to "APIs & Services" → "Credentials"
/// 2. Click "Create Credentials" → "OAuth client ID"
/// 3. Select "iOS" as application type
/// 4. Enter your Bundle ID: `com.mukeshkhatri.subscriptionManager`
/// 5. Download the credentials file
///
/// ## Step 4: Update This Configuration
/// Replace `YOUR_CLIENT_ID` below with the Client ID from your credentials.
/// The format is: `XXXXX.apps.googleusercontent.com`
///
/// ## Step 5: Configure URL Scheme in Xcode
/// 1. Open your project in Xcode
/// 2. Select the target → "Info" tab
/// 3. Expand "URL Types" and click "+"
/// 4. Add URL Scheme: `com.googleusercontent.apps.YOUR_CLIENT_ID`
///    (This is your client ID reversed)
///
/// - Important: Never commit actual credentials to version control.
///              Consider using environment variables or a .xcconfig file.
struct GoogleOAuthConfig {

    // MARK: - Configuration

    /// Your Google OAuth 2.0 Client ID
    /// Format: XXXXX.apps.googleusercontent.com
    ///
    /// - Important: Replace this with your actual Client ID from Google Cloud Console
    static let clientID = "32000601298-3flfbi60gv2c24scrnku13lo2d2grhpl.apps.googleusercontent.com"

    /// The Bundle ID of your application
    /// Must match what you registered in Google Cloud Console
    static let bundleID = "com.mukeshkhatri.subscriptionManager"

    // MARK: - Computed Properties

    /// The reversed client ID used as the URL scheme for OAuth callbacks
    ///
    /// Google requires iOS apps to use a reversed client ID as the callback URL scheme.
    /// For example, if your client ID is `123456.apps.googleusercontent.com`,
    /// your URL scheme would be `com.googleusercontent.apps.123456`
    static var reversedClientID: String {
        let components = clientID.components(separatedBy: ".")
        return components.reversed().joined(separator: ".")
    }

    /// The redirect URI used in OAuth flow
    ///
    /// This is the callback URL that Google will redirect to after authentication.
    /// Format: `{reversedClientID}:/oauth2redirect/google`
    static var redirectURI: String {
        "\(reversedClientID):/oauth2redirect/google"
    }

    /// The URL scheme portion of the redirect URI (without path)
    ///
    /// Used to configure ASWebAuthenticationSession callback scheme.
    static var callbackURLScheme: String {
        reversedClientID
    }

    // MARK: - OAuth Scopes

    /// Gmail API scopes requested during authentication
    ///
    /// - `gmail.readonly`: Read-only access to Gmail messages and settings
    /// - `userinfo.email`: Access to the user's email address
    ///
    /// Following the principle of least privilege, only request scopes you need.
    static let scopes: [String] = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/userinfo.email"
    ]

    /// Scopes formatted as a space-separated string for URL parameters
    static var scopeString: String {
        scopes.joined(separator: " ")
    }

    // MARK: - OAuth Endpoints

    /// Google's OAuth 2.0 authorization endpoint
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"

    /// Google's OAuth 2.0 token endpoint
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    /// Google's token revocation endpoint
    static let revokeEndpoint = "https://oauth2.googleapis.com/revoke"

    /// Google's userinfo endpoint
    static let userInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo"

    // MARK: - Validation

    /// Checks if the configuration has been properly set up
    static var isConfigured: Bool {
        !clientID.contains("YOUR_CLIENT_ID") && clientID.hasSuffix(".apps.googleusercontent.com")
    }

    /// Validates the configuration and throws if invalid
    static func validate() throws {
        guard isConfigured else {
            throw ConfigurationError.missingClientID
        }
    }

    // MARK: - Errors

    enum ConfigurationError: LocalizedError {
        case missingClientID

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                return "Google OAuth Client ID not configured. Please update GoogleOAuthConfig.swift with your Client ID from Google Cloud Console."
            }
        }
    }
}
