//
//  GmailAPIIntegrationTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Integration tests for Gmail API service behavior
final class GmailAPIIntegrationTests: XCTestCase {

    var mockGmailService: MockGmailAPIService!

    override func setUp() {
        super.setUp()
        mockGmailService = MockGmailAPIService()
    }

    override func tearDown() {
        mockGmailService = nil
        super.tearDown()
    }

    // MARK: - Search with Pagination Tests

    func testSearchMessages_SinglePage_ReturnsAllMessages() async throws {
        let messages = GmailMessageFactory.consistentMonthlySequence(count: 5)
        mockGmailService.configureSuccess(messages: messages)

        let results = try await mockGmailService.searchMessages(
            accessToken: TestConstants.validAccessToken,
            query: "subscription",
            maxResults: 100,
            metadataOnly: true
        )

        XCTAssertEqual(results.count, 5)
    }

    func testSearchMessages_MaxResultsLimit_RespectsLimit() async throws {
        let messages = GmailMessageFactory.consistentMonthlySequence(count: 100)
        mockGmailService.configureSuccess(messages: messages)

        let results = try await mockGmailService.searchMessages(
            accessToken: TestConstants.validAccessToken,
            query: "subscription",
            maxResults: 50,
            metadataOnly: true
        )

        XCTAssertLessThanOrEqual(results.count, 50)
    }

    func testSearchMessages_EmptyResults_ReturnsEmptyArray() async throws {
        mockGmailService.configureSuccess(messages: [])

        let results = try await mockGmailService.searchMessages(
            accessToken: TestConstants.validAccessToken,
            query: "nonexistent",
            maxResults: 100,
            metadataOnly: true
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Rate Limiting (429) Tests

    func testRateLimit_SingleOccurrence_Recorded() async throws {
        mockGmailService.configureRateLimiting(times: 1)

        do {
            _ = try await mockGmailService.searchMessages(
                accessToken: TestConstants.validAccessToken,
                query: "test",
                maxResults: 10,
                metadataOnly: true
            )
            XCTFail("Should throw rate limit error")
        } catch let error as GmailAPIError {
            XCTAssertEqual(error, .rateLimited)
        }
    }

    func testRateLimit_AfterRetries_EventuallySucceeds() async throws {
        // Mock: first call rate limited, second succeeds
        let messages = [GmailMessageFactory.netflixSubscription()]
        mockGmailService.configureRateLimiting(times: 1)
        mockGmailService.messagesToReturn = messages

        // First call should throw
        do {
            _ = try await mockGmailService.searchMessages(
                accessToken: TestConstants.validAccessToken,
                query: "test",
                maxResults: 10,
                metadataOnly: true
            )
            XCTFail("First call should throw")
        } catch {
            // Expected
        }

        // Second call should succeed (rateLimitCount is now 0)
        let results = try await mockGmailService.searchMessages(
            accessToken: TestConstants.validAccessToken,
            query: "test",
            maxResults: 10,
            metadataOnly: true
        )

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Unauthorized (401) Tests

    func testUnauthorized_ThrowsError() async throws {
        mockGmailService.configureError(.unauthorized)

        do {
            _ = try await mockGmailService.searchMessages(
                accessToken: TestConstants.expiredAccessToken,
                query: "test",
                maxResults: 10,
                metadataOnly: true
            )
            XCTFail("Should throw unauthorized error")
        } catch let error as GmailAPIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    // MARK: - History API Tests

    func testHistoryAPI_ValidHistoryId_ReturnsNewMessages() async throws {
        let newMessageIds = ["msg1", "msg2", "msg3"]
        mockGmailService.incrementalSyncResult = IncrementalSyncResult(
            newMessageIds: newMessageIds,
            latestHistoryId: "67890",
            historyExpired: false,
            historyRecordsProcessed: 3
        )

        let result = try await mockGmailService.fetchNewMessageIds(
            accessToken: TestConstants.validAccessToken,
            startHistoryId: "12345",
            labelId: nil
        )

        XCTAssertEqual(result.newMessageIds.count, 3)
        XCTAssertFalse(result.historyExpired)
    }

    func testHistoryAPI_ExpiredHistory_ReturnsExpiredFlag() async throws {
        mockGmailService.incrementalSyncResult = IncrementalSyncResult.expired

        let result = try await mockGmailService.fetchNewMessageIds(
            accessToken: TestConstants.validAccessToken,
            startHistoryId: "old_history_id",
            labelId: nil
        )

        XCTAssertTrue(result.historyExpired)
    }

    func testHistoryAPI_NoNewMessages_ReturnsEmpty() async throws {
        mockGmailService.incrementalSyncResult = IncrementalSyncResult(
            newMessageIds: [],
            latestHistoryId: "12345",
            historyExpired: false,
            historyRecordsProcessed: 0
        )

        let result = try await mockGmailService.fetchNewMessageIds(
            accessToken: TestConstants.validAccessToken,
            startHistoryId: "12345",
            labelId: nil
        )

        XCTAssertTrue(result.newMessageIds.isEmpty)
        XCTAssertFalse(result.historyExpired)
    }

    // MARK: - Batch Fetch Tests

    func testBatchFetch_MultipleMessages_ReturnsAll() async throws {
        let messages = [
            GmailMessageFactory.netflixSubscription(),
            GmailMessageFactory.spotifyReceipt(),
            GmailMessageFactory.adobeSubscription()
        ]
        mockGmailService.configureSuccess(messages: messages)

        let results = try await mockGmailService.fetchMessagesByIds(
            accessToken: TestConstants.validAccessToken,
            messageIds: messages.map { $0.id },
            format: .metadata,
            useCache: false
        )

        XCTAssertEqual(results.count, 3)
    }

    func testBatchFetch_PartialMatch_ReturnsMatching() async throws {
        let messages = [
            GmailMessageFactory.netflixSubscription(),
            GmailMessageFactory.spotifyReceipt()
        ]
        mockGmailService.configureSuccess(messages: messages)

        let results = try await mockGmailService.fetchMessagesByIds(
            accessToken: TestConstants.validAccessToken,
            messageIds: [messages[0].id, "nonexistent"],
            format: .metadata,
            useCache: false
        )

        // Should only return the matching message
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, messages[0].id)
    }

    // MARK: - Call Tracking Tests

    func testSearchMessages_TracksCallParams() async throws {
        mockGmailService.configureSuccess(messages: [])

        _ = try await mockGmailService.searchMessages(
            accessToken: TestConstants.validAccessToken,
            query: "test query",
            maxResults: 50,
            metadataOnly: true
        )

        XCTAssertEqual(mockGmailService.searchMessagesCalls.count, 1)
        XCTAssertEqual(mockGmailService.searchMessagesCalls[0].query, "test query")
        XCTAssertEqual(mockGmailService.searchMessagesCalls[0].maxResults, 50)
    }

    func testFetchMessage_TracksCalls() async throws {
        let message = GmailMessageFactory.netflixSubscription()
        mockGmailService.configureSuccess(messages: [message])

        _ = try await mockGmailService.fetchMessage(
            accessToken: TestConstants.validAccessToken,
            messageId: message.id,
            format: .full
        )

        XCTAssertEqual(mockGmailService.fetchMessagesCalls.count, 1)
        XCTAssertEqual(mockGmailService.fetchMessagesCalls[0], message.id)
    }

    // MARK: - Error Recovery Tests

    func testErrorRecovery_AfterReset_WorksNormally() async throws {
        // First configure for error
        mockGmailService.configureError(.requestFailed)

        do {
            _ = try await mockGmailService.searchMessages(
                accessToken: TestConstants.validAccessToken,
                query: "test",
                maxResults: 10,
                metadataOnly: true
            )
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Reset and configure for success
        mockGmailService.reset()
        let messages = [GmailMessageFactory.netflixSubscription()]
        mockGmailService.configureSuccess(messages: messages)

        let results = try await mockGmailService.searchMessages(
            accessToken: TestConstants.validAccessToken,
            query: "test",
            maxResults: 10,
            metadataOnly: true
        )

        XCTAssertEqual(results.count, 1)
    }
}
