// ProfileConfirmView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Profile Confirm View

/// Displays pre-filled profile fields extracted from the user's resume via AI (Gemini).
/// The user can review and edit the information before confirming.
/// Once confirmed, the profile is saved to Firestore and onboarding completes.
public struct ProfileConfirmView: View {

    // MARK: - Dependencies

    @ObservedObject var coordinator: ResumeOnboardingCoordinator

    /// Called after the user confirms and the profile is saved.
    var onConfirm: () -> Void

    // MARK: - Editable State

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var skillsText: String = ""
    @State private var domain: String = ""
    @State private var experience: String = ""
    @State private var phone: String = ""

    @State private var isSaving = false

    // MARK: - Init

    public init(
        coordinator: ResumeOnboardingCoordinator,
        onConfirm: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.onConfirm = onConfirm
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    header

                    // Parsed Details
                    detailsSection

                    // Skills
                    skillsSection

                    // Error
                    if case .failed(let message) = coordinator.phase {
                        errorBanner(message: message)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .navigationTitle("Confirm Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        coordinator.backToResumeUpload()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    actionButtons
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.bar)
                }
            }
            .onAppear {
                prefilledFromParsed()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("Profile Auto-Fill Complete")
                    .font(.title2.bold())
                Text("We extracted the following from your resume. Review and confirm.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 16) {
            SectionLabel(title: "Personal Information", icon: "person.fill")

            EditableField(title: "Name", text: $name, icon: "person")
            EditableField(title: "Email", text: $email, icon: "envelope")
            EditableField(title: "Phone", text: $phone, icon: "phone")
            EditableField(title: "Domain", text: $domain, icon: "briefcase.fill")
            EditableField(title: "Experience", text: $experience, icon: "clock.fill")
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(spacing: 16) {
            SectionLabel(title: "Skills", icon: "star.fill")

            VStack(alignment: .leading, spacing: 8) {
                Text("Skills (comma-separated)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g. Swift, SwiftUI, Firebase", text: $skillsText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    #if os(iOS)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    #else
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.none)
                    #endif

                // Skills pills preview
                if !parsedSkills.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(parsedSkills, id: \.self) { skill in
                            Text(skill)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Re-upload") {
                coordinator.backToResumeUpload()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

            Button {
                handleConfirm()
            } label: {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text("Confirm")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isSaving ? Color.gray : Color.green,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .disabled(isSaving)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .padding(12)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func handleConfirm() {
        isSaving = true
        Task {
            await coordinator.confirmAndSave()
            isSaving = false
            if case .complete = coordinator.phase {
                onConfirm()
            }
        }
    }

    // MARK: - Helpers

    private var parsedSkills: [String] {
        skillsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func prefilledFromParsed() {
        guard case .confirmDetails(let parsed) = coordinator.phase else { return }
        name = parsed.name
        email = parsed.email
        phone = parsed.phone
        domain = parsed.domain
        experience = parsed.experience
        skillsText = parsed.skills.joined(separator: ", ")
    }
}

// MARK: - Section Label

private struct SectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Editable Field

private struct EditableField: View {
    let title: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Enter \(title.lowercased())", text: $text)
                    .font(.subheadline)
                    #if os(iOS)
                    .textInputAutocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        #if os(iOS)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        #else
        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        #endif
    }
}
