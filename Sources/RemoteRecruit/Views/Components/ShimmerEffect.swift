// ShimmerEffect.swift
// RemoteRecruit

import SwiftUI

// MARK: - Shimmer Modifier

/// A repeating linear gradient that animates across a view, creating a shimmer/skeleton effect.
public struct ShimmerModifier: ViewModifier {

    @State private var phase: CGFloat = 0
    let duration: Double
    let color: Color

    public init(duration: Double = 1.5, color: Color = .gray) {
        self.duration = duration
        self.color = color
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let shimmerWidth = max(geo.size.width, 0) * 2
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: color.opacity(0.4), location: 0.3),
                            .init(color: color.opacity(0.08), location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: shimmerWidth)
                    .offset(x: -max(geo.size.width, 0) + (phase * shimmerWidth))
                }
                .clipped()
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Applies a shimmer loading animation overlay.
    public func shimmer(duration: Double = 1.5) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// MARK: - Shimmer Placeholder Views

/// A single rectangular shimmer placeholder block.
public struct ShimmerBlock: View {

    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    public init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Rectangle()
            .fill(Self.fillColor)
            .frame(width: max(width, 0), height: max(height, 0))
            .clipShape(RoundedRectangle(cornerRadius: max(cornerRadius, 0)))
            .shimmer()
    }

    #if os(iOS)
    static let fillColor = Color(uiColor: .systemFill)
    #else
    static let fillColor = Color(NSColor.controlBackgroundColor)
    #endif
}

/// A shimmer placeholder that mimics a text block with random-looking widths.
public struct ShimmerTextBlock: View {

    let lines: Int
    let lineHeight: CGFloat
    let maxWidth: CGFloat
    let spacing: CGFloat

    public init(lines: Int = 3, lineHeight: CGFloat = 14, maxWidth: CGFloat = 300, spacing: CGFloat = 8) {
        self.lines = lines
        self.lineHeight = lineHeight
        self.maxWidth = maxWidth
        self.spacing = spacing
    }

    public var body: some View {
        GeometryReader { geo in
            let availableWidth = max(geo.size.width, 0)
            let resolvedMaxWidth = maxWidth.isFinite ? maxWidth : availableWidth
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<lines, id: \.self) { index in
                    let isLast = index == lines - 1
                    let widthRatio: CGFloat = isLast ? 0.5 : CGFloat.random(in: 0.7...1.0)
                    ShimmerBlock(
                        width: resolvedMaxWidth * widthRatio,
                        height: lineHeight,
                        cornerRadius: lineHeight / 2
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: max(CGFloat(lines) * (lineHeight + spacing), 0))
    }
}

// MARK: - Resume Optimizer Shimmer Skeleton

/// Pre-built shimmer skeleton matching the ResumeOptimizerView layout.
public struct ResumeOptimizerShimmer: View {

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width - 32, 100)
            VStack(spacing: 24) {
                // Simulated Resume Input
                ShimmerBlock(width: 120, height: 14)
                ShimmerBlock(width: w, height: 120, cornerRadius: 12)

                // Simulated JD Input
                ShimmerBlock(width: 120, height: 14)
                ShimmerBlock(width: w, height: 100, cornerRadius: 12)

                // Simulated Analyze Button
                ShimmerBlock(width: w, height: 50, cornerRadius: 25)

                // Simulated Score Ring
                HStack {
                    Spacer()
                    Circle()
                        .fill(ShimmerBlock.fillColor)
                        .frame(width: 140, height: 140)
                        .shimmer()
                    Spacer()
                }

                // Simulated Results
                ShimmerBlock(width: 200, height: 16)
                ShimmerTextBlock(lines: 2, maxWidth: w)

                ShimmerBlock(width: 180, height: 16)
                ShimmerTextBlock(lines: 3, maxWidth: w)

                ShimmerBlock(width: 160, height: 16)
                ShimmerTextBlock(lines: 4, maxWidth: w)

                // Simulated Optimized Resume Section
                ShimmerBlock(width: 180, height: 20, cornerRadius: 10)
                ShimmerTextBlock(lines: 3, maxWidth: w)
                ShimmerTextBlock(lines: 2, maxWidth: w)
                ShimmerTextBlock(lines: 4, maxWidth: w)
            }
            .padding()
        }
    }
}
