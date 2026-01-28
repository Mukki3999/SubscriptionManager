//
//  MerchantMatchingTests.swift
//  subscriptionManagerTests
//
//  Tests for merchant matching logic, especially for services sharing the same domain.
//

import XCTest
@testable import subscriptionManager

/// Tests for MerchantDatabase matching logic
final class MerchantMatchingTests: XCTestCase {

    var merchantDB: MerchantDatabase!

    override func setUp() {
        super.setUp()
        merchantDB = MerchantDatabase.shared
    }

    // MARK: - Apple Services Disambiguation Tests

    func testAppleDomain_iCloudContent_ReturnsiCloud() {
        // Email about iCloud storage should match iCloud+, not Apple Music
        let emailContent = "Your iCloud+ subscription has been renewed. iCloud Storage 50GB plan."

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant, "Should find a merchant for apple.com with iCloud content")
        XCTAssertEqual(merchant?.id, "icloud", "Should match iCloud, not Apple Music")
        XCTAssertEqual(merchant?.name, "iCloud+")
    }

    func testAppleDomain_iCloudStorageContent_ReturnsiCloud() {
        let emailContent = "Receipt for your iCloud storage subscription renewal $0.99/month"

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "icloud")
    }

    func testAppleDomain_AppleMusicContent_ReturnsAppleMusic() {
        // Email about Apple Music should match Apple Music
        let emailContent = "Your Apple Music subscription has been renewed. Enjoy unlimited music."

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant, "Should find a merchant for apple.com with Apple Music content")
        XCTAssertEqual(merchant?.id, "apple_music", "Should match Apple Music")
        XCTAssertEqual(merchant?.name, "Apple Music")
    }

    func testAppleDomain_AppleArcadeContent_ReturnsAppleArcade() {
        let emailContent = "Your Apple Arcade subscription is active. Play 200+ games."

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "apple_arcade")
    }

    func testAppleDomain_AppleFitnessContent_ReturnsAppleFitness() {
        let emailContent = "Welcome to Apple Fitness+ Your Fitness+ subscription starts today."

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "apple_fitness")
    }

    func testAppleDomain_AppleNewsContent_ReturnsAppleNews() {
        let emailContent = "Your Apple News+ subscription receipt. Access hundreds of magazines."

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "apple_news")
    }

    func testAppleDomain_GenericContent_ReturnsFirstMatch() {
        // Generic Apple email with no specific service mentioned
        let emailContent = "Thank you for your purchase from Apple."

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        // Should still return something (first match)
        XCTAssertNotNil(merchant)
    }

    // MARK: - Google Services Disambiguation Tests

    func testGoogleDomain_YouTubeMusicContent_ReturnsYouTubeMusic() {
        let emailContent = "Your YouTube Music Premium subscription has renewed."

        let merchant = merchantDB.findMerchant(byDomain: "google.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "youtube_music")
    }

    func testGoogleDomain_YouTubePremiumContent_ReturnsYouTubeMusic() {
        let emailContent = "YouTube Premium membership renewed. Ad-free videos and music."

        let merchant = merchantDB.findMerchant(byDomain: "google.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "youtube_music")
    }

    func testGoogleDomain_GoogleOneContent_ReturnsGoogleOne() {
        let emailContent = "Your Google One storage plan has been renewed. 100GB plan."

        let merchant = merchantDB.findMerchant(byDomain: "google.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "google_one")
    }

    // MARK: - Microsoft Services Disambiguation Tests

    func testMicrosoftDomain_XboxContent_ReturnsXbox() {
        let emailContent = "Your Xbox Game Pass Ultimate subscription. Play hundreds of games."

        let merchant = merchantDB.findMerchant(byDomain: "microsoft.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "xbox_gamepass")
    }

    func testMicrosoftDomain_Office365Content_ReturnsMicrosoft365() {
        let emailContent = "Your Microsoft 365 subscription renewal receipt."

        let merchant = merchantDB.findMerchant(byDomain: "microsoft.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "microsoft_365")
    }

    // MARK: - Single Domain Merchants (No Disambiguation Needed)

    func testNetflixDomain_ReturnsNetflix() {
        let emailContent = "Your Netflix subscription"

        let merchant = merchantDB.findMerchant(byDomain: "netflix.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "netflix")
    }

    func testSpotifyDomain_ReturnsSpotify() {
        let emailContent = "Spotify Premium receipt"

        let merchant = merchantDB.findMerchant(byDomain: "spotify.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "spotify")
    }

    // MARK: - Basic Domain Lookup (Without Content)

    func testBasicDomainLookup_Netflix() {
        let merchant = merchantDB.findMerchant(byDomain: "netflix.com")

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "netflix")
    }

    func testBasicDomainLookup_Spotify() {
        let merchant = merchantDB.findMerchant(byDomain: "spotify.com")

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "spotify")
    }

    func testBasicDomainLookup_UnknownDomain() {
        let merchant = merchantDB.findMerchant(byDomain: "unknownservice12345.com")

        XCTAssertNil(merchant)
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitive_iCloudUpperCase() {
        let emailContent = "ICLOUD STORAGE subscription renewed"

        let merchant = merchantDB.findMerchant(byDomain: "apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "icloud")
    }

    func testCaseInsensitive_AppleMusicMixedCase() {
        let emailContent = "Apple MUSIC Premium subscription"

        let merchant = merchantDB.findMerchant(byDomain: "APPLE.COM", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "apple_music")
    }

    // MARK: - Real World Email Content Tests

    func testRealEmail_iCloudStorageReceipt() {
        // Simulating a real iCloud receipt email
        let emailContent = """
        Your receipt from Apple.
        iCloud+ 50GB
        $0.99
        Billed monthly
        """

        let merchant = merchantDB.findMerchant(byDomain: "email.apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "icloud", "Should detect iCloud from receipt content")
    }

    func testRealEmail_AppleMusicReceipt() {
        // Simulating a real Apple Music receipt email
        let emailContent = """
        Your receipt from Apple.
        Apple Music Individual
        $10.99
        Billed monthly
        """

        let merchant = merchantDB.findMerchant(byDomain: "email.apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant)
        XCTAssertEqual(merchant?.id, "apple_music", "Should detect Apple Music from receipt content")
    }

    // MARK: - Subdomain Tests

    func testSubdomain_EmailAppleCom() {
        let emailContent = "iCloud storage renewal"

        let merchant = merchantDB.findMerchant(byDomain: "email.apple.com", emailContent: emailContent)

        XCTAssertNotNil(merchant, "Should match apple.com subdomain")
        XCTAssertEqual(merchant?.id, "icloud")
    }

    func testSubdomain_MailerNetflixCom() {
        let emailContent = "Your Netflix subscription"

        let merchant = merchantDB.findMerchant(byDomain: "mailer.netflix.com", emailContent: emailContent)

        XCTAssertNotNil(merchant, "Should match netflix.com subdomain")
        XCTAssertEqual(merchant?.id, "netflix")
    }
}
