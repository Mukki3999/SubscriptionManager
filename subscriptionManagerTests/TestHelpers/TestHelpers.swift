//
//  TestHelpers.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation
import XCTest

// MARK: - Date Helpers

extension Date {

    /// Create a date relative to now
    /// - Parameter days: Number of days from now (negative for past)
    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date())!
    }

    /// Create a date relative to now
    /// - Parameter months: Number of months from now (negative for past)
    static func monthsFromNow(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: Date())!
    }

    /// Create a date relative to now
    /// - Parameter weeks: Number of weeks from now (negative for past)
    static func weeksFromNow(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: Date())!
    }

    /// Create a date at a specific interval
    static func fromInterval(_ interval: TimeInterval) -> Date {
        Date(timeIntervalSince1970: interval)
    }

    /// Convert to Gmail internal date format (milliseconds since epoch)
    var gmailInternalDate: String {
        String(Int(timeIntervalSince1970 * 1000))
    }
}

// MARK: - Async Test Helpers

/// Helper to wait for async conditions in tests
func waitForCondition(
    timeout: TimeInterval = 5.0,
    pollingInterval: TimeInterval = 0.1,
    condition: @escaping () async -> Bool
) async -> Bool {
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
    }

    return false
}

/// Execute async work with a timeout
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        guard let result = try await group.next() else {
            throw TimeoutError()
        }

        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? { "Operation timed out" }
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Run an async test with a timeout
    func runAsyncTest(
        timeout: TimeInterval = 10.0,
        file: StaticString = #file,
        line: UInt = #line,
        _ test: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test")

        Task {
            do {
                try await withTimeout(seconds: timeout) {
                    try await test()
                }
                expectation.fulfill()
            } catch is TimeoutError {
                XCTFail("Test timed out after \(timeout) seconds", file: file, line: line)
                expectation.fulfill()
            } catch {
                XCTFail("Test failed with error: \(error)", file: file, line: line)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout + 1)
    }
}

// MARK: - String Test Helpers

extension String {

    /// Create a random string of specified length
    static func random(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    /// Create a random email address
    static func randomEmail(domain: String = "test.com") -> String {
        "\(random(length: 8))@\(domain)"
    }

    /// Create a random UUID string
    static var randomUUID: String {
        UUID().uuidString
    }
}

// MARK: - Collection Test Helpers

extension Collection {

    /// Check if collection contains all elements matching predicate
    func allSatisfy(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        for element in self {
            if try !predicate(element) {
                return false
            }
        }
        return true
    }
}

// MARK: - Test Data Namespaces

enum TestConstants {
    static let validAccessToken = "test_access_token_12345"
    static let expiredAccessToken = "expired_access_token"
    static let invalidAccessToken = "invalid_token"

    static let testEmail = "test@example.com"
    static let testRefreshToken = "test_refresh_token"

    enum Domains {
        static let netflix = "netflix.com"
        static let spotify = "spotify.com"
        static let adobe = "adobe.com"
        static let paypal = "paypal.com"
        static let bankOfAmerica = "bankofamerica.com"
        static let chase = "chase.com"
    }
}
