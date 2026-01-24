//
//  DonutChartView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/20/26.
//

import SwiftUI
import UIKit

// MARK: - Chart Color Mode

/// Controls whether chart colors match subscription card colors or use a separate muted palette.
enum ChartColorMode {
    /// Chart segment colors match each subscription card's assigned pastel color
    case matchSubscriptionCards
    /// Chart uses a separate muted palette (recommended default)
    case mutedPalette
}

// MARK: - Chart Segment

/// Represents a single segment in the donut chart.
struct ChartSegment: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let color: Color
}

// MARK: - Chart Colors

/// Muted color palette for the donut chart (distinct from subscription card colors).
enum ChartColors {
    static let mutedBlue = Color(red: 0.35, green: 0.55, blue: 0.85)
    static let mutedGreen = Color(red: 0.45, green: 0.72, blue: 0.55)
    static let mutedPink = Color(red: 0.85, green: 0.55, blue: 0.65)
    static let mutedPurple = Color(red: 0.58, green: 0.48, blue: 0.78)
    static let mutedOrange = Color(red: 0.88, green: 0.62, blue: 0.45)
    static let mutedGray = Color(red: 0.55, green: 0.55, blue: 0.58)

    /// Empty state ring color (no subscriptions at all)
    static let emptyRing = Color(red: 0.30, green: 0.30, blue: 0.32)

    static let palette: [Color] = [
        mutedBlue,
        mutedGreen,
        mutedPink,
        mutedPurple,
        mutedOrange,
        mutedGray
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }
}

// MARK: - Donut Chart View

/// A donut chart view displaying spending distribution across subscriptions.
/// Handles edge cases: 0 subs (empty ring), 1 sub (full circle), 2+ subs (proportional).
struct DonutChartView: View {

    let segments: [ChartSegment]
    let lineWidth: CGFloat
    let size: CGFloat

    init(segments: [ChartSegment], lineWidth: CGFloat = 12, size: CGFloat = 70) {
        self.segments = segments
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            if segments.isEmpty {
                // Edge case: No subscriptions at all → empty gray ring (match segment styling)
                DonutSegment(
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270),
                    lineWidth: lineWidth
                )
                .fill(ChartColors.emptyRing)
                .frame(width: size, height: size)
            } else if segments.count == 1 {
                // Edge case: Single subscription → full circle in one color (match multi-segment styling)
                DonutSegment(
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270),
                    lineWidth: lineWidth
                )
                .fill(segments[0].color)
                .frame(width: size, height: size)
            } else {
                // 2+ subscriptions → proportional segments
                ForEach(Array(segmentAngles.enumerated()), id: \.offset) { index, angleData in
                    DonutSegment(
                        startAngle: angleData.start,
                        endAngle: angleData.end,
                        lineWidth: lineWidth
                    )
                    .fill(segments[index].color)
                    .frame(width: size, height: size)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var totalValue: Double {
        let total = segments.reduce(0) { $0 + $1.value }
        // If all values are 0, treat each segment as equal (value of 1)
        return total > 0 ? total : Double(segments.count)
    }

    private var segmentAngles: [(start: Angle, end: Angle)] {
        guard !segments.isEmpty else { return [] }

        var angles: [(start: Angle, end: Angle)] = []
        var currentAngle: Double = -90 // Start from top

        let total = segments.reduce(0) { $0 + $1.value }
        let useEqualDistribution = total == 0

        for segment in segments {
            let proportion: Double
            if useEqualDistribution {
                // All $0 subscriptions: distribute equally
                proportion = 1.0 / Double(segments.count)
            } else {
                proportion = segment.value / total
            }

            let sweepAngle = proportion * 360
            let startAngle = Angle(degrees: currentAngle)
            let endAngle = Angle(degrees: currentAngle + sweepAngle)
            angles.append((start: startAngle, end: endAngle))
            currentAngle += sweepAngle
        }

        return angles
    }
}

// MARK: - Donut Segment Shape

struct DonutSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        return path.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }
}

// MARK: - Logo Donut Chart

struct LogoDonutItem: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let color: Color
    let logoName: String?
}

struct LogoDonutChartView: View {
    let items: [LogoDonutItem]
    let lineWidth: CGFloat
    let size: CGFloat
    var showLogos: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let chartSize = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: chartSize / 2, y: chartSize / 2)
            let radius = chartSize / 2 - lineWidth / 2
            let logoSize = max(28, lineWidth - 4)
            let logoCornerRadius: CGFloat = 8

            ZStack {
                if items.isEmpty {
                    DonutSegment(
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270),
                        lineWidth: lineWidth
                    )
                    .fill(ChartColors.emptyRing)
                    .frame(width: chartSize, height: chartSize)
                } else {
                    ForEach(segmentAngles) { segment in
                        DonutSegment(
                            startAngle: segment.start,
                            endAngle: segment.end,
                            lineWidth: lineWidth
                        )
                        .fill(segment.item.color)
                        .frame(width: chartSize, height: chartSize)
                    }

                    if showLogos {
                        ForEach(segmentAngles) { segment in
                            let midRadians = segment.mid.radians
                            let x = center.x + CGFloat(cos(midRadians)) * radius
                            let y = center.y + CGFloat(sin(midRadians)) * radius

                            logoView(for: segment.item)
                                .frame(width: logoSize, height: logoSize)
                                .background(RoundedRectangle(cornerRadius: logoCornerRadius).fill(Color.white))
                                .clipShape(RoundedRectangle(cornerRadius: logoCornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: logoCornerRadius)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(width: chartSize, height: chartSize)
        }
        .frame(width: size, height: size)
    }

    private struct SegmentAngle: Identifiable {
        let id = UUID()
        let item: LogoDonutItem
        let start: Angle
        let end: Angle
        let mid: Angle
    }

    private var segmentAngles: [SegmentAngle] {
        guard !items.isEmpty else { return [] }
        var angles: [SegmentAngle] = []
        var currentAngle: Double = -90
        let total = items.reduce(0) { $0 + $1.value }
        let useEqual = total == 0

        for item in items {
            let proportion = useEqual ? (1.0 / Double(items.count)) : (item.value / total)
            let sweep = proportion * 360
            let start = Angle(degrees: currentAngle)
            let end = Angle(degrees: currentAngle + sweep)
            let mid = Angle(degrees: currentAngle + sweep / 2)
            angles.append(SegmentAngle(item: item, start: start, end: end, mid: mid))
            currentAngle += sweep
        }

        return angles
    }

    @ViewBuilder
    private func logoView(for item: LogoDonutItem) -> some View {
        if let logoName = item.logoName, UIImage(named: logoName) != nil {
            Image(logoName)
                .resizable()
                .scaledToFit()
                .padding(2)
        } else {
            Text(String(item.name.prefix(1)))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black.opacity(0.7))
        }
    }
}

// MARK: - Chart Data Builder

/// Builds chart segments from subscription data with proper edge case handling.
struct ChartDataBuilder {

    /// Builds chart segments from subscriptions.
    /// - Parameters:
    ///   - subscriptions: Array of tuples (id, name, monthlyValue, colorIndex)
    ///   - colorMode: Color mode to use
    /// - Returns: Array of chart segments (empty ONLY if no subscriptions exist)
    static func buildSegments(
        from subscriptions: [(id: UUID, name: String, monthlyValue: Double, colorIndex: Int)],
        colorMode: ChartColorMode = .mutedPalette
    ) -> [ChartSegment] {
        // Edge case: No subscriptions at all
        guard !subscriptions.isEmpty else { return [] }

        // Build segments for ALL subscriptions (including $0 ones)
        // The chart view will handle equal distribution if all are $0
        return subscriptions.enumerated().map { index, subscription in
            let color: Color
            switch colorMode {
            case .matchSubscriptionCards:
                color = SubscriptionCardColors.color(for: subscription.colorIndex)
            case .mutedPalette:
                color = ChartColors.color(for: index)
            }

            return ChartSegment(
                id: subscription.id,
                name: subscription.name,
                value: max(0, subscription.monthlyValue), // Ensure non-negative
                color: color
            )
        }
    }
}

// MARK: - Preview

#Preview("Donut Chart Edge Cases") {
    ZStack {
        Color(red: 0.11, green: 0.11, blue: 0.12)
            .ignoresSafeArea()

        VStack(spacing: 30) {
            // 0 subscriptions - empty ring
            VStack {
                Text("0 Subscriptions")
                    .font(.caption)
                    .foregroundColor(.white)
                DonutChartView(segments: [], size: 70)
            }

            // 1 subscription with $0 - full circle
            VStack {
                Text("1 Sub ($0)")
                    .font(.caption)
                    .foregroundColor(.white)
                DonutChartView(
                    segments: [
                        ChartSegment(id: UUID(), name: "Netflix", value: 0, color: ChartColors.mutedBlue)
                    ],
                    size: 70
                )
            }

            // 2 subscriptions both $0 - equal 50-50 split
            VStack {
                Text("2 Subs (both $0)")
                    .font(.caption)
                    .foregroundColor(.white)
                DonutChartView(
                    segments: [
                        ChartSegment(id: UUID(), name: "Netflix", value: 0, color: ChartColors.mutedBlue),
                        ChartSegment(id: UUID(), name: "Spotify", value: 0, color: ChartColors.mutedGreen)
                    ],
                    size: 70
                )
            }

            // 2 subscriptions with values - proportional
            VStack {
                Text("2 Subs ($75 + $25)")
                    .font(.caption)
                    .foregroundColor(.white)
                DonutChartView(
                    segments: [
                        ChartSegment(id: UUID(), name: "Netflix", value: 75, color: ChartColors.mutedBlue),
                        ChartSegment(id: UUID(), name: "Spotify", value: 25, color: ChartColors.mutedGreen)
                    ],
                    size: 70
                )
            }

            // 4 subscriptions
            VStack {
                Text("4 Subscriptions")
                    .font(.caption)
                    .foregroundColor(.white)
                DonutChartView(
                    segments: [
                        ChartSegment(id: UUID(), name: "Netflix", value: 15.99, color: ChartColors.mutedBlue),
                        ChartSegment(id: UUID(), name: "Spotify", value: 9.99, color: ChartColors.mutedGreen),
                        ChartSegment(id: UUID(), name: "Disney+", value: 7.99, color: ChartColors.mutedPink),
                        ChartSegment(id: UUID(), name: "HBO", value: 14.99, color: ChartColors.mutedPurple)
                    ],
                    size: 70
                )
            }
        }
    }
}
