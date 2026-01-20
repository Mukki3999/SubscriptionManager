# Google OAuth Setup Guide

This guide walks you through setting up Google OAuth 2.0 for the subscriptionManager iOS app.

## Prerequisites

- Xcode 15.0 or later
- An Apple Developer account
- A Google account with access to Google Cloud Console

---

## Step 1: Google Cloud Console Setup

### 1.1 Create or Select a Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click the project dropdown at the top
3. Either select an existing project or click "New Project"
4. If creating new: Enter a project name (e.g., "subscriptionManager")

### 1.2 Enable the Gmail API

1. In the left sidebar, go to **APIs & Services** → **Library**
2. Search for "Gmail API"
3. Click on "Gmail API" in the results
4. Click **Enable**

### 1.3 Configure OAuth Consent Screen

1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **External** as the user type (unless you have Google Workspace)
3. Click **Create**

Fill in the required information:
- **App name**: subscriptionManager
- **User support email**: Your email address
- **Developer contact email**: Your email address

4. Click **Save and Continue**

5. On the **Scopes** page, click **Add or Remove Scopes**
6. Add these scopes:
   - `.../auth/gmail.readonly`
   - `.../auth/userinfo.email`
7. Click **Update** → **Save and Continue**

8. On **Test users** page, add your Gmail address for testing
9. Click **Save and Continue** → **Back to Dashboard**

### 1.4 Create OAuth 2.0 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Select **iOS** as the Application type
4. Enter the following:
   - **Name**: subscriptionManager iOS
   - **Bundle ID**: `com.mukeshkhatri.subscriptionManager`
5. Click **Create**

6. **Important**: Copy your **Client ID**. It will look like:
   ```
   123456789012-abcdefghijklmnopqrstuvwxyz123456.apps.googleusercontent.com
   ```

---

## Step 2: Configure the App

### 2.1 Update GoogleOAuthConfig.swift

Open `subscriptionManager/Services/GoogleOAuthConfig.swift` and replace the placeholder Client ID:

```swift
static let clientID = "YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com"
```

For example:
```swift
static let clientID = "123456789012-abcdefghijklmnopqrstuvwxyz123456.apps.googleusercontent.com"
```

### 2.2 Add URL Scheme in Xcode

The app needs a custom URL scheme to receive the OAuth callback from Safari.

1. Open the project in Xcode
2. Select the **subscriptionManager** target
3. Go to the **Info** tab
4. Expand **URL Types**
5. Click the **+** button to add a new URL type
6. Configure it as follows:

| Field | Value |
|-------|-------|
| Identifier | `com.mukeshkhatri.subscriptionManager.google` |
| URL Schemes | `com.googleusercontent.apps.YOUR_CLIENT_ID` |
| Role | Editor |

**Important**: The URL Scheme is your Client ID reversed. For example:
- Client ID: `123456789012-abcdefghijklmnop.apps.googleusercontent.com`
- URL Scheme: `com.googleusercontent.apps.123456789012-abcdefghijklmnop`

### 2.3 Alternative: Edit Info.plist Directly

If you prefer, add this to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.mukeshkhatri.subscriptionManager.google</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

## Step 3: Add New Files to Xcode Project

Make sure all the new Swift files are added to your Xcode project:

1. In Xcode, right-click on the **Services** folder
2. Select **Add Files to "subscriptionManager"...**
3. Add these files if they're not already included:
   - `KeychainService.swift`
   - `GoogleOAuthConfig.swift`
   - `PKCEHelper.swift`

---

## Step 4: Test the Integration

### 4.1 Run the App

1. Build and run the app on a simulator or device
2. Tap "Connect your Gmail Account"
3. A Safari web view should appear with Google's sign-in page

### 4.2 Complete Authentication

1. Sign in with your Google account
2. Review and accept the requested permissions
3. You should be redirected back to the app
4. Your Gmail account should now appear as connected

### 4.3 Troubleshooting

**Error: "Google OAuth Client ID not configured"**
- Make sure you updated `GoogleOAuthConfig.swift` with your actual Client ID

**Error: "redirect_uri_mismatch"**
- Verify the Bundle ID in Google Cloud Console matches your app's bundle identifier
- Check that the URL scheme is correctly configured

**Authentication window doesn't appear**
- Ensure you're testing on a device or simulator with iOS 13.0+
- Check that `ASWebAuthenticationSession` is properly configured

**Callback not received**
- Verify the URL scheme is exactly the reversed Client ID
- Make sure the URL scheme is added to Info.plist

---

## Security Features Implemented

This implementation follows Apple's best practices and includes:

1. **PKCE (Proof Key for Code Exchange)**
   - Protects against authorization code interception attacks
   - Required for mobile OAuth clients

2. **State Parameter**
   - Prevents CSRF (Cross-Site Request Forgery) attacks
   - Validated on callback

3. **Keychain Storage**
   - Tokens stored securely in iOS Keychain
   - Not in UserDefaults or plain files

4. **Token Refresh**
   - Automatic token refresh before expiration
   - Seamless user experience

5. **ASWebAuthenticationSession**
   - Apple's recommended OAuth flow for iOS
   - Secure, in-app browser experience
   - Shares cookies with Safari for SSO

---

## Production Considerations

Before releasing to the App Store:

1. **Verify OAuth Consent Screen**
   - Submit for Google verification if you have more than 100 users
   - Add privacy policy and terms of service URLs

2. **App Store Review**
   - Ensure you have a clear privacy policy
   - Explain why you need Gmail access
   - Follow Apple's App Store Review Guidelines

3. **Environment Variables**
   - Consider using `.xcconfig` files for different environments
   - Never commit production credentials to version control

4. **Error Handling**
   - Handle all error cases gracefully
   - Provide clear user feedback

---

## File Structure

```
subscriptionManager/
├── Services/
│   ├── GoogleOAuthConfig.swift    # OAuth configuration
│   ├── GoogleOAuthService.swift   # Main OAuth service
│   ├── PKCEHelper.swift           # PKCE implementation
│   ├── KeychainService.swift      # Secure token storage
│   ├── GmailAPIService.swift      # Gmail API client
│   └── AppleSignInService.swift   # Apple Sign-In
├── Models/
│   └── ConnectedAccount.swift     # Account data model
├── ViewModels/
│   └── AccountConnectionViewModel.swift
└── Views/
    └── AccountConnectionView.swift
```

---

## Support

If you encounter issues:
1. Check the Xcode console for detailed error messages
2. Verify all configuration steps are completed
3. Ensure you're using the correct Bundle ID and Client ID
