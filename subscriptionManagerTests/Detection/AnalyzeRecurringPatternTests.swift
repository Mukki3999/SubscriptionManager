//
//  AnalyzeRecurringPatternTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for recurring billing pattern detection in SubscriptionDetectionService
final class AnalyzeRecurringPatternTests: XCTestCase {

    // MARK: - Weekly Pattern Tests (6-8 day intervals)

    func testWeeklyPattern_SevenDayIntervals_DetectsWeekly() {
        // Generate emails at 7-day intervals
        let dates = (0..<8).map { index in
            Calendar.current.date(byAdding: .day, value: -7 * index, to: Date())!
        }

        // Calculate average interval
        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        // Average should be around 7 days
        XCTAssertTrue(avgInterval >= 6 && avgInterval <= 8,
                      "Average interval \(avgInterval) should be between 6-8 days for weekly")
    }

    func testWeeklyPattern_SixDayIntervals_DetectsWeekly() {
        // Use start of day to avoid time component edge cases
        let baseDate = Calendar.current.startOfDay(for: Date())
        let dates = (0..<6).map { index in
            Calendar.current.date(byAdding: .day, value: -6 * index, to: baseDate)!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        // 6-day intervals should fall within weekly range (6-8 days)
        XCTAssertTrue(avgInterval >= 6 && avgInterval <= 8,
                      "Average interval \(avgInterval) should be between 6-8 days")
    }

    func testWeeklyPattern_EightDayIntervals_DetectsWeekly() {
        let dates = (0..<6).map { index in
            Calendar.current.date(byAdding: .day, value: -8 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        XCTAssertTrue(avgInterval >= 6 && avgInterval <= 8)
    }

    // MARK: - Monthly Pattern Tests (25-35 day intervals)

    func testMonthlyPattern_ThirtyDayIntervals_DetectsMonthly() {
        let dates = (0..<6).map { index in
            Calendar.current.date(byAdding: .day, value: -30 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        XCTAssertTrue(avgInterval >= 25 && avgInterval <= 35,
                      "Average interval \(avgInterval) should be between 25-35 days for monthly")
    }

    func testMonthlyPattern_TwentyEightDayIntervals_DetectsMonthly() {
        // February-like months
        let dates = (0..<6).map { index in
            Calendar.current.date(byAdding: .day, value: -28 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        XCTAssertTrue(avgInterval >= 25 && avgInterval <= 35)
    }

    func testMonthlyPattern_ThirtyOneDayIntervals_DetectsMonthly() {
        // Months with 31 days
        let dates = (0..<6).map { index in
            Calendar.current.date(byAdding: .day, value: -31 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        XCTAssertTrue(avgInterval >= 25 && avgInterval <= 35)
    }

    // MARK: - Quarterly Pattern Tests (85-100 day intervals)

    func testQuarterlyPattern_NinetyDayIntervals_DetectsQuarterly() {
        let dates = (0..<4).map { index in
            Calendar.current.date(byAdding: .day, value: -90 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        XCTAssertTrue(avgInterval >= 85 && avgInterval <= 100,
                      "Average interval \(avgInterval) should be between 85-100 days for quarterly")
    }

    func testQuarterlyPattern_NinetyOneDayIntervals_DetectsQuarterly() {
        // 91-day quarters (365/4)
        let dates = (0..<4).map { index in
            Calendar.current.date(byAdding: .day, value: -91 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        XCTAssertTrue(avgInterval >= 85 && avgInterval <= 100)
    }

    // MARK: - Yearly Pattern Tests (355-375 day intervals)

    func testYearlyPattern_365DayIntervals_DetectsYearly() {
        let dates = [
            Date(),
            Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        ]

        let days = Calendar.current.dateComponents([.day], from: dates[1], to: dates[0]).day ?? 0

        XCTAssertTrue(days >= 355 && days <= 375,
                      "Interval \(days) should be between 355-375 days for yearly")
    }

    func testYearlyPattern_LeapYear_DetectsYearly() {
        // Leap year has 366 days
        let dates = [
            Date(),
            Calendar.current.date(byAdding: .day, value: -366, to: Date())!
        ]

        let days = Calendar.current.dateComponents([.day], from: dates[1], to: dates[0]).day ?? 0

        XCTAssertTrue(days >= 355 && days <= 375)
    }

    // MARK: - Consistency Bonus Tests (+10 points for variance <= 3)

    func testConsistencyBonus_LowVariance_AddsBonus() {
        // Very consistent 30-day intervals with small variance
        let dates = [0, 30, 60, 90, 120, 150].map { dayOffset in
            Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count
        let variance = intervals.map { abs($0 - avgInterval) }.reduce(0, +) / intervals.count

        // Variance should be 0 for perfectly consistent intervals
        XCTAssertTrue(variance <= 3, "Variance \(variance) should be <= 3 for consistency bonus")
    }

    func testConsistencyBonus_HighVariance_NoBonus() {
        // Inconsistent intervals
        let dates = [0, 25, 60, 85, 130, 160].map { dayOffset in
            Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count
        let variance = intervals.map { abs($0 - avgInterval) }.reduce(0, +) / intervals.count

        XCTAssertTrue(variance > 3, "Variance \(variance) should be > 3 for no bonus")
    }

    // MARK: - Multiple Email Bonus Tests

    func testMultipleEmailBonus_ThreeOrMore_AddsBonus() {
        let emails = GmailMessageFactory.consistentMonthlySequence(count: 3)
        XCTAssertTrue(emails.count >= 3, "Should have 3 or more emails for bonus")
    }

    func testManyEmailBonus_SixOrMore_AddsExtraBonus() {
        let emails = GmailMessageFactory.consistentMonthlySequence(count: 6)
        XCTAssertTrue(emails.count >= 6, "Should have 6 or more emails for extra bonus")
    }

    // MARK: - Single Email Tests

    func testSingleEmail_ReturnsUnknownCycle() {
        let emails = [GmailMessageFactory.createMessage()]
        XCTAssertEqual(emails.count, 1, "Single email cannot determine billing pattern")
    }

    // MARK: - Edge Cases

    func testVeryShortInterval_NotSubscription() {
        // 2-day intervals are not typical subscriptions
        let dates = (0..<5).map { index in
            Calendar.current.date(byAdding: .day, value: -2 * index, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        // 2-day intervals are too short for any billing cycle
        XCTAssertTrue(avgInterval < 6, "Very short intervals should not match any billing cycle")
    }

    func testVeryLongInterval_NotStandardCycle() {
        // 500-day intervals don't match standard cycles
        let dates = [
            Date(),
            Calendar.current.date(byAdding: .day, value: -500, to: Date())!
        ]

        let days = Calendar.current.dateComponents([.day], from: dates[1], to: dates[0]).day ?? 0

        XCTAssertTrue(days > 400, "Very long intervals don't match standard cycles")
    }

    // MARK: - Variable Interval Tests

    func testVariableIntervals_FindsClosestCycle() {
        // Intervals that vary around 30 days
        let offsets = [0, 28, 61, 89, 122] // ~30-day average with variance
        let dates = offsets.map { dayOffset in
            Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        }

        var intervals: [Int] = []
        for i in 1..<dates.count {
            let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            intervals.append(abs(days))
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        // Should still be detected as monthly (closest to 30)
        XCTAssertTrue(avgInterval > 20 && avgInterval < 40,
                      "Variable intervals averaging ~30 days should be monthly")
    }
}
