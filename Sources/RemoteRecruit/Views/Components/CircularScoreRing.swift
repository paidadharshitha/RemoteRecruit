// CircularScoreRing.swift
// RemoteRecruit

import SwiftUI

/// Animated circular ring that displays an ATS compatibility score (0–100).
public struct CircularScoreRing: View {

    let score: Int
    let lineWidth: CGFloat

    public init(score: Int, lineWidth: CGFloat = 12) {
        self.score = min(max(score, 0), 100)
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Self.trackColor, lineWidth: lineWidth)

            // Foreground arc
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: score)

            // Center label
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(ringColor)

                Text("ATS Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
    }

    #if os(iOS)
    private static let trackColor = Color(uiColor: .systemFill)
    #else
    private static let trackColor = Color(NSColor.controlBackgroundColor)
    #endif

    private var ringColor: Color {
        switch score {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}
