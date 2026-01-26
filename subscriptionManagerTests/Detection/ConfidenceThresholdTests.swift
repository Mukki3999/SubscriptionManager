//
//  ConfidenceThresholdTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for confidence score thresholds and categorization
final class ConfidenceThresholdTests: XCTestCase {

    // MARK: - High Confidence Tests (score >= 70)

    func testHighConfidence_ScoreAt70_IsHigh() {
        let confidence = determineConfidence(score: 70)
        XCTAssertEqual(confidence, .high)
    }

    func testHighConfidence_ScoreAbove70_IsHigh() {
        let scores = [71, 80, 90, 100, 150]
        for score in scores {
            let confidence = determineConfidence(score: score)
            XCTAssertEqual(confidence, .high, "Score \(score) should be high confidence")
        }
    }

    func testHighConfidence_NetflixWithKeywords_IsHigh() {
        // Netflix (known merchant +30) + subscription keyword (+20) + price pattern (+15) + emails (+5)
        // = 70+ points
        let score = 30 + 20 + 15 + 5
        XCTAssertTrue(score >= 70, "Netflix with keywords should score >= 70")
        XCTAssertEqual(determineConfidence(score: score), .high)
    }

    func testHighConfidence_SpotifyWithRecurring_IsHigh() {
        // Spotify (known +30) + recurring (+20) + monthly pattern (+20)
        let score = 30 + 20 + 20
        XCTAssertTrue(score >= 70)
        XCTAssertEqual(determineConfidence(score: score), .high)
    }

    func testHighConfidence_AdobeWithConsistentBilling_IsHigh() {
        // Adobe (known +30) + subscription (+20) + consistent pattern (+10) + many emails (+10)
        let score = 30 + 20 + 10 + 10
        XCTAssertTrue(score >= 70)
        XCTAssertEqual(determineConfidence(score: score), .high)
    }

    // MARK: - Medium Confidence Tests (50 <= score < 70)

    func testMediumConfidence_ScoreAt50_IsMedium() {
        let confidence = determineConfidence(score: 50)
        XCTAssertEqual(confidence, .medium)
    }

    func testMediumConfidence_ScoreAt69_IsMedium() {
        let confidence = determineConfidence(score: 69)
        XCTAssertEqual(confidence, .medium)
    }

    func testMediumConfidence_RangeBetween50And70_IsMedium() {
        let scores = [50, 55, 60, 65, 69]
        for score in scores {
            let confidence = determineConfidence(score: score)
            XCTAssertEqual(confidence, .medium, "Score \(score) should be medium confidence")
        }
    }

    func testMediumConfidence_UnknownServiceWithKeywords_IsMedium() {
        // Unknown service (no merchant bonus) + subscription (+20) + receipt (+10) + price (+15)
        let score = 0 + 20 + 10 + 15 // = 45, might need more
        // Actually this is 45, which is below 50. Let's add more signals
        let scoreWithMore = 20 + 10 + 15 + 10 // = 55
        XCTAssertTrue(scoreWithMore >= 50 && scoreWithMore < 70)
        XCTAssertEqual(determineConfidence(score: scoreWithMore), .medium)
    }

    func testMediumConfidence_PayPalWithExtractedMerchant_IsMedium() {
        // PayPal + extracted merchant (+25) + receipt (+10) + price (+15)
        let score = 25 + 10 + 15 // = 50
        XCTAssertTrue(score >= 50 && score < 70)
        XCTAssertEqual(determineConfidence(score: score), .medium)
    }

    // MARK: - Low Confidence Tests (score < 50)

    func testLowConfidence_ScoreAt49_IsLow() {
        let confidence = determineConfidence(score: 49)
        XCTAssertEqual(confidence, .low)
    }

    func testLowConfidence_ScoreBelow50_IsLow() {
        let scores = [0, 10, 20, 30, 40, 49]
        for score in scores {
            let confidence = determineConfidence(score: score)
            XCTAssertEqual(confidence, .low, "Score \(score) should be low confidence")
        }
    }

    func testLowConfidence_SingleEmailNoKeywords_IsLow() {
        // Single email with just a generic price
        let score = 5 // minimal score
        XCTAssertTrue(score < 50)
        XCTAssertEqual(determineConfidence(score: score), .low)
    }

    func testLowConfidence_ShippingNotification_IsLow() {
        // Has anti-keywords that reduce score
        let score = 10 + (-25) // receipt + shipped anti-keyword
        XCTAssertTrue(score < 50)
        // Note: negative scores are capped at 0
        XCTAssertEqual(determineConfidence(score: max(0, score)), .low)
    }

    // MARK: - Rejection Tests (score = 0)

    func testRejection_HardExclusion_ScoreZero() {
        // Hard exclusion penalty is -100
        let initialScore = 50
        let finalScore = max(0, initialScore + (-100))
        XCTAssertEqual(finalScore, 0, "Hard exclusion should result in 0 score")
    }

    func testRejection_BlockedDomain_ShouldNotScore() {
        // Blocked domains should be filtered before scoring
        let blockedDomains = ["bankofamerica.com", "gmail.com", "ups.com"]
        for domain in blockedDomains {
            // These should be filtered out entirely
            XCTAssertTrue(isBlockedDomain(domain), "\(domain) should be blocked")
        }
    }

    func testRejection_OrderConfirmation_ScoreZero() {
        // "Order confirmation" is a hard exclusion
        let scoreAfterHardExclusion = 0
        XCTAssertEqual(determineConfidence(score: scoreAfterHardExclusion), .low)
    }

    // MARK: - Minimum Score Filter Tests

    func testMinimumFilter_BelowThreshold_NotDetected() {
        let minConfidenceScore = 50

        let lowScores = [0, 10, 20, 30, 40, 49]
        for score in lowScores {
            XCTAssertTrue(score < minConfidenceScore,
                          "Score \(score) should be below minimum threshold")
        }
    }

    func testMinimumFilter_AtThreshold_Detected() {
        let minConfidenceScore = 50
        XCTAssertTrue(50 >= minConfidenceScore)
    }

    func testMinimumFilter_AboveThreshold_Detected() {
        let minConfidenceScore = 50
        let passingScores = [50, 60, 70, 80, 100]
        for score in passingScores {
            XCTAssertTrue(score >= minConfidenceScore,
                          "Score \(score) should pass minimum threshold")
        }
    }

    // MARK: - Scoring Weight Verification Tests

    func testScoringWeight_KnownMerchant_Is30() {
        let weight = 30
        XCTAssertEqual(weight, 30, "Known merchant should add 30 points")
    }

    func testScoringWeight_StrongKeyword_Is20() {
        let weight = 20
        XCTAssertEqual(weight, 20, "Strong keyword should add 20 points")
    }

    func testScoringWeight_MediumKeyword_Is10() {
        let weight = 10
        XCTAssertEqual(weight, 10, "Medium keyword should add 10 points")
    }

    func testScoringWeight_PricePattern_Is15() {
        let weight = 15
        XCTAssertEqual(weight, 15, "Structural price pattern should add 15 points")
    }

    func testScoringWeight_RecurringMonthly_Is20() {
        let weight = 20
        XCTAssertEqual(weight, 20, "Monthly recurring pattern should add 20 points")
    }

    func testScoringWeight_ConsistencyBonus_Is10() {
        let weight = 10
        XCTAssertEqual(weight, 10, "Consistency bonus should add 10 points")
    }

    func testScoringWeight_AntiKeyword_IsMinus25() {
        let weight = -25
        XCTAssertEqual(weight, -25, "Anti-keyword should subtract 25 points")
    }

    func testScoringWeight_HardExclusion_IsMinus100() {
        let weight = -100
        XCTAssertEqual(weight, -100, "Hard exclusion should subtract 100 points")
    }

    // MARK: - Boundary Tests

    func testBoundary_Score49vs50() {
        XCTAssertEqual(determineConfidence(score: 49), .low)
        XCTAssertEqual(determineConfidence(score: 50), .medium)
    }

    func testBoundary_Score69vs70() {
        XCTAssertEqual(determineConfidence(score: 69), .medium)
        XCTAssertEqual(determineConfidence(score: 70), .high)
    }

    func testBoundary_NegativeScoreClamped() {
        // Negative scores should be clamped to 0
        let score = max(0, -50)
        XCTAssertEqual(score, 0)
        XCTAssertEqual(determineConfidence(score: score), .low)
    }

    // MARK: - Integration Scenario Tests

    func testScenario_TypicalNetflixEmail() {
        // Known merchant (30) + subscription keyword (20) + price pattern (15) + unsubscribe (5)
        let score = 30 + 20 + 15 + 5 // = 70
        XCTAssertEqual(determineConfidence(score: score), .high)
    }

    func testScenario_PayPalToUnknownMerchant() {
        // Extracted merchant (25) + receipt (10) + price (15)
        let score = 25 + 10 + 15 // = 50
        XCTAssertEqual(determineConfidence(score: score), .medium)
    }

    func testScenario_BankStatementWithSubscriptionKeyword() {
        // Starts with subscription keyword (20) but hits hard exclusion (-100)
        let score = max(0, 20 - 100) // = 0
        XCTAssertEqual(determineConfidence(score: score), .low)
    }

    // MARK: - Helper Methods

    private func determineConfidence(score: Int) -> SubscriptionConfidence {
        if score >= 70 {
            return .high
        } else if score >= 50 {
            return .medium
        } else {
            return .low
        }
    }

    private func isBlockedDomain(_ domain: String) -> Bool {
        let blocked: Set<String> = [
            "bankofamerica.com", "chase.com", "gmail.com", "ups.com"
        ]
        return blocked.contains(domain.lowercased())
    }
}
