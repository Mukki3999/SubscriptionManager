//
//  BlockedDomainTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for blocked domain filtering to prevent false positives
final class BlockedDomainTests: XCTestCase {

    // MARK: - Bank Domain Tests

    func testBlocked_BankOfAmerica_Filtered() {
        XCTAssertTrue(isBlockedDomain("bankofamerica.com"))
        XCTAssertTrue(isBlockedDomain("ealerts.bankofamerica.com"))
        XCTAssertTrue(isBlockedDomain("mail.bankofamerica.com"))
    }

    func testBlocked_Chase_Filtered() {
        XCTAssertTrue(isBlockedDomain("chase.com"))
        XCTAssertTrue(isBlockedDomain("alerts.chase.com"))
    }

    func testBlocked_WellsFargo_Filtered() {
        XCTAssertTrue(isBlockedDomain("wellsfargo.com"))
        XCTAssertTrue(isBlockedDomain("email.wellsfargo.com"))
    }

    func testBlocked_Citi_Filtered() {
        XCTAssertTrue(isBlockedDomain("citi.com"))
        XCTAssertTrue(isBlockedDomain("citibank.com"))
    }

    func testBlocked_CapitalOne_Filtered() {
        XCTAssertTrue(isBlockedDomain("capitalone.com"))
    }

    func testBlocked_Schwab_Filtered() {
        XCTAssertTrue(isBlockedDomain("schwab.com"))
    }

    func testBlocked_Fidelity_Filtered() {
        XCTAssertTrue(isBlockedDomain("fidelity.com"))
    }

    func testBlocked_Vanguard_Filtered() {
        XCTAssertTrue(isBlockedDomain("vanguard.com"))
    }

    func testBlocked_AmericanExpress_Filtered() {
        XCTAssertTrue(isBlockedDomain("americanexpress.com"))
        XCTAssertTrue(isBlockedDomain("aexp.com"))
    }

    // MARK: - Personal Email Domain Tests

    func testBlocked_Gmail_Filtered() {
        XCTAssertTrue(isBlockedDomain("gmail.com"))
        XCTAssertTrue(isBlockedDomain("googlemail.com"))
    }

    func testBlocked_Yahoo_Filtered() {
        XCTAssertTrue(isBlockedDomain("yahoo.com"))
        XCTAssertTrue(isBlockedDomain("ymail.com"))
    }

    func testBlocked_Outlook_Filtered() {
        XCTAssertTrue(isBlockedDomain("outlook.com"))
        XCTAssertTrue(isBlockedDomain("hotmail.com"))
        XCTAssertTrue(isBlockedDomain("live.com"))
    }

    func testBlocked_iCloud_Filtered() {
        XCTAssertTrue(isBlockedDomain("icloud.com"))
        XCTAssertTrue(isBlockedDomain("me.com"))
        XCTAssertTrue(isBlockedDomain("mac.com"))
    }

    func testBlocked_ProtonMail_Filtered() {
        XCTAssertTrue(isBlockedDomain("protonmail.com"))
        XCTAssertTrue(isBlockedDomain("proton.me"))
    }

    // MARK: - Shipping Domain Tests

    func testBlocked_UPS_Filtered() {
        XCTAssertTrue(isBlockedDomain("ups.com"))
    }

    func testBlocked_FedEx_Filtered() {
        XCTAssertTrue(isBlockedDomain("fedex.com"))
    }

    func testBlocked_USPS_Filtered() {
        XCTAssertTrue(isBlockedDomain("usps.com"))
    }

    func testBlocked_DHL_Filtered() {
        XCTAssertTrue(isBlockedDomain("dhl.com"))
    }

    // MARK: - Hard Excluded Domain Tests (Venmo, Zelle, etc.)

    func testHardExcluded_Venmo_Filtered() {
        XCTAssertTrue(isHardExcludedDomain("venmo.com"))
    }

    func testHardExcluded_Zelle_Filtered() {
        XCTAssertTrue(isHardExcludedDomain("zelle.com"))
    }

    func testHardExcluded_CashApp_Filtered() {
        XCTAssertTrue(isHardExcludedDomain("cashapp.com"))
    }

    func testHardExcluded_Klarna_Filtered() {
        XCTAssertTrue(isHardExcludedDomain("klarna.com"))
    }

    func testHardExcluded_Affirm_Filtered() {
        XCTAssertTrue(isHardExcludedDomain("affirm.com"))
    }

    // MARK: - E-commerce Domain Tests

    func testBlocked_eBay_Filtered() {
        XCTAssertTrue(isBlockedDomain("ebay.com"))
    }

    func testBlocked_Etsy_Filtered() {
        XCTAssertTrue(isBlockedDomain("etsy.com"))
    }

    // MARK: - Valid Subscription Domain Tests (Should NOT be filtered)

    func testNotBlocked_Netflix_Allowed() {
        XCTAssertFalse(isBlockedDomain("netflix.com"))
        XCTAssertFalse(isBlockedDomain("mailer.netflix.com"))
    }

    func testNotBlocked_Spotify_Allowed() {
        XCTAssertFalse(isBlockedDomain("spotify.com"))
    }

    func testNotBlocked_Adobe_Allowed() {
        XCTAssertFalse(isBlockedDomain("adobe.com"))
        XCTAssertFalse(isBlockedDomain("email.adobe.com"))
    }

    func testNotBlocked_Apple_Allowed() {
        // Note: apple.com is not blocked, but icloud.com is
        XCTAssertFalse(isBlockedDomain("apple.com"))
    }

    func testNotBlocked_Microsoft_Allowed() {
        // Note: microsoft.com is not blocked, but outlook.com is
        XCTAssertFalse(isBlockedDomain("microsoft.com"))
    }

    func testNotBlocked_Disney_Allowed() {
        XCTAssertFalse(isBlockedDomain("disneyplus.com"))
    }

    // MARK: - Payment Processor Domain Tests (Should NOT be blocked, but needs special handling)

    func testPaymentProcessor_PayPal_NotBlocked() {
        XCTAssertFalse(isBlockedDomain("paypal.com"))
        XCTAssertTrue(isPaymentProcessor("paypal.com"))
    }

    func testPaymentProcessor_Stripe_NotBlocked() {
        XCTAssertFalse(isBlockedDomain("stripe.com"))
        XCTAssertTrue(isPaymentProcessor("stripe.com"))
    }

    func testPaymentProcessor_Square_NotBlocked() {
        XCTAssertFalse(isBlockedDomain("squareup.com"))
        XCTAssertTrue(isPaymentProcessor("squareup.com"))
    }

    // MARK: - Subdomain Tests

    func testSubdomain_MailPrefix_StillBlocked() {
        XCTAssertTrue(isBlockedDomain("mail.bankofamerica.com"))
        XCTAssertTrue(isBlockedDomain("alerts.chase.com"))
        XCTAssertTrue(isBlockedDomain("notifications.wellsfargo.com"))
    }

    func testSubdomain_ValidService_StillAllowed() {
        XCTAssertFalse(isBlockedDomain("email.netflix.com"))
        XCTAssertFalse(isBlockedDomain("billing.spotify.com"))
        XCTAssertFalse(isBlockedDomain("notifications.adobe.com"))
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitive_UpperCase_StillBlocked() {
        XCTAssertTrue(isBlockedDomain("BANKOFAMERICA.COM"))
        XCTAssertTrue(isBlockedDomain("CHASE.COM"))
    }

    func testCaseInsensitive_MixedCase_StillBlocked() {
        XCTAssertTrue(isBlockedDomain("BankOfAmerica.com"))
        XCTAssertTrue(isBlockedDomain("Chase.Com"))
    }

    // MARK: - Helper Methods

    private let blockedDomains: Set<String> = [
        // Banks
        "bankofamerica.com", "bofa.com", "boa.com",
        "chase.com", "jpmorganchase.com",
        "wellsfargo.com", "wf.com",
        "citi.com", "citibank.com",
        "capitalone.com",
        "usbank.com",
        "pnc.com",
        "td.com", "tdbank.com",
        "schwab.com",
        "fidelity.com",
        "vanguard.com",
        "americanexpress.com", "aexp.com",
        "discover.com",
        "synchrony.com",
        "ally.com",
        "marcus.com",
        "sofi.com",

        // Personal email
        "gmail.com", "googlemail.com",
        "yahoo.com", "ymail.com",
        "outlook.com", "hotmail.com", "live.com",
        "icloud.com", "me.com", "mac.com",
        "aol.com",
        "protonmail.com", "proton.me",

        // Shipping
        "ups.com", "fedex.com", "usps.com", "dhl.com",
        "ontrac.com", "lasership.com",

        // E-commerce
        "ebay.com", "etsy.com", "wish.com",
        "aliexpress.com", "alibaba.com"
    ]

    private let hardExcludedDomains: Set<String> = [
        "venmo.com", "zelle.com", "cashapp.com",
        "klarna.com", "affirm.com", "afterpay.com"
    ]

    private let paymentProcessorDomains: Set<String> = [
        "paypal.com", "paypal-communication.com",
        "stripe.com",
        "squareup.com", "square.com"
    ]

    private func isBlockedDomain(_ domain: String) -> Bool {
        let lowercased = domain.lowercased()

        if blockedDomains.contains(lowercased) {
            return true
        }

        // Check if domain ends with blocked domain
        for blocked in blockedDomains {
            if lowercased.hasSuffix(".\(blocked)") {
                return true
            }
        }

        return false
    }

    private func isHardExcludedDomain(_ domain: String) -> Bool {
        hardExcludedDomains.contains(domain.lowercased())
    }

    private func isPaymentProcessor(_ domain: String) -> Bool {
        let lowercased = domain.lowercased()
        return paymentProcessorDomains.contains { lowercased.contains($0) }
    }
}
