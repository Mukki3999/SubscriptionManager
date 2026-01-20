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
    private let batchSize = 15 // Concurrent requests (increased for better performance)

    /// Message format for API requests
    enum MessageFormat: String {
        case full = "full"
        case metadata = "metadata"
        case minimal = "minimal"
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

    private func fetchMessagesInBatches(
        accessToken: String,
        messageRefs: [MessageReference],
        format: MessageFormat = .full
    ) async throws -> [GmailMessage] {
        var messages: [GmailMessage] = []

        // Process in batches for better performance
        for batchStart in stride(from: 0, to: messageRefs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, messageRefs.count)
            let batch = Array(messageRefs[batchStart..<batchEnd])

            // Fetch batch concurrently with specified format
            let batchMessages = await withTaskGroup(of: GmailMessage?.self) { group in
                for ref in batch {
                    group.addTask {
                        try? await self.fetchMessage(
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

            messages.append(contentsOf: batchMessages)
        }

        return messages
    }

    // MARK: - Fetch Message

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
        }
    }
}
