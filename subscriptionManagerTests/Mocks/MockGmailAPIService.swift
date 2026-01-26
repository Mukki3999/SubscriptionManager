//
//  MockGmailAPIService.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation
@testable import subscriptionManager

// MARK: - Gmail API Service Protocol

/// Protocol defining the Gmail API service interface for mocking
protocol GmailAPIServiceProtocol {
    func searchMessages(
        accessToken: String,
        query: String,
        maxResults: Int,
        metadataOnly: Bool
    ) async throws -> [GmailMessage]

    func fetchNewMessageIds(
        accessToken: String,
        startHistoryId: String,
        labelId: String?
    ) async throws -> IncrementalSyncResult

    func getCurrentHistoryId(accessToken: String) async throws -> String?

    func fetchMessagesInBatches(
        accessToken: String,
        messageRefs: [MessageReference],
        format: GmailAPIService.MessageFormat,
        useCache: Bool
    ) async throws -> [GmailMessage]

    func fetchMessagesByIds(
        accessToken: String,
        messageIds: [String],
        format: GmailAPIService.MessageFormat,
        useCache: Bool
    ) async throws -> [GmailMessage]

    func fetchMessage(
        accessToken: String,
        messageId: String,
        format: GmailAPIService.MessageFormat
    ) async throws -> GmailMessage
}

// MARK: - Mock Gmail API Service

/// Mock implementation of Gmail API service for testing
final class MockGmailAPIService: GmailAPIServiceProtocol {

    // MARK: - Configuration

    /// Messages to return from search
    var messagesToReturn: [GmailMessage] = []

    /// Error to throw (if set)
    var errorToThrow: Error?

    /// History ID to return
    var historyIdToReturn: String? = "12345"

    /// Incremental sync result to return
    var incrementalSyncResult: IncrementalSyncResult?

    /// Delay before returning results (simulates network)
    var simulatedDelay: TimeInterval = 0

    /// Whether to simulate rate limiting
    var shouldSimulateRateLimit: Bool = false
    var rateLimitCount: Int = 1

    /// Track method calls
    private(set) var searchMessagesCalls: [(query: String, maxResults: Int)] = []
    private(set) var fetchMessagesCalls: [String] = []
    private(set) var fetchNewMessageIdsCalls: [String] = []

    // MARK: - Protocol Implementation

    func searchMessages(
        accessToken: String,
        query: String,
        maxResults: Int,
        metadataOnly: Bool
    ) async throws -> [GmailMessage] {
        searchMessagesCalls.append((query: query, maxResults: maxResults))

        if let delay = Optional(simulatedDelay), delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldSimulateRateLimit && rateLimitCount > 0 {
            rateLimitCount -= 1
            throw GmailAPIError.rateLimited
        }

        if let error = errorToThrow {
            throw error
        }

        return Array(messagesToReturn.prefix(maxResults))
    }

    func fetchNewMessageIds(
        accessToken: String,
        startHistoryId: String,
        labelId: String?
    ) async throws -> IncrementalSyncResult {
        fetchNewMessageIdsCalls.append(startHistoryId)

        if let delay = Optional(simulatedDelay), delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if let error = errorToThrow {
            throw error
        }

        return incrementalSyncResult ?? IncrementalSyncResult(
            newMessageIds: [],
            latestHistoryId: startHistoryId,
            historyExpired: false,
            historyRecordsProcessed: 0
        )
    }

    func getCurrentHistoryId(accessToken: String) async throws -> String? {
        if let error = errorToThrow {
            throw error
        }
        return historyIdToReturn
    }

    func fetchMessagesInBatches(
        accessToken: String,
        messageRefs: [MessageReference],
        format: GmailAPIService.MessageFormat,
        useCache: Bool
    ) async throws -> [GmailMessage] {
        if let error = errorToThrow {
            throw error
        }

        // Return matching messages from messagesToReturn
        let requestedIds = Set(messageRefs.map { $0.id })
        return messagesToReturn.filter { requestedIds.contains($0.id) }
    }

    func fetchMessagesByIds(
        accessToken: String,
        messageIds: [String],
        format: GmailAPIService.MessageFormat,
        useCache: Bool
    ) async throws -> [GmailMessage] {
        if let error = errorToThrow {
            throw error
        }

        let requestedIds = Set(messageIds)
        return messagesToReturn.filter { requestedIds.contains($0.id) }
    }

    func fetchMessage(
        accessToken: String,
        messageId: String,
        format: GmailAPIService.MessageFormat
    ) async throws -> GmailMessage {
        fetchMessagesCalls.append(messageId)

        if let error = errorToThrow {
            throw error
        }

        guard let message = messagesToReturn.first(where: { $0.id == messageId }) else {
            throw GmailAPIError.requestFailed
        }

        return message
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        messagesToReturn = []
        errorToThrow = nil
        historyIdToReturn = "12345"
        incrementalSyncResult = nil
        simulatedDelay = 0
        shouldSimulateRateLimit = false
        rateLimitCount = 1
        searchMessagesCalls = []
        fetchMessagesCalls = []
        fetchNewMessageIdsCalls = []
    }

    /// Configure for rate limit testing
    func configureRateLimiting(times: Int) {
        shouldSimulateRateLimit = true
        rateLimitCount = times
    }

    /// Configure for successful responses with messages
    func configureSuccess(messages: [GmailMessage]) {
        errorToThrow = nil
        messagesToReturn = messages
    }

    /// Configure for error responses
    func configureError(_ error: GmailAPIError) {
        errorToThrow = error
    }
}
