// LoginView.swift
// RemoteRecruit

import SwiftUI
import AuthenticationServices
import FirebaseAuth
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Auth Method

/// The two primary sign-in methods on the login screen.
private enum AuthMethod {
    case email
    case phone
}

// MARK: - Login View

/// Professional sign-in screen supporting Email/Password, Phone Number, Google Sign-In, and Apple Sign-In.
/// All auth logic is delegated to `AuthenticationViewModel` — this View only handles presentation.
public struct LoginView: View {

    // MARK: - Dependencies

    @StateObject private var viewModel: AuthenticationViewModel

    // MARK: - Local State

    @State private var email = ""
    @State private var password = ""
    @State private var selectedAuthMethod: AuthMethod = .email
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""

    // MARK: - Callbacks

    /// Called when sign-in succeeds (used by RootView to transition to main content).
    public var onLoginSuccess: () -> Void

    /// Navigate to the sign-up screen.
    public var onNavigateToSignup: () -> Void

    // MARK: - Init

    public init(
        viewModel: AuthenticationViewModel,
        onLoginSuccess: @escaping () -> Void,
        onNavigateToSignup: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onLoginSuccess = onLoginSuccess
        self.onNavigateToSignup = onNavigateToSignup
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // MARK: Header
                    header

                    // MARK: Auth Method Toggle
                    authMethodPicker

                    // MARK: Auth Form (email or phone)
                    if selectedAuthMethod == .email {
                        if !viewModel.smsCodeSent {
                            emailPasswordForm
                        }
                    } else {
                        if viewModel.smsCodeSent {
                            smsCodeEntryForm
                        } else {
                            phoneInputForm
                        }
                    }

                    // MARK: Error Display
                    if let errorMessage = viewModel.errorMessage, viewModel.flowState.isLoading == false {
                        errorBanner(message: errorMessage)
                    }

                    // MARK: Divider
                    if !viewModel.smsCodeSent {
                        divider

                        // MARK: Social Sign-In
                        socialSignInSection
                    }

                    // MARK: Footer
                    if !viewModel.smsCodeSent {
                        footerButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Sign In")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .overlay {
                if viewModel.flowState.isLoading {
                    loadingOverlay
                }
            }
            .onChange(of: viewModel.flowState) { _, newState in
                if case .success = newState {
                    onLoginSuccess()
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                forgotPasswordSheet
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            Text("RemoteRecruit")
                .font(.largeTitle.bold())
            Text("Sign in to your account")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Email / Password Form

    private var emailPasswordForm: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
#endif
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
#if os(iOS)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
#else
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
#endif

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
#if os(iOS)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
#else
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
#endif

            Button(action: { Task { await viewModel.signIn(email: email, password: password) } }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        isFormValid ? Color.blue : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }
            .disabled(!isFormValid || viewModel.flowState.isLoading)

            // Forgot Password link
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    forgotPasswordEmail = email
                    showForgotPassword = true
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
            }
        }
    }

    // MARK: - Forgot Password Sheet

    private var forgotPasswordSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.tint)

                    Text("Reset Password")
                        .font(.title2.bold())

                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                TextField("Email address", text: $forgotPasswordEmail)
                    .textContentType(.emailAddress)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
#endif
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
#if os(iOS)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
#else
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
#endif
#if os(iOS)
                    .autocapitalization(.none)
#endif

                if let errorMessage = viewModel.errorMessage, !viewModel.passwordResetEmailSent {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                if viewModel.passwordResetEmailSent {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email sent!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                            Text("Check your inbox at \(forgotPasswordEmail) and tap the reset link.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 24)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    if viewModel.passwordResetEmailSent {
                        Button {
                            showForgotPassword = false
                            viewModel.resetPasswordResetState()
                        } label: {
                            Text("Back to Sign In")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                        }
                    } else {
                        Button {
                            Task { await viewModel.sendPasswordReset(to: forgotPasswordEmail) }
                        } label: {
                            if viewModel.flowState.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Send Reset Link")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        isForgotEmailValid ? Color.blue : Color.gray.opacity(0.4),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                            }
                        }
                        .disabled(!isForgotEmailValid || viewModel.flowState.isLoading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .navigationTitle("Reset Password")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showForgotPassword = false
                        viewModel.resetPasswordResetState()
                    }
                }
            }
        }
    }

    // MARK: - Auth Method Picker

    private var authMethodPicker: some View {
        Picker("Sign in method", selection: $selectedAuthMethod) {
            Text("Email")
                .tag(AuthMethod.email)
            Text("Phone Number")
                .tag(AuthMethod.phone)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
        .onChange(of: selectedAuthMethod) { _, _ in
            viewModel.resetState()
            viewModel.resetPhoneAuthState()
        }
    }

    // MARK: - Phone Input Form

    private var phoneInputForm: some View {
        VStack(spacing: 16) {
            TextField("Phone number (e.g. +1 555-123-4567)", text: $phoneNumber)
                .textContentType(.telephoneNumber)
#if os(iOS)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
#if os(iOS)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
#else
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
#endif

            Button(action: {
                Task { await viewModel.sendPhoneVerificationCode(to: phoneNumber) }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                    Text("Send Verification Code")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isPhoneNumberValid ? Color.blue : Color.gray.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .disabled(!isPhoneNumberValid || viewModel.flowState.isLoading)

            Text("We'll send a 6-digit code to verify your number.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - SMS Code Entry Form

    private var smsCodeEntryForm: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tint)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Enter verification code")
                    .font(.headline)
                if let masked = viewModel.maskedPhoneNumber {
                    Text("Code sent to \(masked)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // 6-digit code input
            TextField("000000", text: $verificationCode)
                .textContentType(.oneTimeCode)
#if os(iOS)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
#if os(iOS)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
#else
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
#endif
                .onChange(of: verificationCode) { _, newValue in
                    // Auto-submit when 6 digits entered
                    if newValue.count == 6 && newValue.allSatisfy(\.isNumber) {
                        Task { await viewModel.verifyPhoneCode(newValue) }
                    }
                }

            Button(action: {
                Task { await viewModel.verifyPhoneCode(verificationCode) }
            }) {
                Text("Verify")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        verificationCode.count == 6 ? Color.blue : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }
            .disabled(verificationCode.count != 6 || viewModel.flowState.isLoading)

            // Resend / cooldown
            if viewModel.resendCooldown > 0 {
                Text("Resend code in \(viewModel.resendCooldown)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Resend Code") {
                    verificationCode = ""
                    Task { await viewModel.sendPhoneVerificationCode(to: phoneNumber) }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.tint)
            }

            Button("Use a different number") {
                verificationCode = ""
                viewModel.resetPhoneAuthState()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Divider

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)

            Text("or continue with")
                .font(.caption)
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
        }
    }

    // MARK: - Social Sign-In

    private var socialSignInSection: some View {
        VStack(spacing: 12) {
#if canImport(GoogleSignIn)
            // Google Sign-In Button
            Button(action: handleGoogleSignIn) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 24, height: 24)
                    Text("Continue with Google")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
#if os(iOS)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
#else
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
#endif
            }
            .disabled(viewModel.flowState.isLoading)
#else
            // Google Sign-In not available (SDK not linked)
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 24, height: 24)
                Text("Continue with Google (unavailable)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
#if os(iOS)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
#else
            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
#endif
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3))
            )
            .opacity(0.6)
#endif

            // Apple Sign-In Button
            SignInWithAppleButton { request in
                request.requestedScopes = [.fullName, .email]
                let nonce = viewModel.startAppleSignIn()
                request.nonce = AuthenticationViewModel.sha256(nonce)
            } onCompletion: { result in
                handleAppleSignIn(result: result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            .disabled(viewModel.flowState.isLoading)
        }
    }

    // MARK: - Footer

    private var footerButton: some View {
        Button(action: onNavigateToSignup) {
            Text("Don't have an account? ")
                .foregroundStyle(.secondary) +
            Text("Sign Up")
                .foregroundStyle(.tint)
        }
        .font(.subheadline)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Signing in…")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
            Spacer()
            Button {
                viewModel.resetState()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.gray)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return email.range(of: emailRegex, options: .regularExpression) != nil
            && password.count >= 6
    }

    private var isPhoneNumberValid: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.count >= 10
    }

    private var isForgotEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return forgotPasswordEmail.range(of: emailRegex, options: .regularExpression) != nil
    }

    // MARK: - Google Sign-In Handler

#if canImport(GoogleSignIn)
    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            viewModel.setError("Unable to present Google Sign-In.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            // Guard against cancelled or failed sign-in
            guard let result, error == nil else {
                let message = error?.localizedDescription ?? "Google Sign-In was cancelled."
                viewModel.setError("Google Sign-In failed: \(message)")
                return
            }

            // Extract tokens and delegate to the ViewModel's provider-agnostic method
            let idToken = result.user.idToken?.tokenString ?? ""
            let accessToken = result.user.accessToken?.tokenString

            guard !idToken.isEmpty else {
                viewModel.setError("Google Sign-In failed: no ID token received.")
                return
            }

            Task { @MainActor in
                await viewModel.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            }
        }
    }
#endif

    // MARK: - Apple Sign-In Handler

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let rawNonce = viewModel.currentNonce,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                viewModel.setError("Failed to retrieve Apple credential.")
                return
            }

            Task {
                let firebaseCredential = OAuthProvider.credential(
                    providerID: .apple,
                    idToken: tokenString,
                    rawNonce: rawNonce
                )
                await viewModel.completeAppleSignIn(credential: firebaseCredential)
            }

        case .failure(let error):
            viewModel.setError("Apple sign-in cancelled or failed: \(error.localizedDescription)")
        }
    }
}

