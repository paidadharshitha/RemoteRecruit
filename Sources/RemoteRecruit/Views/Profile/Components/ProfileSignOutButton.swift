//
//  ProfileSignOutButton.swift
//  RemoteRecruit
//
//  Sign out button with destructive card styling.
//

import SwiftUI

// MARK: - ProfileSignOutButton

/// A card-styled destructive button for signing out.
public struct ProfileSignOutButton: View {

    // MARK: Properties

    private var onSignOut: () -> Void

    // MARK: Initializer

    public init(onSignOut: @escaping () -> Void) {
        self.onSignOut = onSignOut
    }

    // MARK: Body

    public var body: some View {
        Button(action: onSignOut) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.body.weight(.medium))

                Text("Sign Out")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }
}
