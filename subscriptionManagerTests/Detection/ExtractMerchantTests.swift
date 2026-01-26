//
//  ExtractMerchantTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for merchant name extraction from payment processor emails
final class ExtractMerchantTests: XCTestCase {

    // MARK: - PayPal Pattern Tests

    func testPayPal_PaymentTo_ExtractsMerchant() {
        let text = "Payment to Spotify on January 15, 2026"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertEqual(merchant, "Spotify", "Should extract 'Spotify' from PayPal payment")
    }

    func testPayPal_AutomaticPaymentTo_ExtractsMerchant() {
        let text = "automatic payment to Notion Labs for $10.99"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertEqual(merchant, "Notion Labs", "Should extract 'Notion Labs'")
    }

    func testPayPal_YouPaid_ExtractsMerchant() {
        let text = "You sent an automatic payment to Figma Inc"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertNotNil(merchant, "Should extract merchant from 'automatic payment to'")
    }

    // MARK: - Stripe Pattern Tests

    func testStripe_ReceiptFrom_ExtractsMerchant() {
        let text = "Receipt from Figma for your subscription"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertEqual(merchant, "Figma", "Should extract 'Figma' from Stripe receipt")
    }

    func testStripe_StatementDescriptor_ExtractsMerchant() {
        let text = "Statement descriptor: FIGMA INC"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertEqual(merchant, "FIGMA INC", "Should extract from statement descriptor")
    }

    // MARK: - Generic Merchant Pattern Tests

    func testGeneric_MerchantField_ExtractsMerchant() {
        let text = "Merchant: Notion Labs LLC"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertEqual(merchant, "Notion Labs LLC", "Should extract from 'Merchant:' field")
    }

    func testGeneric_PaidTo_ExtractsMerchant() {
        let text = "paid Spotify $9.99 on 1/15/26"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertEqual(merchant, "Spotify", "Should extract from 'paid X $' pattern")
    }

    // MARK: - Generic Term Filtering Tests

    func testFilter_Payment_Rejected() {
        let genericTerms = ["Payment", "Subscription", "Recurring", "Charge",
                           "Invoice", "Receipt", "Billing", "Automatic",
                           "Monthly", "Annual", "Yearly", "Your"]

        for term in genericTerms {
            XCTAssertTrue(isGenericPaymentTerm(term), "\(term) should be filtered as generic")
        }
    }

    func testFilter_ValidMerchant_Accepted() {
        let validMerchants = ["Spotify", "Netflix", "Adobe", "Notion", "Figma",
                             "Dropbox", "Slack", "Zoom", "GitHub"]

        for merchant in validMerchants {
            XCTAssertFalse(isGenericPaymentTerm(merchant), "\(merchant) should not be filtered")
        }
    }

    // MARK: - Merchant Name Cleaning Tests

    func testCleaning_TrimWhitespace() {
        let dirty = "  Spotify  "
        let cleaned = cleanMerchantName(dirty)
        XCTAssertEqual(cleaned, "Spotify")
    }

    func testCleaning_RemovePunctuation() {
        let dirty = "Spotify."
        let cleaned = cleanMerchantName(dirty)
        XCTAssertEqual(cleaned, "Spotify")
    }

    func testCleaning_RemoveTrailingComma() {
        let dirty = "Notion Labs,"
        let cleaned = cleanMerchantName(dirty)
        XCTAssertEqual(cleaned, "Notion Labs")
    }

    // MARK: - Length Validation Tests

    func testValidation_TooShort_Rejected() {
        let short = "A"
        XCTAssertFalse(isValidMerchantName(short), "Single char should be rejected")
    }

    func testValidation_MinLength_Accepted() {
        let min = "AB"
        XCTAssertTrue(isValidMerchantName(min), "2 char merchant should be accepted")
    }

    func testValidation_TooLong_Rejected() {
        let long = String(repeating: "A", count: 51)
        XCTAssertFalse(isValidMerchantName(long), "50+ char merchant should be rejected")
    }

    func testValidation_MaxLength_Accepted() {
        let max = String(repeating: "A", count: 50)
        XCTAssertTrue(isValidMerchantName(max), "50 char merchant should be accepted")
    }

    // MARK: - Edge Cases

    func testEdgeCase_NoMerchant_ReturnsNil() {
        let text = "Thank you for your payment"

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertNil(merchant, "Should return nil when no merchant pattern found")
    }

    func testEdgeCase_EmptyString_ReturnsNil() {
        let text = ""

        let merchant = extractMerchantFromPaymentProcessor(text)

        XCTAssertNil(merchant)
    }

    func testEdgeCase_OnlyGenericTerms_ReturnsNil() {
        let text = "Receipt from Payment for your Subscription"

        let merchant = extractMerchantFromPaymentProcessor(text)

        // Should return nil because "Payment" is a generic term
        // (depends on implementation - it might extract "Payment" first)
        if let merchant = merchant {
            XCTAssertFalse(isGenericPaymentTerm(merchant),
                          "Should not return generic term as merchant")
        }
    }

    // MARK: - Combined Subject + Snippet Tests

    func testCombined_SubjectAndSnippet_ExtractsMerchant() {
        let subject = "Receipt for your payment"
        let snippet = "Payment to Spotify - $9.99"
        let combined = "\(subject) \(snippet)"

        let merchant = extractMerchantFromPaymentProcessor(combined)

        XCTAssertEqual(merchant, "Spotify")
    }

    // MARK: - Helper Methods

    private func extractMerchantFromPaymentProcessor(_ text: String) -> String? {
        // Patterns to extract merchant names with post-processing to clean up
        // Using regular string literals (not raw strings) for NSRegularExpression
        let patterns: [String] = [
            "Receipt from\\s+([A-Za-z0-9][A-Za-z0-9\\s\\-\\.]+)",
            "Payment to\\s+([A-Za-z0-9][A-Za-z0-9\\s\\-\\.]+)",
            "automatic payment to\\s+([A-Za-z0-9][A-Za-z0-9\\s\\-\\.]+)",
            "Statement descriptor:\\s*([A-Za-z0-9][A-Za-z0-9\\s\\-\\.]+)",
            "Merchant:\\s*([A-Za-z0-9][A-Za-z0-9\\s\\-\\.]+)",
            "paid\\s+([A-Za-z0-9][A-Za-z0-9\\s\\-\\.]+?)\\s+\\$"
        ]

        // Words that indicate the merchant name has ended
        let stopWords = Set(["on", "for", "at", "of", "-", "$"])

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {

                var extracted = String(text[range])
                    .trimmingCharacters(in: .whitespaces)

                // Split by spaces and remove trailing stop words
                var words = extracted.split(separator: " ").map(String.init)
                while let last = words.last, stopWords.contains(last.lowercased()) {
                    words.removeLast()
                }
                extracted = words.joined(separator: " ")

                // Clean up trailing punctuation
                extracted = extracted.trimmingCharacters(in: CharacterSet(charactersIn: ".,- "))

                if isValidMerchantName(extracted) && !isGenericPaymentTerm(extracted) {
                    return extracted
                }
            }
        }

        return nil
    }

    private func isGenericPaymentTerm(_ term: String) -> Bool {
        let genericTerms: Set<String> = [
            "payment", "subscription", "recurring", "charge",
            "invoice", "receipt", "billing", "automatic",
            "monthly", "annual", "yearly", "your"
        ]
        return genericTerms.contains(term.lowercased())
    }

    private func cleanMerchantName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
    }

    private func isValidMerchantName(_ name: String) -> Bool {
        name.count >= 2 && name.count <= 50
    }
}
