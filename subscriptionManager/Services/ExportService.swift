//
//  ExportService.swift
//  subscriptionManager
//
//  Created by Claude on 1/20/26.
//

import Foundation

// MARK: - Export Service

@MainActor
final class ExportService {

    static let shared = ExportService()

    private init() {}

    // MARK: - CSV Export

    /// Export subscriptions to CSV format
    /// - Parameter subscriptions: Array of subscriptions to export
    /// - Returns: URL to the temporary CSV file
    func exportToCSV(_ subscriptions: [Subscription]) -> URL? {
        let csvString = buildDetailedCSV(subscriptions)
        let fileName = "subscriptions_export_\(formattedCurrentDate()).csv"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("ExportService: Failed to write CSV file - \(error.localizedDescription)")
            return nil
        }
    }

    /// Export a bundle of files (detailed CSV + summary CSV + HTML report).
    /// - Parameters:
    ///   - subscriptions: Array of subscriptions to export
    ///   - includeReport: Whether to include the HTML report and summary CSV
    /// - Returns: URLs to the temporary files
    func exportBundle(_ subscriptions: [Subscription], includeReport: Bool) -> [URL]? {
        var urls: [URL] = []

        guard let detailedCSVURL = exportToCSV(subscriptions) else { return nil }
        urls.append(detailedCSVURL)

        guard includeReport else { return urls }

        let dateStamp = formattedCurrentDate()
        let tempDirectory = FileManager.default.temporaryDirectory

        if let summaryCSV = buildSummaryCSV(subscriptions) {
            let summaryName = "subscriptions_summary_\(dateStamp).csv"
            let summaryURL = tempDirectory.appendingPathComponent(summaryName)
            do {
                try summaryCSV.write(to: summaryURL, atomically: true, encoding: .utf8)
                urls.append(summaryURL)
            } catch {
                print("ExportService: Failed to write summary CSV - \(error.localizedDescription)")
            }
        }

        if let reportHTML = buildHTMLReport(subscriptions) {
            let reportName = "subscriptions_report_\(dateStamp).html"
            let reportURL = tempDirectory.appendingPathComponent(reportName)
            do {
                try reportHTML.write(to: reportURL, atomically: true, encoding: .utf8)
                urls.append(reportURL)
            } catch {
                print("ExportService: Failed to write HTML report - \(error.localizedDescription)")
            }
        }

        let validURLs = validatedURLs(urls)
        return validURLs.isEmpty ? nil : validURLs
    }

    // MARK: - Helpers

    private func buildDetailedCSV(_ subscriptions: [Subscription]) -> String {
        var csvString = "Name,Category,Billing Cycle,Price,Monthly Equivalent,Annual Cost,Next Billing Date,Last Charge Date,Detection Source,Confidence,Sender Email\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let sorted = subscriptions.sorted { monthlyEquivalent(for: $0) > monthlyEquivalent(for: $1) }

        for subscription in sorted {
            let name = escapeCSVField(subscription.name)
            let category = escapeCSVField(categoryFor(subscription).rawValue)
            let billingCycle = subscription.billingCycle.rawValue
            let price = formatNumber(subscription.price)
            let monthly = formatNumber(monthlyEquivalent(for: subscription))
            let annual = formatNumber(monthlyEquivalent(for: subscription) * 12)
            let nextBillingDate = escapeCSVField(formattedDate(subscription.nextBillingDate, formatter: dateFormatter))
            let lastChargeDate = escapeCSVField(formattedDate(subscription.lastChargeDate, formatter: dateFormatter))
            let detectionSource = subscription.detectionSource.rawValue
            let confidence = subscription.confidence.rawValue
            let senderEmail = escapeCSVField(subscription.senderEmail)

            let row = "\(name),\(category),\(billingCycle),\(price),\(monthly),\(annual),\(nextBillingDate),\(lastChargeDate),\(detectionSource),\(confidence),\(senderEmail)\n"
            csvString.append(row)
        }

        return csvString
    }

    private func buildSummaryCSV(_ subscriptions: [Subscription]) -> String? {
        let summaries = categorySummaries(from: subscriptions)
        guard !summaries.isEmpty else { return nil }

        var csvString = "Category,Subscriptions,Monthly Total,Annual Total\n"
        let totalMonthly = summaries.reduce(0) { $0 + $1.monthlyTotal }
        let totalAnnual = totalMonthly * 12
        let totalSubscriptions = summaries.reduce(0) { $0 + $1.count }

        for summary in summaries {
            let category = escapeCSVField(summary.category.rawValue)
            let count = "\(summary.count)"
            let monthly = formatNumber(summary.monthlyTotal)
            let annual = formatNumber(summary.monthlyTotal * 12)
            csvString.append("\(category),\(count),\(monthly),\(annual)\n")
        }

        csvString.append("Total,\(totalSubscriptions),\(formatNumber(totalMonthly)),\(formatNumber(totalAnnual))\n")
        return csvString
    }

    private func buildHTMLReport(_ subscriptions: [Subscription]) -> String? {
        let summaries = categorySummaries(from: subscriptions)
        guard !summaries.isEmpty else { return nil }

        let totalMonthly = summaries.reduce(0) { $0 + $1.monthlyTotal }
        let totalAnnual = totalMonthly * 12
        let totalSubscriptions = summaries.reduce(0) { $0 + $1.count }
        let dateLabel = formattedCurrentDate()
        let currencyFormatter = currencyFormatter()

        let chartPalette = [
            "#5A8CD9",
            "#73B88C",
            "#D98CA6",
            "#9480C7",
            "#E0A06E",
            "#8F8F96"
        ]

        let rowsHTML = summaries.enumerated().map { index, summary in
            let percent = totalMonthly > 0 ? (summary.monthlyTotal / totalMonthly) * 100 : 0
            let width = max(2, percent)
            let color = chartPalette[index % chartPalette.count]
            let monthly = currencyFormatter.string(from: NSNumber(value: summary.monthlyTotal)) ?? "$0.00"
            return """
            <div class="bar-row">
              <div class="bar-label">\(escapeHTML(summary.category.rawValue))</div>
              <div class="bar-track">
                <div class="bar-fill" style="width: \(String(format: "%.1f", width))%; background: \(color);"></div>
              </div>
              <div class="bar-value">\(monthly)</div>
            </div>
            """
        }.joined(separator: "\n")

        let tableRows = subscriptions.sorted { monthlyEquivalent(for: $0) > monthlyEquivalent(for: $1) }.map { subscription in
            let name = escapeHTML(subscription.name)
            let category = escapeHTML(categoryFor(subscription).rawValue)
            let cycle = subscription.billingCycle.rawValue
            let monthly = currencyFormatter.string(from: NSNumber(value: monthlyEquivalent(for: subscription))) ?? "$0.00"
            let nextDate = formattedDate(subscription.nextBillingDate, formatter: reportDateFormatter())
            return """
            <tr>
              <td>\(name)</td>
              <td>\(category)</td>
              <td>\(cycle)</td>
              <td>\(monthly)</td>
              <td>\(nextDate)</td>
            </tr>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Subscription Manager Report</title>
          <style>
            :root {
              color-scheme: light;
            }
            body {
              margin: 0;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              background: #f5f5f7;
              color: #1b1b1f;
            }
            .page {
              max-width: 980px;
              margin: 24px auto 48px;
              padding: 0 20px;
            }
            .header {
              display: flex;
              justify-content: space-between;
              align-items: baseline;
            }
            .header h1 {
              font-size: 28px;
              margin: 0;
            }
            .header .date {
              color: #6b6b73;
              font-size: 14px;
            }
            .stats {
              display: grid;
              grid-template-columns: repeat(3, 1fr);
              gap: 12px;
              margin: 20px 0 28px;
            }
            .stat-card {
              background: #ffffff;
              border-radius: 14px;
              padding: 16px;
              box-shadow: 0 8px 24px rgba(0, 0, 0, 0.06);
            }
            .stat-card .label {
              font-size: 12px;
              color: #7a7a85;
              text-transform: uppercase;
              letter-spacing: 0.08em;
            }
            .stat-card .value {
              font-size: 20px;
              margin-top: 6px;
              font-weight: 600;
            }
            .section {
              background: #ffffff;
              border-radius: 16px;
              padding: 20px;
              margin-bottom: 20px;
              box-shadow: 0 10px 28px rgba(0, 0, 0, 0.06);
            }
            .section h2 {
              margin: 0 0 14px;
              font-size: 18px;
            }
            .bar-row {
              display: grid;
              grid-template-columns: 140px 1fr 90px;
              gap: 12px;
              align-items: center;
              margin-bottom: 10px;
            }
            .bar-label {
              font-size: 14px;
              color: #2f2f35;
            }
            .bar-track {
              background: #e7e7ec;
              border-radius: 999px;
              height: 10px;
              overflow: hidden;
            }
            .bar-fill {
              height: 100%;
              border-radius: 999px;
            }
            .bar-value {
              font-size: 13px;
              color: #4f4f59;
              text-align: right;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              font-size: 13px;
            }
            th, td {
              padding: 10px 8px;
              border-bottom: 1px solid #e7e7ec;
              text-align: left;
            }
            th {
              color: #6b6b73;
              font-weight: 600;
              text-transform: uppercase;
              letter-spacing: 0.08em;
              font-size: 11px;
            }
            .note {
              font-size: 12px;
              color: #7a7a85;
              margin-top: 12px;
            }
            @media (max-width: 640px) {
              .stats {
                grid-template-columns: 1fr;
              }
              .bar-row {
                grid-template-columns: 1fr;
              }
              .bar-value {
                text-align: left;
              }
            }
          </style>
        </head>
        <body>
          <div class="page">
            <div class="header">
              <h1>Subscription Manager Report</h1>
              <div class="date">Exported \(dateLabel)</div>
            </div>
            <div class="stats">
              <div class="stat-card">
                <div class="label">Total Subscriptions</div>
                <div class="value">\(totalSubscriptions)</div>
              </div>
              <div class="stat-card">
                <div class="label">Monthly Spend</div>
                <div class="value">\(currencyFormatter.string(from: NSNumber(value: totalMonthly)) ?? "$0.00")</div>
              </div>
              <div class="stat-card">
                <div class="label">Annual Projection</div>
                <div class="value">\(currencyFormatter.string(from: NSNumber(value: totalAnnual)) ?? "$0.00")</div>
              </div>
            </div>
            <div class="section">
              <h2>Category Breakdown</h2>
              \(rowsHTML)
            </div>
            <div class="section">
              <h2>Subscriptions</h2>
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Category</th>
                    <th>Cycle</th>
                    <th>Monthly</th>
                    <th>Next Bill</th>
                  </tr>
                </thead>
                <tbody>
                  \(tableRows)
                </tbody>
              </table>
              <div class="note">Monthly values are normalized from each billing cycle.</div>
            </div>
          </div>
        </body>
        </html>
        """
    }

    private struct CategorySummary {
        let category: CompanyCategory
        let monthlyTotal: Double
        let count: Int
    }

    private func categorySummaries(from subscriptions: [Subscription]) -> [CategorySummary] {
        guard !subscriptions.isEmpty else { return [] }

        var summaryMap: [CompanyCategory: (total: Double, count: Int)] = [:]
        for subscription in subscriptions {
            let category = categoryFor(subscription)
            let monthly = monthlyEquivalent(for: subscription)
            let current = summaryMap[category] ?? (0, 0)
            summaryMap[category] = (current.total + monthly, current.count + 1)
        }

        return summaryMap.map { key, value in
            CategorySummary(category: key, monthlyTotal: value.total, count: value.count)
        }
        .sorted { $0.monthlyTotal > $1.monthlyTotal }
    }

    private func categoryFor(_ subscription: Subscription) -> CompanyCategory {
        if let company = CompanyLogoService.shared.findCompany(for: subscription.name) {
            return company.category
        }
        return .other
    }

    private func monthlyEquivalent(for subscription: Subscription) -> Double {
        switch subscription.billingCycle {
        case .weekly:
            return subscription.price * 4.33
        case .monthly:
            return subscription.price
        case .quarterly:
            return subscription.price / 3
        case .yearly:
            return subscription.price / 12
        case .unknown:
            return subscription.price
        }
    }

    private func formattedDate(_ date: Date?, formatter: DateFormatter) -> String {
        guard let date else { return "Not set" }
        return formatter.string(from: date)
    }

    private func reportDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private func formatNumber(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func currencyFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Escape special characters in CSV fields
    private func escapeCSVField(_ field: String) -> String {
        // If field contains comma, newline, or quote, wrap in quotes and escape quotes
        if field.contains(",") || field.contains("\n") || field.contains("\"") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    /// Format current date for filename
    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func validatedURLs(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            FileManager.default.fileExists(atPath: url.path)
        }
    }
}
