//
//  ProfileDashboardCard.swift
//  RemoteRecruit
//
//  Reusable navigation card for profile dashboard sections.
//

import SwiftUI

// MARK: - ProfileDashboardCard

/// A tappable card that navigates to a profile sub-section (Projects, Skills).
/// Uses a configurable gradient for unique color per section.
public struct ProfileDashboardCard: View {

    // MARK: Properties

    private let icon: String
    private let title: String
    private let count: Int
    private let subtitle: String
    private let gradientStart: Color
    private let gradientEnd: Color
    private let destination: DashboardSection

    // MARK: Initializer

    public init(
        icon: String,
        title: String,
        count: Int,
        subtitle: String,
        gradientStart: Color,
        gradientEnd: Color,
        destination: DashboardSection
    ) {
        self.icon = icon
        self.title = title
        self.count = count
        self.subtitle = subtitle
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
        self.destination = destination
    }

    // MARK: Body

    public var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 14) {
                // Icon badge
                iconBadge

                // Title & count
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        countBadge
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Subviews

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)

            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var countBadge: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
    }
}
