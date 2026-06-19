//
//  ExperienceTimelineCard.swift
//  RemoteRecruit
//
//  Expandable timeline card for work experience entries.
//

import SwiftUI

// MARK: - ExperienceTimelineCard

/// A card that shows work experience entries in an expandable timeline format.
/// Tapping the card header expands to show a summary, and a chevron navigates to the full detail view.
struct ExperienceTimelineCard: View {

    // MARK: Properties

    let experiences: [WorkExperience]
    var destination: DashboardSection = .experience

    @State private var isExpanded = false

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (tappable to expand)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Icon badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)

                        Image(systemName: "briefcase.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Experience")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Text(experienceSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Count badge
                    Text("\(experiences.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )

                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)

                if experiences.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "briefcase")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("No work experience added yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(experiences.prefix(3).enumerated()), id: \.element.id) { index, exp in
                            timelineRow(exp: exp, isFirst: index == 0)

                            if index < min(experiences.count, 3) - 1 {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }

                        if experiences.count > 3 {
                            Text("+ \(experiences.count - 3) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    }

                    // View all button
                    NavigationLink(value: destination) {
                        HStack {
                            Text("View All Experience")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.purple)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple.opacity(0.7))
                        }
                        .padding(.top, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Helpers

    private var experienceSubtitle: String {
        experiences.count == 0 ? "Add your work history" : "\(experiences.count) position\(experiences.count == 1 ? "" : "s")"
    }

    private func timelineRow(exp: WorkExperience, isFirst: Bool) -> some View {
        HStack(spacing: 12) {
            // Timeline dot
            VStack(spacing: 0) {
                Circle()
                    .fill(isFirst ? Color.purple : Color.purple.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
            .frame(width: 28)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(exp.role.isEmpty ? "Untitled Role" : exp.role)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !exp.company.isEmpty {
                        Text(exp.company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !exp.duration.isEmpty {
                        Text(exp.duration)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !exp.description.isEmpty {
                    Text(exp.description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
