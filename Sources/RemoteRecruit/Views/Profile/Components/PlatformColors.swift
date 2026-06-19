//
//  PlatformColors.swift
//  RemoteRecruit
//
//  Cross-platform color helpers for iOS/macOS.
//

import SwiftUI

/// Provides platform-appropriate system background colors.
enum PlatformColors {
    /// Primary background color (systemBackground on iOS, windowBackgroundColor on macOS).
    static var systemBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Secondary background color (secondarySystemBackground on iOS, controlBackgroundColor on macOS).
    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
