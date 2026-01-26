//
//  GmailAPIService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import Foundation

class GmailAPIService {

    // MARK: - Configuration

    private let baseURL = "https://gmail.googleapis.com/gmail/v1/users/me"

    // MARK: - Rate Limiting

    private let rateLimiter = RateLimiter()
    private let circuitBreaker = CircuitBreaker()
    private let batchSizer = AdaptiveBatchSizer()

    // MARK: - Cache Integration

    private let messageCache = GmailMessageCache.shared
    private let syncStateManager = GmailSyncStateManager.shared

    /// Message format for API requests
    enum MessageFormat: String {
        case full = "full"
        case metadata = "metadata"
        case minimal = "minimal"
    }

    // MARK: - Incremental Sync (History API)

    /// Fetch new message IDs added since last sync using Gmail History API
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - startHistoryId: History ID from last successful sync
    ///   - labelId: Optional label filter (e.g., "INBOX")
    /// - Returns: IncrementalSyncResult with new message IDs or expired flag
    func fetchNewMessageIds(
        accessToken: String,
        startHistoryId: String,
        labelId: String? = nil
    ) async throws -> IncrementalSyncResult {
        var allNewMessageIds: [String] = []
        var pageToken: String? = nil
        var latestHistoryId = startHistoryId
        var totalRecords = 0

        repeat {
            var urlComponents = URLComponents(string: "\(baseURL)/history")!

            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "startHistoryId", value: startHistoryId),
                URLQueryItem(name: "historyTypes", value: "messageAdded")
            ]

            if let labelId = labelId {
                queryItems.append(URLQueryItem(name: "labelId", value: labelId))
            }

            if let pageToken = pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            urlComponents.queryItems = queryItems

            guard let url = urlComponents.url else {
                throw GmailAPIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GmailAPIError.requestFailed
            }

            // History ID expired - need full scan
            if httpResponse.statusCode == 404 {
                return .expired
            }

            if httpResponse.statusCode == 401 {
                throw GmailAPIError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw GmailAPIError.requestFailed
            }

            let historyResponse = try JSONDecoder().decode(HistoryListResponse.self, from: data)

            // Extract new message IDs from history records
            if let history = historyResponse.history {
                for record in history {
                    if let messagesAdded = record.messagesAdded {
                        for added in messagesAdded {
                            allNewMessageIds.append(added.message.id)
                        }
                    }
                }
                totalRecords += history.count
            }

            // Update latest history ID
            if let newHistoryId = historyResponse.historyId {
                latestHistoryId = newHistoryId
            }

            pageToken = historyResponse.nextPageToken

        } while pageToken != nil

        return IncrementalSyncResult(
            newMessageIds: allNewMessageIds,
            latestHistoryId: latestHistoryId,
            historyExpired: false,
            historyRecordsProcessed: totalRecords
        )
    }

    /// Get the current profile's history ID (for initial sync)
    func getCurrentHistoryId(accessToken: String) async throws -> String? {
        let urlString = "\(baseURL)/profile"

        guard let url = URL(string: urlString) else {
            throw GmailAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailAPIError.requestFailed
        }

        if httpResponse.statusCode == 401 {
            throw GmailAPIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GmailAPIError.requestFailed
        }

        let profile = try JSONDecoder().decode(GmailProfile.self, from: data)
        return profile.historyId
    }

    // MARK: - Search Messages

    /// Search messages with query, supporting metadata-only mode for faster scanning
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - query: Gmail search query
    ///   - maxResults: Maximum messages to return
    ///   - metadataOnly: If true, fetches only headers and snippet (faster)
    func searchMessages(
        accessToken: String,
        query: String,
        maxResults: Int = 100,
        metadataOnly: Bool = false
    ) async throws -> [GmailMessage] {
        var allMessageRefs: [MessageReference] = []
        var pageToken: String? = nil

        // Paginate through results
        repeat {
            let refs = try await fetchMessageReferences(
                accessToken: accessToken,
                query: query,
                maxResults: min(maxResults - allMessageRefs.count, 100),
                pageToken: pageToken
            )

            allMessageRefs.append(contentsOf: refs.messages)
            pageToken = refs.nextPageToken

        } while pageToken != nil && allMessageRefs.count < maxResults

        // Fetch message details in batches for performance
        let format: MessageFormat = metadataOnly ? .metadata : .full
        return try await fetchMessagesInBatches(
            accessToken: accessToken,
            messageRefs: Array(allMessageRefs.prefix(maxResults)),
            format: format
        )
    }

    // MARK: - Fetch Message References (IDs only)

    private func fetchMessageReferences(
        accessToken: String,
        query: String?,
        maxResults: Int,
        pageToken: String?
    ) async throws -> (messages: [MessageReference], nextPageToken: String?) {
        var urlComponents = URLComponents(string: "\(baseURL)/messages")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        if let query = query {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw GmailAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailAPIError.requestFailed
        }

        if httpResponse.statusCode == 401 {
            throw GmailAPIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GmailAPIError.requestFailed
        }

        let listResponse = try JSONDecoder().decode(MessageListResponse.self, from: data)

        return (listResponse.messages ?? [], listResponse.nextPageToken)
    }

    // MARK: - Batch Fetch Messages

    /// Fetch messages in batches with cache support
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - messageRefs: Message references to fetch
    ///   - format: Message format (full, metadata, minimal)
    ///   - useCache: Whether to check cache before fetching (default: true)
    /// - Returns: Array of GmailMessage objects
    func fetchMessagesInBatches(
        accessToken: String,
        messageRefs: [MessageReference],
        format: MessageFormat = .full,
        useCache: Bool = true
    ) async throws -> [GmailMessage] {
        let messageIds = messageRefs.map { $0.id }

        // Check cache first if enabled
        var cachedMessages: [GmailMessage] = []
        var uncachedIds: [String] = []

        if useCache {
            let cacheResult = await messageCache.getBatch(messageIds)
            cachedMessages = cacheResult.cached
            uncachedIds = cacheResult.missing
        } else {
            uncachedIds = messageIds
        }

        // If all messages were cached, return early
        guard !uncachedIds.isEmpty else {
            return cachedMessages
        }

        // Create refs for uncached messages only
        let uncachedRefs = messageRefs.filter { uncachedIds.contains($0.id) }

        var fetchedMessages: [GmailMessage] = []

        // Get current batch size from adaptive sizer
        let currentBatchSize = await batchSizer.getCurrentBatchSize()

        // Process uncached messages in batches for better performance
        for batchStart in stride(from: 0, to: uncachedRefs.count, by: currentBatchSize) {
            let batchEnd = min(batchStart + currentBatchSize, uncachedRefs.count)
            let batch = Array(uncachedRefs[batchStart..<batchEnd])

            // Add throttle delay between batches (except first batch)
            if batchStart > 0 {
                try? await Task.sleep(nanoseconds: UInt64(RateLimitConfiguration.batchThrottleDelay * 1_000_000_000))
            }

            // Fetch batch concurrently with specified format and retry logic
            let batchMessages = await withTaskGroup(of: GmailMessage?.self) { group in
                for ref in batch {
                    group.addTask {
                        try? await self.fetchMessageWithRetry(
                            accessToken: accessToken,
                            messageId: ref.id,
                            format: format
                        )
                    }
                }

                var results: [GmailMessage] = []
                for await message in group {
                    if let message = message {
                        results.append(message)
                    }
                }
                return results
            }

            fetchedMessages.append(contentsOf: batchMessages)
        }

        // Cache the newly fetched messages
        if useCache && !fetchedMessages.isEmpty {
            await messageCache.setBatch(fetchedMessages)
        }

        // Combine cached and fetched messages
        return cachedMessages + fetchedMessages
    }

    /// Fetch messages by IDs (convenience method for incremental sync)
    func fetchMessagesByIds(
        accessToken: String,
        messageIds: [String],
        format: MessageFormat = .metadata,
        useCache: Bool = true
    ) async throws -> [GmailMessage] {
        let refs = messageIds.map { MessageReference(id: $0, threadId: "") }
        return try await fetchMessagesInBatches(
            accessToken: accessToken,
            messageRefs: refs,
            format: format,
            useCache: useCache
        )
    }

    // MARK: - Fetch Message

    /// Fetch a single message with retry logic
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - messageId: Gmail message ID
    ///   - format: Response format (full, metadata, minimal)
    private func fetchMessageWithRetry(
        accessToken: String,
        messageId: String,
        format: MessageFormat = .full
    ) async throws -> GmailMessage {
        var urlComponents = URLComponents(string: "\(baseURL)/messages/\(messageId)")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "format", value: format.rawValue)
        ]

        if format == .metadata {
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "Subject"))
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "From"))
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "Date"))
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "List-Unsubscribe"))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw GmailAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await executeWithRetry {
            try await URLSession.shared.data(for: request)
        }

        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    /// Fetch a single message with specified format
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - messageId: Gmail message ID
    ///   - format: Response format (full, metadata, minimal)
    func fetchMessage(
        accessToken: String,
        messageId: String,
        format: MessageFormat = .full
    ) async throws -> GmailMessage {
        var urlComponents = URLComponents(string: "\(baseURL)/messages/\(messageId)")!

        // Add format parameter for optimized fetching
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "format", value: format.rawValue)
        ]

        // For metadata format, specify which headers we need
        if format == .metadata {
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "Subject"))
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "From"))
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "Date"))
            queryItems.append(URLQueryItem(name: "metadataHeaders", value: "List-Unsubscribe"))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw GmailAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailAPIError.requestFailed
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            throw GmailAPIError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GmailAPIError.requestFailed
        }

        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    // MARK: - Search Related Emails

    /// Search for emails related to a subscription (for cancellation help)
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - senderDomain: Domain of the subscription sender (e.g., "netflix.com")
    ///   - merchantName: Name of the merchant/subscription
    ///   - maxResults: Maximum messages to return
    /// - Returns: Array of related Gmail messages
    func searchRelatedEmails(
        accessToken: String,
        senderDomain: String?,
        merchantName: String,
        maxResults: Int = 20
    ) async throws -> [GmailMessage] {
        // Build search query
        // Query: from:@{domain} OR subject:({name} AND (cancel OR subscription OR billing OR unsubscribe))
        var queryParts: [String] = []

        if let domain = senderDomain, !domain.isEmpty {
            queryParts.append("from:@\(domain)")
        }

        // Search for subscription-related keywords in subject with merchant name
        let keywords = "(cancel OR subscription OR billing OR unsubscribe OR account OR payment)"
        let subjectQuery = "subject:(\(merchantName) \(keywords))"
        queryParts.append(subjectQuery)

        let query = queryParts.joined(separator: " OR ")

        return try await searchMessages(
            accessToken: accessToken,
            query: query,
            maxResults: maxResults,
            metadataOnly: true
        )
    }

    // MARK: - Rate Limited Request Execution

    /// Execute an API request with retry logic and circuit breaker protection
    /// - Parameters:
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: GmailAPIError if all retries fail or circuit breaker is open
    private func executeWithRetry(
        _ operation: @escaping () async throws -> (Data, URLResponse)
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        // Check circuit breaker first
        guard await circuitBreaker.canProceed() else {
            throw GmailAPIError.circuitBreakerOpen
        }

        while true {
            // Wait for rate limiter
            await rateLimiter.waitForNextRequest()

            do {
                let (data, response) = try await operation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GmailAPIError.requestFailed
                }

                // Handle rate limiting (429)
                if httpResponse.statusCode == 429 {
                    // Record failure for circuit breaker and batch sizer
                    await circuitBreaker.recordFailure()
                    await batchSizer.recordRateLimit()

                    // Parse Retry-After header if present
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    await rateLimiter.parseRetryAfterHeader(retryAfter)

                    // Check if we've exceeded max retries
                    if await rateLimiter.hasExceededMaxRetries {
                        throw GmailAPIError.maxRetriesExceeded
                    }

                    // Apply exponential backoff
                    await rateLimiter.applyBackoff()
                    continue
                }

                // Handle unauthorized (401)
                if httpResponse.statusCode == 401 {
                    await circuitBreaker.recordFailure()
                    throw GmailAPIError.unauthorized
                }

                // Handle other errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    await circuitBreaker.recordFailure()
                    throw GmailAPIError.requestFailed
                }

                // Success - record and reset
                await circuitBreaker.recordSuccess()
                await batchSizer.recordSuccess()
                await rateLimiter.resetRetryState()

                return (data, httpResponse)

            } catch let error as GmailAPIError {
                throw error
            } catch {
                await circuitBreaker.recordFailure()

                // Check if we've exceeded max retries
                if await rateLimiter.hasExceededMaxRetries {
                    throw GmailAPIError.maxRetriesExceeded
                }

                // Apply backoff and retry
                await rateLimiter.applyBackoff()
            }
        }
    }

    // MARK: - List Messages

    /// List messages without search query (basic listing)
    func listMessages(accessToken: String, maxResults: Int = 100) async throws -> [GmailMessage] {
        let urlString = "\(baseURL)/messages?maxResults=\(maxResults)"

        guard let url = URL(string: urlString) else {
            throw GmailAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GmailAPIError.requestFailed
        }

        let listResponse = try JSONDecoder().decode(MessageListResponse.self, from: data)

        // Fetch full message details using batch fetching
        guard let refs = listResponse.messages, !refs.isEmpty else {
            return []
        }

        return try await fetchMessagesInBatches(
            accessToken: accessToken,
            messageRefs: Array(refs.prefix(maxResults)),
            format: .full
        )
    }
}

// MARK: - Models

struct MessageListResponse: Codable {
    let messages: [MessageReference]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct MessageReference: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable, Identifiable {
    let id: String
    let threadId: String
    let snippet: String
    let payload: MessagePayload?
    let internalDate: String?

    var subject: String {
        payload?.headers?.first { $0.name.lowercased() == "subject" }?.value ?? "No Subject"
    }

    var from: String {
        payload?.headers?.first { $0.name.lowercased() == "from" }?.value ?? "Unknown"
    }

    /// Message date (defaults to now if parsing fails)
    var date: Date {
        guard let internalDate = internalDate,
              let timestamp = TimeInterval(internalDate) else {
            return Date()
        }
        return Date(timeIntervalSince1970: timestamp / 1000)
    }

    /// Check if email has List-Unsubscribe header (common in subscription emails)
    var hasUnsubscribeHeader: Bool {
        payload?.headers?.contains { $0.name.lowercased() == "list-unsubscribe" } ?? false
    }
}

struct MessagePayload: Codable {
    let headers: [MessageHeader]?
    let body: MessageBody?
}

struct MessageHeader: Codable {
    let name: String
    let value: String
}

struct MessageBody: Codable {
    let data: String?
}

// MARK: - Errors

enum GmailAPIError: LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed
    case unauthorized
    case rateLimited
    case historyExpired
    case circuitBreakerOpen
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gmail API URL"
        case .requestFailed:
            return "Gmail API request failed"
        case .decodingFailed:
            return "Failed to decode Gmail API response"
        case .unauthorized:
            return "Gmail access token expired. Please sign in again."
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .historyExpired:
            return "Sync history expired. Performing full scan."
        case .circuitBreakerOpen:
            return "Service temporarily unavailable. Please try again later."
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded. Please try again later."
        }
    }
}

// MARK: - History API Models

struct HistoryListResponse: Codable {
    let history: [HistoryRecord]?
    let nextPageToken: String?
    let historyId: String?
}

struct HistoryRecord: Codable {
    let id: String
    let messages: [MessageReference]?
    let messagesAdded: [MessageAdded]?
    let messagesDeleted: [MessageDeleted]?
    let labelsAdded: [LabelChange]?
    let labelsRemoved: [LabelChange]?
}

struct MessageAdded: Codable {
    let message: MessageReference
}

struct MessageDeleted: Codable {
    let message: MessageReference
}

struct LabelChange: Codable {
    let message: MessageReference
    let labelIds: [String]?
}

struct GmailProfile: Codable {
    let emailAddress: String
    let messagesTotal: Int?
    let threadsTotal: Int?
    let historyId: String?
}
