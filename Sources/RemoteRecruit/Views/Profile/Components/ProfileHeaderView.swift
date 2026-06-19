//
//  ProfileHeaderView.swift
//  RemoteRecruit
//
//  Clean horizontal header card for the profile screen.
//

import SwiftUI

// MARK: - ProfileHeaderView

/// Displays the user's avatar, name, email, domain, and edit action in a clean horizontal card.
public struct ProfileHeaderView: View {

    // MARK: Properties

    private let profile: UserProfile
    private let profileDisplayName: String
    private let isEditingBasicInfo: Bool
    private var onToggleEdit: () -> Void

    // MARK: Initializer

    public init(
        profile: UserProfile,
        profileDisplayName: String,
        isEditingBasicInfo: Bool,
        onToggleEdit: @escaping () -> Void
    ) {
        self.profile = profile
        self.profileDisplayName = profileDisplayName
        self.isEditingBasicInfo = isEditingBasicInfo
        self.onToggleEdit = onToggleEdit
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 16) {
            // Avatar
            avatarView

            // Name, domain, email
            VStack(alignment: .leading, spacing: 4) {
                Text(profileDisplayName)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !profile.domain.isEmpty {
                    Text(profile.domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !profile.email.isEmpty {
                    Text(profile.email)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Edit button
            Button(action: onToggleEdit) {
                Image(systemName: isEditingBasicInfo ? "checkmark.circle.fill" : "pencil.circle")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Subviews

    private var avatarView: some View {
        let initial = profileDisplayName.trimmingCharacters(in: .whitespaces)
            .uppercased()
            .prefix(1)

        return Text(initial)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}
