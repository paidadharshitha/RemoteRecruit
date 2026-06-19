// RootView.swift
// RemoteRecruit

import SwiftUI
import FirebaseAuth

// MARK: - Root View

/// App-level coordinator that gates navigation through four phases:
///
/// 1. **Unauthenticated** → Login / Signup flow
/// 2. **Authenticated + no resume** → Resume upload (`OnboardingResumeView`)
/// 3. **Resume parsed + not confirmed** → `ProfileConfirmView` (verify AI-extracted details)
/// 4. **Authenticated + confirmed** → `MainTabView`
///
/// Uses `@StateObject` on `AppState` and a `fullScreenCover` for the onboarding
/// flow (resume upload → confirm details) to ensure clean memory management.
public struct RootView: View {

    // MARK: - Dependencies

    @StateObject private var appState = AppState.shared
    private let container: DIContainer

    // MARK: - Navigation State

    @State private var showSignup = false

    // MARK: - Onboarding

    /// Whether the onboarding fullScreenCover should be shown.
    @State private var showOnboarding = false

    /// Coordinator that drives the mandatory resume upload pipeline.
    @StateObject private var onboardingCoordinator = ResumeOnboardingCoordinator(
        profileViewModel: DIContainer.shared.makeProfileViewModel()
    )

    // MARK: - Init

    public init(container: DIContainer) {
        self.container = container
    }

    // MARK: - Derived State

    /// Whether the user has passed the onboarding gate and can access the main app.
    private var canAccessMainApp: Bool {
        appState.isLoggedIn && appState.hasCompletedOnboarding
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if canAccessMainApp {
                MainTabView(container: container)
                    .transition(.opacity)
            } else {
                loginFlow
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.isLoggedIn)
        .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
        .fullScreenCover(isPresented: $showOnboarding) {
            onboardingContent
        }
        .onChange(of: appState.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                beginOnboardingIfNeeded()
            } else {
                showOnboarding = false
            }
        }
        .onChange(of: appState.hasCompletedOnboarding) { _, completed in
            if completed {
                showOnboarding = false
            }
        }
    }

    // MARK: - Onboarding Content

    @ViewBuilder
    private var onboardingContent: some View {
        switch onboardingCoordinator.phase {
        case .resumeUpload, .processing, .failed:
            OnboardingResumeView(
                coordinator: onboardingCoordinator,
                onContinue: handleOnboardingComplete
            )

        case .confirmDetails:
            ProfileConfirmView(
                coordinator: onboardingCoordinator,
                onConfirm: handleOnboardingComplete
            )

        case .complete:
            // This case should be caught by onChange(hasCompletedOnboarding),
            // but handle it defensively.
            Color.clear
                .onAppear {
                    handleOnboardingComplete()
                }

        case .skipped:
            Color.clear
                .onAppear {
                    handleOnboardingComplete()
                }
        }
    }

    // MARK: - Login Flow

    @ViewBuilder
    private var loginFlow: some View {
        if showSignup {
            SignupView(
                viewModel: container.makeAuthenticationViewModel(),
                onSignupSuccess: handleLoginSuccess
            )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        } else {
            LoginView(
                viewModel: container.makeAuthenticationViewModel(),
                onLoginSuccess: handleLoginSuccess,
                onNavigateToSignup: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showSignup = true
                    }
                }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            ))
        }
    }

    // MARK: - Handlers

    private func handleLoginSuccess() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showSignup = false
        }
    }

    /// Called after successful onboarding (resume upload + profile confirm).
    private func handleOnboardingComplete() {
        appState.hasCompletedOnboarding = true
    }

    /// Begins the onboarding flow if the user is authenticated but hasn't completed it.
    private func beginOnboardingIfNeeded() {
        guard !appState.hasCompletedOnboarding else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        showOnboarding = true

        Task {
            await onboardingCoordinator.beginOnboarding(userId: uid)

            // If profile already exists with data, skip onboarding entirely
            if case .skipped = onboardingCoordinator.phase {
                appState.hasCompletedOnboarding = true
            }
        }
    }
}
