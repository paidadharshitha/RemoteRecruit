// AuthenticationViewModel.swift
// RemoteRecruit

import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

// MARK: - Auth State

/// Represents the current authentication flow state.
/// Used by the View to render loading, error, or success UI.
public enum AuthenticationFlowState: Equatable {
    case idle
    case loading
    case success
    case error(String)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

// MARK: - Auth Provider Errors

/// Typed errors for each authentication provider.
public enum AuthError: LocalizedError, Equatable, Sendable {
    case invalidEmail
    case weakPassword(minLength: Int)
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case networkError(String)
    case googleSignInFailed(String)
    case appleSignInFailed(String)
    case invalidPhoneNumber
    case invalidVerificationCode
    case smsCodeExpired
    case tooManyRequests
    case sessionExpired
    case credentialError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword(let min):
            return "Password must be at least \(min) characters."
        case .userNotFound:
            return "No account found with this email."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .googleSignInFailed(let detail):
            return "Google sign-in failed: \(detail)"
        case .appleSignInFailed(let detail):
            return "Apple sign-in failed: \(detail)"
        case .invalidPhoneNumber:
            return "Please enter a valid phone number with country code (e.g. +1 555-123-4567)."
        case .invalidVerificationCode:
            return "The verification code you entered is incorrect. Please try again."
        case .smsCodeExpired:
            return "The verification code has expired. Please request a new one."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .sessionExpired:
            return "Verification session expired. Please request a new code."
        case .credentialError(let detail):
            return "Credential error: \(detail)"
        case .unknown(let detail):
            return detail
        }
    }
}

// MARK: - Auth Providing Protocol

/// Protocol for authentication services enabling testability and DI injection.
public protocol AuthProviding: AnyObject, Sendable {
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String) async throws -> User
    func signInWithGoogle(idToken: String, accessToken: String?) async throws -> User
    func signInWithApple(credential: AuthCredential) async throws -> User
    func sendEmailVerification(to user: User) async throws
    func sendPasswordReset(to email: String) async throws
    func sendPhoneVerificationCode(to phoneNumber: String) async throws -> String
    func verifySMSCode(_ code: String, verificationID: String) async throws -> User
    func reloadUser(_ user: User) async throws -> User
    func isEmailVerified(_ user: User) -> Bool
    func signOut() throws
    var currentUser: User? { get }
}

// MARK: - FirebaseAuthProvider

/// Concrete implementation of `AuthProviding` backed by Firebase Auth.
public final class FirebaseAuthProvider: AuthProviding, @unchecked Sendable {

    public static let shared = FirebaseAuthProvider()

    public init() {}

    public var currentUser: User? {
        Auth.auth().currentUser
    }

    /// Signs in with email and password.
    public func signInWithEmail(email: String, password: String) async throws -> User {
        try await Auth.auth().signIn(withEmail: email, password: password).user
    }

    /// Creates a new account with email and password.
    public func signUpWithEmail(email: String, password: String) async throws -> User {
        try await Auth.auth().createUser(withEmail: email, password: password).user
    }

    /// Signs in with a Google ID token.
    public func signInWithGoogle(idToken: String, accessToken: String?) async throws -> User {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken ?? "")
        return try await Auth.auth().signIn(with: credential).user
    }

    /// Signs in with an Apple auth credential.
    public func signInWithApple(credential: AuthCredential) async throws -> User {
        return try await Auth.auth().signIn(with: credential).user
    }

    /// Sends an SMS verification code to the given phone number.
    /// - Parameter phoneNumber: The phone number in E.164 format (e.g. "+15551234567").
    /// - Returns: The verification ID to use with `verifySMSCode`.
    /// - Note: Phone auth is only available on iOS.
#if os(iOS)
    public func sendPhoneVerificationCode(to phoneNumber: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let verificationID {
                    continuation.resume(returning: verificationID)
                } else {
                    continuation.resume(throwing: AuthError.unknown("Failed to send verification code. No verification ID returned."))
                }
            }
        }
    }

    /// Verifies the SMS code and signs in the user.
    /// - Parameters:
    ///   - code: The 6-digit SMS verification code entered by the user.
    ///   - verificationID: The verification ID from `sendPhoneVerificationCode`.
    /// - Returns: The authenticated Firebase `User`.
    public func verifySMSCode(_ code: String, verificationID: String) async throws -> User {
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        return try await Auth.auth().signIn(with: credential).user
    }
#else
    public func sendPhoneVerificationCode(to phoneNumber: String) async throws -> String {
        fatalError("Phone authentication is not available on macOS.")
    }

    public func verifySMSCode(_ code: String, verificationID: String) async throws -> User {
        fatalError("Phone authentication is not available on macOS.")
    }
#endif

    /// Sends an email verification link to the given user.
    /// - Parameter user: The Firebase `User` who just signed up.
    public func sendEmailVerification(to user: User) async throws {
        try await user.sendEmailVerification()
    }

    /// Sends a password reset email to the given email address.
    /// - Parameter email: The email address of the account to reset.
    public func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Reloads the user's auth data from Firebase (e.g. to pick up email verification).
    /// - Parameter user: The Firebase `User` to reload.
    /// - Returns: The updated `User` object.
    public func reloadUser(_ user: User) async throws -> User {
        try await user.reload()
        return Auth.auth().currentUser ?? user
    }

    /// Checks whether the user's email has been verified.
    /// - Parameter user: The Firebase `User` to check.
    public func isEmailVerified(_ user: User) -> Bool {
        user.isEmailVerified
    }

    /// Signs out the current user.
    public func signOut() throws {
        try Auth.auth().signOut()
    }
}

// MARK: - Authentication ViewModel

/// Manages the full authentication lifecycle: email/password, Google, and Apple sign-in.
/// Exposes `@Published` state for the View to reactively update UI.
@MainActor
public final class AuthenticationViewModel: ObservableObject {

    // MARK: - Published State

    /// Current flow state (idle, loading, success, error).
    @Published private(set) var flowState: AuthenticationFlowState = .idle

    /// Whether the user is currently authenticated.
    @Published private(set) var isAuthenticated = false

    /// Human-readable error message for display.
    @Published private(set) var errorMessage: String?

    /// The raw Firebase error code from the last auth failure (e.g. 17999, 17007).
    /// Nil when no error has occurred. Useful for debugging.
    @Published private(set) var lastAuthErrorCode: Int?

    /// Which stage of sign-up failed — "auth" or nil if no failure.
    @Published private(set) var failureStage: String?

    /// Nonce for Apple Sign-In (needed to verify the credential).
    @Published var currentNonce: String?

    /// Tracks the profile update flow state.
    @Published private(set) var profileSaveState: ProfileSaveState = .idle

    /// Whether a profile save is in progress. Always updated on @MainActor.
    /// Used to disable the Save button and prevent duplicate saves.
    @Published private(set) var isLoading: Bool = false

    /// Whether the current user's email has been verified.
    /// Updated after sign-up (automatically sends verification) and after manual reload.
    @Published private(set) var isEmailVerified: Bool = false

    /// Whether an email verification link was recently sent.
    @Published private(set) var verificationEmailSent: Bool = false

    // MARK: - Password Reset State

    /// Whether a password reset email was successfully sent.
    @Published private(set) var passwordResetEmailSent: Bool = false

    // MARK: - Phone Auth State

    /// Whether an SMS verification code has been sent and the user should enter it.
    @Published private(set) var smsCodeSent: Bool = false

    /// The Firebase verification ID for the current phone auth session.
    /// Used internally to verify the SMS code.
    @Published private(set) var phoneVerificationID: String?

    /// Formatted phone number last used to request a code (for display in the code entry screen).
    @Published private(set) var maskedPhoneNumber: String?

    /// Countdown timer for resending the SMS code (prevents spam).
    @Published private(set) var resendCooldown: Int = 0

    // MARK: - Dependencies

    private let authService: AuthProviding

    // MARK: - Init

    /// Creates the ViewModel with an injectable auth provider.
    /// - Parameter authService: The auth service to use.
    public init(authService: AuthProviding) {
        self.authService = authService
    }

    /// Convenience init using the shared Firebase provider.
    public convenience init() {
        self.init(authService: FirebaseAuthProvider.shared)
    }

    // MARK: - Email / Password Sign-In

    /// Signs in with email and password. Updates `flowState` reactively.
    public func signIn(email: String, password: String) async {
        flowState = .loading
        errorMessage = nil

        do {
            let user = try await authService.signInWithEmail(email: email, password: password)
            handleAuthSuccess(user)
        } catch let error as NSError {
            handleFirebaseError(error)
        } catch {
            flowState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email / Password Sign-Up

    /// Creates a new account with email and password, then immediately sends
    /// a verification email. The flow state transitions: loading → success.
    /// If verification email delivery fails, the account is still created but
    /// `verificationEmailSent` remains `false` — the user can retry later.
    public func signUp(email: String, password: String) async {
        flowState = .loading
        errorMessage = nil
        lastAuthErrorCode = nil
        failureStage = "auth"
        verificationEmailSent = false

        do {
            // Step 1: Create the Firebase Auth user
            let user = try await authService.signUpWithEmail(email: email, password: password)
            failureStage = nil

            // Step 2: Send email verification asynchronously
            // Non-blocking — sign-up succeeds even if email fails to send
            do {
                try await authService.sendEmailVerification(to: user)
                verificationEmailSent = true
            } catch {
                // Log but don't fail the sign-up — user can resend later
                print("⚠️ Email verification send failed: \(error.localizedDescription)")
            }

            // Step 3: Update local email verification status
            isEmailVerified = authService.isEmailVerified(user)
            handleAuthSuccess(user)
        } catch let error as NSError {
            handleFirebaseError(error)
        } catch {
            flowState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email Verification

    /// Resends the email verification link to the currently signed-in user.
    /// Safe to call if the user taps a "Resend" button in the verification banner.
    public func resendVerificationEmail() async {
        guard let user = authService.currentUser else {
            setError("No signed-in user to send verification email to.")
            return
        }

        do {
            try await authService.sendEmailVerification(to: user)
            verificationEmailSent = true
        } catch {
            setError("Failed to resend verification email: \(error.localizedDescription)")
        }
    }

    /// Reloads the user's auth state from Firebase and updates `isEmailVerified`.
    /// Call this when the user returns from the email link (e.g. via deep link handler
    /// or a manual "I verified my email" button).
    public func checkEmailVerification() async {
        guard let user = authService.currentUser else { return }

        do {
            _ = try await authService.reloadUser(user)
            isEmailVerified = authService.isEmailVerified(Auth.auth().currentUser ?? user)
        } catch {
            print("⚠️ Failed to reload user for email verification: \(error.localizedDescription)")
        }
    }

    // MARK: - Password Reset

    /// Sends a password reset email to the given address.
    /// Firebase handles the email with a link — no password is exposed or changed directly.
    public func sendPasswordReset(to email: String) async {
        flowState = .loading
        errorMessage = nil
        passwordResetEmailSent = false

        do {
            print("✉️ Sending password reset to: \(email)")
            try await authService.sendPasswordReset(to: email)
            print("✅ Password reset email sent to: \(email)")
            passwordResetEmailSent = true
            flowState = .idle

            // Auto-dismiss success state after 4 seconds
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(4))
                self?.passwordResetEmailSent = false
            }
        } catch let error as NSError {
            print("❌ Password reset failed for: \(email) — code: \(error.code), info: \(error.userInfo)")
            lastAuthErrorCode = error.code
            let message: String
            if let code = AuthErrorCode(rawValue: error.code) {
                switch code {
                case .userNotFound:
                    message = "No account found with this email address."
                case .invalidEmail:
                    message = "Please enter a valid email address."
                case .tooManyRequests:
                    message = "Too many requests. Please wait a moment and try again."
                default:
                    message = error.localizedDescription
                }
            } else {
                message = error.localizedDescription
            }
            flowState = .error(message)
            errorMessage = message
        } catch {
            flowState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Resets the password reset flow state.
    public func resetPasswordResetState() {
        passwordResetEmailSent = false
        flowState = .idle
        errorMessage = nil
    }

    // MARK: - Google Sign-In

    /// Completes Google Sign-In with the ID token and optional access token from the Google SDK.
    public func signInWithGoogle(idToken: String, accessToken: String?) async {
        flowState = .loading
        errorMessage = nil

        do {
            let user = try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            handleAuthSuccess(user)
        } catch {
            let authErr = AuthError.googleSignInFailed(error.localizedDescription)
            flowState = .error(authErr.errorDescription ?? error.localizedDescription)
            errorMessage = authErr.localizedDescription
        }
    }

    // MARK: - Apple Sign-In

    /// Starts the Apple Sign-In flow by generating a nonce.
    /// Call this before presenting `ASAuthorizationAppleIDButton`.
    public func startAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
    }

    /// Completes Apple Sign-In with the authorization credential.
    public func completeAppleSignIn(credential: AuthCredential) async {
        flowState = .loading
        errorMessage = nil

        do {
            let user = try await authService.signInWithApple(credential: credential)
            handleAuthSuccess(user)
        } catch {
            let authErr = AuthError.appleSignInFailed(error.localizedDescription)
            flowState = .error(authErr.errorDescription ?? error.localizedDescription)
            errorMessage = authErr.localizedDescription
        }
    }

    // MARK: - Phone Sign-In

    /// Sends an SMS verification code to the given phone number.
    /// The phone number should be in E.164 format (e.g. "+15551234567").
    /// On success, `smsCodeSent` becomes `true` and `phoneVerificationID` is stored.
    public func sendPhoneVerificationCode(to phoneNumber: String) async {
        flowState = .loading
        errorMessage = nil
        smsCodeSent = false
        phoneVerificationID = nil

        let normalized = formatToE164(phoneNumber)
        maskedPhoneNumber = maskPhoneNumber(normalized)

        do {
            let verificationID = try await authService.sendPhoneVerificationCode(to: normalized)
            phoneVerificationID = verificationID
            smsCodeSent = true
            flowState = .idle
            startResendCooldown()
        } catch let error as NSError {
            handlePhoneAuthError(error)
        } catch {
            flowState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Verifies the SMS code entered by the user and completes sign-in.
    /// - Parameter code: The 6-digit verification code from the SMS.
    public func verifyPhoneCode(_ code: String) async {
        guard let verificationID = phoneVerificationID else {
            setError("Verification session expired. Please request a new code.")
            resetPhoneAuthState()
            return
        }

        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            flowState = .error(AuthError.invalidVerificationCode.localizedDescription)
            errorMessage = AuthError.invalidVerificationCode.localizedDescription
            return
        }

        flowState = .loading
        errorMessage = nil

        do {
            let user = try await authService.verifySMSCode(code, verificationID: verificationID)
            handleAuthSuccess(user)
        } catch let error as NSError {
            handlePhoneAuthError(error)
        } catch {
            flowState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Resets the phone auth flow (e.g. to go back and enter a different number).
    public func resetPhoneAuthState() {
        smsCodeSent = false
        phoneVerificationID = nil
        maskedPhoneNumber = nil
        resendCooldown = 0
        errorMessage = nil
        flowState = .idle
    }

    // MARK: - Sign Out

    /// Signs out the current user and resets state.
    public func signOut() {
        try? authService.signOut()
        isAuthenticated = false
        errorMessage = nil
        flowState = .idle
        smsCodeSent = false
        phoneVerificationID = nil
        maskedPhoneNumber = nil
        resendCooldown = 0
        AppState.shared.logout()
    }

    // MARK: - Helpers

    private func handleAuthSuccess(_ user: User) {
        let username = user.email?.components(separatedBy: "@").first ?? user.displayName ?? "User"
        AppState.shared.login(username: username, password: "")
        isAuthenticated = true
        flowState = .success
        errorMessage = nil
    }

    private func handleFirebaseError(_ error: NSError) {
        // Log full error details to console for debugging
        print("""
        ═══════════════════════════════════════════
        🔥 FIREBASE AUTH ERROR
        ═══════════════════════════════════════════
        Domain:   \(error.domain)
        Code:     \(error.code)
        UserInfo: \(error.userInfo)
        Description: \(error.localizedDescription)

        Common Firebase Auth error codes:
        • 17007  → email-already-in-use
        • 17008  → invalid-email
        • 17009  → wrong-password
        • 17011  → user-not-found
        • 17026  → weak-password
        • 17020  → network-request-failed
        • 17025  → invalid-credential (wrong email/password combo)
        • 17999  → internal-error (check Firebase project config / API keys)
        ═══════════════════════════════════════════
        """)

        // Store the raw code for debugging
        lastAuthErrorCode = error.code

        guard let code = AuthErrorCode(rawValue: error.code) else {
            // Unknown code — still provide the numeric code in the message
            let message = "Error (\(error.code)): \(error.localizedDescription)"
            flowState = .error(message)
            errorMessage = message
            return
        }

        let mapped: AuthError = switch code {
        case .invalidEmail:
            .invalidEmail
        case .weakPassword:
            .weakPassword(minLength: 6)
        case .userNotFound:
            .userNotFound
        case .wrongPassword:
            .wrongPassword
        case .emailAlreadyInUse:
            .emailAlreadyInUse
        case .networkError:
            .networkError(error.localizedDescription)
        case .invalidCredential:
            .credentialError("The email or password is incorrect.")
        default:
            .unknown("Error (\(error.code)): \(error.localizedDescription)")
        }

        flowState = .error(mapped.errorDescription ?? error.localizedDescription)
        errorMessage = mapped.localizedDescription
    }

    /// Resets flow state to idle (e.g. for retry).
    public func resetState() {
        flowState = .idle
        errorMessage = nil
        lastAuthErrorCode = nil
        failureStage = nil
    }

    /// Sets an error state from the View layer without exposing the setter.
    /// Keeps `flowState` private(set) while allowing the View to report errors.
    public func setError(_ message: String) {
        flowState = .error(message)
        errorMessage = message
    }

    /// Reports a placeholder error when a required SDK is not available.
    public func setProviderUnavailableError(_ provider: String) {
        let message = "\(provider) requires the \(provider) SDK. See documentation for setup instructions."
        flowState = .error(message)
        errorMessage = message
    }

    // MARK: - Phone Auth Helpers

    /// Handles errors from Firebase Phone Auth, mapping Firebase error codes to user-friendly messages.
    private func handlePhoneAuthError(_ error: NSError) {
        lastAuthErrorCode = error.code

        guard let code = AuthErrorCode(rawValue: error.code) else {
            let message = "Error (\(error.code)): \(error.localizedDescription)"
            flowState = .error(message)
            errorMessage = message
            return
        }

        let mapped: AuthError = switch code {
        case .invalidPhoneNumber:
            .invalidPhoneNumber
        case .invalidVerificationCode:
            .invalidVerificationCode
        case .sessionExpired:
            .sessionExpired
        case .tooManyRequests:
            .tooManyRequests
        default:
            .unknown("Error (\(error.code)): \(error.localizedDescription)")
        }

        flowState = .error(mapped.errorDescription ?? error.localizedDescription)
        errorMessage = mapped.localizedDescription
    }

    /// Formats a phone number string to E.164 format.
    /// Strips all non-digit characters and prepends a default country code if needed.
    private func formatToE164(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)

        // Already has country code (10+ digits starting with non-zero)
        if digits.count >= 10 {
            if raw.first == "+" {
                return "+\(digits)"
            } else {
                // Assume US number if no + prefix
                return "+1\(digits)"
            }
        }

        // Short number — assume US with missing country code
        return "+1\(digits)"
    }

    /// Masks a phone number for display (e.g. "+1 (•••) •••-4567").
    private func maskPhoneNumber(_ e164: String) -> String {
        let digits = e164.filter(\.isNumber)
        guard digits.count > 4 else { return e164 }
        let last4 = String(digits.suffix(4))
        let maskCount = digits.count - 4
        let mask = String(repeating: "•", count: maskCount)
        return "+\(mask)\(last4)"
    }

    /// Starts a 60-second cooldown timer to prevent SMS spam.
    private func startResendCooldown() {
        resendCooldown = 60
        Task { @MainActor [weak self] in
            while true {
                guard let self, self.resendCooldown > 0 else { return }
                try? await Task.sleep(for: .seconds(1))
                self.resendCooldown -= 1
            }
        }
    }
}

// MARK: - Profile Save State

/// Tracks the outcome of a profile write to Firestore.
public enum ProfileSaveState: Equatable {
    case idle
    case saving
    case success
    case error(String)
}

// MARK: - Profile Update

extension AuthenticationViewModel {

    /// Saves the user's profile fields (domain, phone) to Firestore at `/users/{userId}`.
    /// Uses `merge: true` so only the provided fields are updated — existing data is preserved.
    ///
    /// Fail-safe guarantees:
    /// - **State reset**: `isLoading` is always set to `false` in the `finally` block, so the UI
    ///   can never get permanently stuck in a loading state.
    /// - **Timeout**: If the Firestore write takes longer than 5 seconds, the task is
    ///   automatically cancelled and a timeout error is surfaced.
    /// - **UI feedback**: On failure, `errorMessage` is set so the View can show an alert.
    /// - **Duplicate prevention**: `isLoading` disables the Save button while a save is in flight.
    ///
    /// - Parameters:
    ///   - userId: The Firebase Auth UID.
    ///   - fields: Dictionary of fields to update (e.g. `"phone": "555-1234"`, `"domain": "iOS Developer"`).
    public func saveProfile(userId: String, fields: [String: Any]) async {
        guard !userId.isEmpty else {
            errorMessage = "User ID is missing. Please sign in again."
            profileSaveState = .error("User ID is missing. Please sign in again.")
            return
        }

        // Guard against duplicate saves — button should be disabled via .disabled(isLoading)
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        profileSaveState = .saving

        // Wrap the entire operation so isLoading is ALWAYS reset, even on cancellation.
        defer {
            isLoading = false
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // The actual Firestore write
                group.addTask {
                    try await FirestoreService.shared.updateProfileFields(userId: userId, fields: fields)
                }
                // 5-second timeout — cancels the write if it takes too long
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    throw URLError(.timedOut)
                }
                // Return whichever finishes first
                try await group.next()!
                group.cancelAll()
            }

            profileSaveState = .success

            // Auto-dismiss success after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                if case .success = profileSaveState {
                    profileSaveState = .idle
                }
            }
        } catch {
            let message: String
            if let urlError = error as? URLError, urlError.code == .timedOut {
                message = "Network timeout. The save took too long — please check your connection and try again."
            } else {
                message = "Failed to save profile: \(error.localizedDescription)"
            }
            errorMessage = message
            profileSaveState = .error(message)
        }
    }

    /// Resets the profile save state to idle.
    public func resetProfileSaveState() {
        profileSaveState = .idle
    }

    /// Clears the current error message.
    public func clearError() {
        errorMessage = nil
    }
}

// MARK: - Apple Nonce Helpers

extension AuthenticationViewModel {

    /// Generates a random nonce string for Apple Sign-In SHA256 hashing.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)

        guard result == errSecSuccess else {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(result)")
        }

        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    /// SHA256 hash of the nonce used for Apple Sign-In credential verification.
    public static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
