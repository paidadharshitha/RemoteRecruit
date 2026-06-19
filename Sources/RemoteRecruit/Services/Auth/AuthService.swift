// AuthService.swift
// RemoteRecruit

import Foundation
import Combine
import FirebaseAuth

// MARK: - Auth Service

/// Manages Firebase Authentication flows and exposes the current user reactively.
@MainActor
public final class AuthService: ObservableObject {

    // MARK: - Published State

    /// The currently signed-in Firebase user, or `nil` if signed out.
    @Published public private(set) var user: User?

    /// Whether an auth operation is currently in progress.
    @Published public private(set) var isLoading = false

    // MARK: - Private

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    // MARK: - Singleton

    public static let shared = AuthService()

    private init() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            self?.user = firebaseUser
            // Sync the centralized AppState so the UI reflects the restored session.
            AppState.shared.syncFromFirebase()
        }
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    // MARK: - Sign Up

    /// Creates a new account with the given email and password.
    public func signUp(
        email: String,
        password: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard !isLoading else { return }
        isLoading = true

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            self?.isLoading = false
            completion(error)
        }
    }

    // MARK: - Sign In

    /// Signs in an existing user with the given email and password.
    public func signIn(
        email: String,
        password: String,
        completion: @escaping (Error?) -> Void
    ) {
        guard !isLoading else { return }
        isLoading = true

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            self?.isLoading = false
            completion(error)
        }
    }

    // MARK: - Sign In (Google)

    /// Authenticates with Firebase using a Google ID token and access token.
    /// - Parameters:
    ///   - idToken: The Google ID token from GIDSignInResult.
    ///   - accessToken: The optional Google access token.
    /// - Returns: The authenticated Firebase `User`.
    public func signInWithGoogle(idToken: String, accessToken: String?) async throws -> User {
        guard !isLoading else { throw AuthError.credentialError("An auth operation is already in progress.") }
        isLoading = true
        defer { isLoading = false }

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken ?? "")
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    // MARK: - Sign In (Apple)

    /// Authenticates with Firebase using an Apple AuthCredential.
    /// - Parameter credential: The `AuthCredential` from `ASAuthorizationAppleIDCredential`.
    /// - Returns: The authenticated Firebase `User`.
    public func signInWithApple(credential: AuthCredential) async throws -> User {
        guard !isLoading else { throw AuthError.credentialError("An auth operation is already in progress.") }
        isLoading = true
        defer { isLoading = false }

        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    // MARK: - Sign Out

    /// Signs out the current user.
    public func signOut() {
        try? Auth.auth().signOut()
    }
}
