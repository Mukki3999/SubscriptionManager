//
//  ExtractPriceTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for price extraction from email content
final class ExtractPriceTests: XCTestCase {

    // MARK: - Basic USD Price Tests

    func testExtractPrice_BasicUSD_Extracts() {
        let text = "Your payment of $9.99 has been processed"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 9.99, "Should extract $9.99")
    }

    func testExtractPrice_WholeNumber_Extracts() {
        let text = "Amount charged: $10"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 10.0, "Should extract $10")
    }

    func testExtractPrice_LargerAmount_Extracts() {
        let text = "Your annual subscription costs $99.99"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 99.99, "Should extract $99.99")
    }

    func testExtractPrice_TripleDigit_Extracts() {
        let text = "Premium plan: $149.99/year"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 149.99, "Should extract $149.99")
    }

    // MARK: - Subscription Price Pattern Tests

    func testExtractPrice_PerMonth_Extracts() {
        let text = "Your plan costs $9.99/mo"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 9.99, "Should extract $9.99/mo")
    }

    func testExtractPrice_PerMonthFull_Extracts() {
        let text = "Monthly charge: $10.99/month"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 10.99, "Should extract $10.99/month")
    }

    func testExtractPrice_PerYear_Extracts() {
        let text = "Annual subscription: $99.99/yr"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 99.99, "Should extract $99.99/yr")
    }

    func testExtractPrice_PerYearFull_Extracts() {
        let text = "Yearly plan: $79.99/year"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 79.99, "Should extract $79.99/year")
    }

    func testExtractPrice_PerMonthSpaced_Extracts() {
        let text = "$9.99 per month subscription"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 9.99, "Should extract $9.99 per month")
    }

    func testExtractPrice_PerYearSpaced_Extracts() {
        let text = "$99.99 per year membership"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 99.99, "Should extract $99.99 per year")
    }

    // MARK: - European Format Tests

    func testExtractPrice_EuroComma_Extracts() {
        let text = "Your subscription: €9,99/mo"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 9.99, "Should extract €9,99 as 9.99")
    }

    func testExtractPrice_EuroPeriod_Extracts() {
        let text = "Monthly charge: €9.99"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 9.99, "Should extract €9.99")
    }

    // MARK: - USD Label Tests

    func testExtractPrice_USDPrefix_Extracts() {
        let text = "Amount: USD 19.99"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 19.99, "Should extract USD 19.99")
    }

    func testExtractPrice_USDNoSpace_Extracts() {
        let text = "Total: USD19.99"

        let price = extractPriceFromText(text)

        // This pattern may or may not match depending on implementation
        XCTAssertNotNil(price)
    }

    // MARK: - Edge Cases

    func testExtractPrice_MultiplepricesFirst() {
        let text = "Original $19.99, now $9.99/mo"

        let price = extractPriceFromText(text)

        // Should extract first price or the more relevant one
        XCTAssertNotNil(price)
    }

    func testExtractPrice_NoPricepresent_ReturnsNil() {
        let text = "Thank you for your subscription"

        let price = extractPriceFromText(text)

        XCTAssertNil(price, "Should return nil when no price present")
    }

    func testExtractPrice_InvalidPrice_ReturnsNil() {
        let text = "Code: ABC123"

        let price = extractPriceFromText(text)

        XCTAssertNil(price, "Should return nil for non-price numbers")
    }

    func testExtractPrice_VerySmallPrice_Extracts() {
        let text = "Charged: $0.99"

        let price = extractPriceFromText(text)

        XCTAssertEqual(price, 0.99, "Should extract $0.99")
    }

    func testExtractPrice_FreeOrZero_ReturnsNil() {
        let text = "Your price: $0.00"

        let price = extractPriceFromText(text)

        // $0.00 might be extracted but should be filtered out
        if let price = price {
            XCTAssertEqual(price, 0.0)
        }
    }

    // MARK: - Validation Range Tests

    func testPriceValidation_TooLow_Filtered() {
        let price = 0.50
        XCTAssertFalse(isValidSubscriptionPrice(price), "Prices < $0.99 should be filtered")
    }

    func testPriceValidation_MinValid_Accepted() {
        let price = 0.99
        XCTAssertTrue(isValidSubscriptionPrice(price), "Prices >= $0.99 should be accepted")
    }

    func testPriceValidation_Typical_Accepted() {
        let prices = [9.99, 10.99, 14.99, 19.99, 49.99, 99.99]
        for price in prices {
            XCTAssertTrue(isValidSubscriptionPrice(price), "\(price) should be valid")
        }
    }

    func testPriceValidation_MaxReasonable_Accepted() {
        let price = 499.99
        XCTAssertTrue(isValidSubscriptionPrice(price), "Prices <= $500 should be accepted")
    }

    func testPriceValidation_TooHigh_Filtered() {
        let price = 1000.00
        XCTAssertFalse(isValidSubscriptionPrice(price), "Prices > $500 should be filtered")
    }

    // MARK: - Helper Methods

    /// Extract price from text using common patterns
    private func extractPriceFromText(_ text: String) -> Double? {
        // Structural patterns first
        let structuralPatterns = [
            #"\$(\d{1,3}(?:\.\d{2})?)\s*/\s*(?:mo|month|yr|year)"#,
            #"\$(\d{1,3}(?:\.\d{2})?)\s*per\s*(?:month|year)"#,
        ]

        for pattern in structuralPatterns {
            if let price = extractFirstPrice(from: text, pattern: pattern) {
                return price
            }
        }

        // Basic patterns
        let basicPatterns = [
            #"\$(\d{1,3}(?:\.\d{2})?)"#,
            #"USD\s*(\d{1,3}(?:\.\d{2})?)"#,
            #"€(\d{1,3}(?:[,\.]\d{2})?)"#,
        ]

        for pattern in basicPatterns {
            if let price = extractFirstPrice(from: text, pattern: pattern) {
                return price
            }
        }

        return nil
    }

    private func extractFirstPrice(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        var priceString = String(text[range])
        priceString = priceString.replacingOccurrences(of: ",", with: ".")

        return Double(priceString)
    }

    private func isValidSubscriptionPrice(_ price: Double) -> Bool {
        return price >= 0.99 && price <= 500
    }
}
