// AuthManager.swift
// RemoteRecruit

import Foundation
import Combine
import FirebaseAuth

// MARK: - Auth Manager

/// Centralized authentication state manager that bridges Firebase Auth with AppState.
/// Used as a `@StateObject` in the App entry point and observed by RootView
/// for driving navigation transitions.
@MainActor
public final class AuthManager: ObservableObject {

    // MARK: - Published State

    /// Whether the user is currently authenticated.
    @Published private(set) var isLoggedIn: Bool = false

    /// Whether the user has uploaded and parsed their resume.
    @Published var hasUploadedResume: Bool = false

    /// Whether the user has completed the full onboarding (confirmed profile details).
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - Dependencies

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init() {
        // Sync initial state from AppState singleton
        let appState = AppState.shared
        isLoggedIn = appState.isLoggedIn
        hasUploadedResume = appState.hasUploadedResume
        hasCompletedOnboarding = appState.hasCompletedOnboarding

        // Observe AppState changes reactively
        appState.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed (proxied from AppState)

    var username: String {
        AppState.shared.username
    }

    // MARK: - Sync

    /// Call after sign-in to sync auth state.
    func syncFromFirebase() {
        AppState.shared.syncFromFirebase()
        isLoggedIn = AppState.shared.isLoggedIn
    }
}
