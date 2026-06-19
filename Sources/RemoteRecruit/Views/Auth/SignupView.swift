// SignupView.swift
// RemoteRecruit

import SwiftUI
import FirebaseAuth

// MARK: - Signup View

/// Create Account screen with full error extraction and descriptive user feedback.
/// Uses `AuthenticationViewModel` for auth + `FirestoreService` for profile persistence.
public struct SignupView: View {

    // MARK: - Dependencies

    @StateObject private var viewModel: AuthenticationViewModel

    // MARK: - State

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var college = ""
    @State private var phone = ""
    @State private var selectedDomain: JobDomain = .iosDeveloper
    @State private var firestoreError: String?

    // MARK: - Callbacks

    /// Called when sign-up succeeds and the profile has been saved.
    public var onSignupSuccess: () -> Void

    // MARK: - Init

    public init(
        viewModel: AuthenticationViewModel,
        onSignupSuccess: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSignupSuccess = onSignupSuccess
    }

    // MARK: - Computed

    /// Display error: auth error from the ViewModel takes priority, then Firestore error.
    /// Prefixes with the failure source so the user knows exactly where it failed.
    private var displayError: String? {
        if let authMsg = viewModel.errorMessage, viewModel.failureStage == "auth" {
            let code = viewModel.lastAuthErrorCode.map { " (code \($0))" } ?? ""
            return "Account creation failed\(code): \(authMsg)"
        }
        if let fsError = firestoreError {
            return "Profile save failed: \(fsError)"
        }
        return viewModel.errorMessage
    }

    private var isLoading: Bool {
        viewModel.flowState.isLoading
    }

    private var isFormValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return email.range(of: emailRegex, options: .regularExpression) != nil
            && password.count >= 6
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Account
                Section("Account") {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
#endif
                    SecureField("Password", text: $password)
                }

                // MARK: Profile Details
                Section("Profile Details") {
                    TextField("College / University", text: $college)
                    TextField("Phone Number", text: $phone)
#if os(iOS)
                        .keyboardType(.phonePad)
#endif
                }

                // MARK: Preferred Domain
                Section("Preferred Domain") {
                    Picker("Domain", selection: $selectedDomain) {
                        ForEach(JobDomain.allCases) { domain in
                            Text(domain.rawValue).tag(domain)
                        }
                    }
                }

                // MARK: Error Display
                if let message = displayError {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(message)
                                .foregroundStyle(.red)
                                .font(.footnote)
                            Spacer()
                            Button {
                                viewModel.resetState()
                                firestoreError = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }

                // MARK: Email Verification Banner
                /// Shown after sign-up succeeds and a verification email is sent.
                /// Provides a "Check Verification" button and a "Resend" link.
                if viewModel.verificationEmailSent && !viewModel.isEmailVerified {
                    Section {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Verify your email")
                                        .font(.subheadline.weight(.semibold))
                                    Text("We sent a verification link to \(email). Check your inbox and tap the link.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack(spacing: 16) {
                                Button {
                                    Task { await viewModel.checkEmailVerification() }
                                } label: {
                                    Text("I verified my email")
                                        .font(.caption.weight(.medium))
                                }

                                Spacer()

                                Button("Resend") {
                                    Task { await viewModel.resendVerificationEmail() }
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: Verified Success
                if viewModel.isEmailVerified {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Email verified successfully.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: handleSignup) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign Up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Creating account…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Actions

    private func handleSignup() {
        firestoreError = nil

        Task {
            // Step 1: Create the Firebase Auth account via the ViewModel
            // The ViewModel maps Firebase error codes to descriptive messages.
            await viewModel.signUp(email: email, password: password)

            // Check if auth failed
            if viewModel.errorMessage != nil {
                return
            }

            // Step 2: Save the initial profile to Firestore
            guard let uid = Auth.auth().currentUser?.uid else {
                viewModel.setError("Unexpected error: no user ID after sign-up.")
                return
            }

            let profile = UserProfile(
                name: name,
                userId: uid,
                email: email,
                college: college,
                phone: phone,
                domain: selectedDomain.rawValue,
                experienceLevel: AppState.shared.selectedExperienceLevel.rawValue
            )

            do {
                try await FirestoreService.shared.saveUserProfile(profile: profile)
                AppState.shared.login(username: name, password: "")
                onSignupSuccess()
            } catch {
                // Extract and log the full Firestore error details
                logFirestoreError(error)
                firestoreError = descriptiveFirestoreError(error)
            }
        }
    }

    // MARK: - Firebase Error Logging

    /// Prints the full Firebase error code, domain, and userInfo to the console
    /// so you can identify the exact failure in Xcode.
    private func logFirestoreError(_ error: Error) {
        let nsError = error as NSError
        print("""
        ═══════════════════════════════════════════
        🔥 FIRESTORE ERROR
        ═══════════════════════════════════════════
        Domain:   \(nsError.domain)
        Code:     \(nsError.code)
        UserInfo: \(nsError.userInfo)
        Description: \(nsError.localizedDescription)

        Common causes:
        • Code 7  → Firestore security rules deny the write.
                   Check rules allow: if request.auth != null
        • Code 14 → Network / service unavailable.
                   Check your internet connection and Firebase project status.
        • Code 1  → Permission denied (auth not yet propagated).
                   Ensure Firestore rules reference request.auth.uid
        ═══════════════════════════════════════════
        """)
    }

    /// Converts a Firestore error into a user-friendly message.
    private func descriptiveFirestoreError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 7:
            return "Permission denied. Your account was created but profile save failed. " +
                   "Check your Firestore security rules allow authenticated writes to the 'users' collection."
        case 14:
            return "Network error. Please check your connection and try again."
        case 1:
            return "Permission denied. Please try again in a moment."
        default:
            return nsError.localizedDescription
        }
    }
}

