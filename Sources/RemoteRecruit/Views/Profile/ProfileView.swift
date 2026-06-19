// ProfileView.swift
// RemoteRecruit

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UniformTypeIdentifiers

// MARK: - Profile View

public struct ProfileView: View {

    @StateObject private var appState = AppState.shared
    @StateObject private var authService = AuthService.shared
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var authViewModel = AuthenticationViewModel()

    // MARK: - Edit Mode (basic info)

    @State private var isEditingBasicInfo = false
    @State private var editableName = ""
    @State private var editableCollege = ""
    @State private var editablePhone = ""
    @State private var editableDomain = ""
    @State private var editableExperienceLevel = ""
    @State private var editableSkills: [String] = []
    @State private var editablePortfolioLink = ""
    @State private var newSkillText = ""

    @State private var validationError: String?

    // MARK: - Init

    public init() {
        let apiKey: String = {
            guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
                  let config = NSDictionary(contentsOf: url) as? [String: Any],
                  let key = config["GeminiAPIKey"] as? String,
                  !key.isEmpty,
                  key != "YOUR_GEMINI_API_KEY_HERE"
            else { return "" }
            return key
        }()
        _viewModel = StateObject(wrappedValue: ProfileViewModel(geminiAPIKey: apiKey))
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = viewModel.profile {
                    // MARK: Header Card
                    ProfileHeaderView(
                        profile: profile,
                        profileDisplayName: profileDisplayName,
                        isEditingBasicInfo: isEditingBasicInfo,
                        onToggleEdit: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditingBasicInfo.toggle()
                                validationError = nil
                            }
                        }
                    )

                    // MARK: Edit Mode
                    if isEditingBasicInfo {
                        basicInfoEditSection(profile)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Domain & Role Section
                    ProfileEditView(viewModel: viewModel)

                    // MARK: Experience Timeline Section
                    ExperienceTimelineCard(
                        experiences: profile.workExperience,
                        destination: .experience
                    )

                    // MARK: Projects & Skills Section
                    VStack(alignment: .leading, spacing: 0) {
                        // Section header
                        Text("Quick Access")
                            .font(DesignTokens.Typography.subheadline.bold())
                            .foregroundStyle(.primary)
                            .sectionHeader(icon: "square.grid.2x2")

                        Divider()

                        ProfileDashboardCard(
                            icon: "folder.fill",
                            title: "Projects",
                            count: profile.projects.count,
                            subtitle: projectSubtitle(profile.projects.count),
                            gradientStart: .blue,
                            gradientEnd: .cyan,
                            destination: .projects
                        )

                        Divider()

                        ProfileDashboardCard(
                            icon: "star.fill",
                            title: "Skills",
                            count: profile.skills.count,
                            subtitle: skillsSubtitle(profile.skills.count),
                            gradientStart: .orange,
                            gradientEnd: .yellow,
                            destination: .skills
                        )
                    }
                    .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)

                    // MARK: Metrics Section
                    ProfileMetricsRow(
                        jobsAppliedCount: appState.jobsAppliedCount,
                        atsScore: appState.latestATSScore
                    )

                    // MARK: Resume Section
                    ProfileResumeCard(
                        pipelineStep: viewModel.pipelineStep,
                        parsingState: viewModel.parsingState,
                        showDocumentPicker: $viewModel.showDocumentPicker,
                        resumeURL: profile.resumeURL,
                        onUploadTap: { viewModel.showDocumentPicker = true },
                        onConfirm: { Task { await viewModel.confirmAutoFill() } },
                        onDiscard: { viewModel.dismissPreview() },
                        onReset: { viewModel.resetPipeline() }
                    )

                    // MARK: Sign Out
                    ProfileSignOutButton {
                        handleSignOut()
                    }
                    .padding(.top, 16)
                } else if viewModel.isFetchingProfile {
                    LoadingStateView(message: "Loading profile\u{2026}")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let message = viewModel.profileErrorMessage {
                    ErrorStateView(message: message) {
                        if let uid = authService.user?.uid {
                            Task { await viewModel.loadProfile(userId: uid) }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(.bottom, 32)
            .background(PlatformColors.secondarySystemBackground)
            .navigationTitle("Profile")
            .navigationDestination(for: DashboardSection.self) { section in
                switch section {
                case .projects:
                    ProjectsDetailView(viewModel: viewModel)
                case .experience:
                    ExperienceDetailView(viewModel: viewModel)
                case .skills:
                    SkillsDetailView(viewModel: viewModel)
                }
            }
            .task {
                if let uid = authService.user?.uid {
                    await viewModel.loadProfile(userId: uid)
                    prefillEditableFields()
                }
            }
            .onChange(of: viewModel.pipelineStep) {
                if case .done = viewModel.pipelineStep {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        viewModel.resetPipeline()
                    }
                }
            }
            .onChange(of: viewModel.parsingState) {
                if case .done = viewModel.parsingState {
                    prefillEditableFields()
                }
            }
            .fileImporter(
                isPresented: $viewModel.showDocumentPicker,
                allowedContentTypes: [.pdf],
                onCompletion: handleDocumentPicker
            )
            .alert("Save Failed", isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { if !$0 { authViewModel.clearError() } }
            )) {
                Button("OK") {
                    authViewModel.clearError()
                }
            } message: {
                Text(authViewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Subtitle Helpers

    private func projectSubtitle(_ count: Int) -> String {
        count == 0 ? "Add your first project" : "\(count) project\(count == 1 ? "" : "s") added"
    }

    private func skillsSubtitle(_ count: Int) -> String {
        count == 0 ? "Add your technical skills" : "\(count) skill\(count == 1 ? "" : "s")"
    }

    // MARK: - Basic Info Edit Section

    private func basicInfoEditSection(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.subheadline.weight(.semibold))
.foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text("Edit Information")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.bottom, 4)

            VStack(spacing: 14) {
                TextField("Full Name", text: $editableName)
                    .textContentType(.name)

                TextField("College / University", text: $editableCollege)
                    .textContentType(.organizationName)

                HStack {
                    Image(systemName: "phone")
                        .foregroundStyle(.secondary)
                    TextField("Phone Number", text: $editablePhone)
                        .textContentType(.telephoneNumber)
                #if os(iOS)
                        .keyboardType(.phonePad)
                #endif
                }

                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    TextField("Portfolio URL", text: $editablePortfolioLink)
                        .textContentType(.URL)
                #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                #endif
                        .disableAutocorrection(true)
                }

                // Skills
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Add a skill", text: $newSkillText)
                            .textContentType(.none)
                #if os(iOS)
                            .autocapitalization(.none)
                #endif
                            .disableAutocorrection(true)
                            .onSubmit { addSkill() }

                        Button(action: addSkill) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        .disabled(newSkillText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if !editableSkills.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(editableSkills, id: \.self) { skill in
                                HStack(spacing: 6) {
                                    Text(skill)
                                        .font(.caption.weight(.medium))
                                    Button {
                                        editableSkills.removeAll { $0 == skill }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        .background(PlatformColors.secondarySystemBackground, in: Capsule())
                            }
                        }
                    }
                }

                if let error = validationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                HStack(spacing: 12) {
                    Button {
                        handleSaveProfile()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Save")
                            if authViewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasEdits || authViewModel.isLoading)

                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingBasicInfo = false
                            if let p = viewModel.profile { discardEdits(profile: p) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Skill Helper

    private func addSkill() {
        let skill = newSkillText.trimmingCharacters(in: .whitespaces)
        guard !skill.isEmpty, !editableSkills.contains(skill) else { return }
        editableSkills.append(skill)
        newSkillText = ""
    }

    // MARK: - Actions

    private func handleSaveProfile() {
        guard let uid = authService.user?.uid, !uid.isEmpty else {
            authViewModel.setError("You must be signed in to update your profile.")
            return
        }

        if let error = validateFields() {
            validationError = error
            return
        }
        validationError = nil

        var fields: [String: Any] = [:]
        if !editableName.trimmingCharacters(in: .whitespaces).isEmpty { fields["name"] = editableName }
        if !editableCollege.trimmingCharacters(in: .whitespaces).isEmpty { fields["college"] = editableCollege }
        if !editablePhone.trimmingCharacters(in: .whitespaces).isEmpty { fields["phone"] = editablePhone }
        if !editableDomain.isEmpty { fields["domain"] = editableDomain }
        if !editableExperienceLevel.isEmpty { fields["experienceLevel"] = editableExperienceLevel }
        if !editablePortfolioLink.trimmingCharacters(in: .whitespaces).isEmpty { fields["portfolioLink"] = editablePortfolioLink }
        fields["skills"] = editableSkills

        guard !fields.isEmpty else { return }

        Task {
            await authViewModel.saveProfile(userId: uid, fields: fields)

            if case .success = authViewModel.profileSaveState {
                await viewModel.loadProfile(userId: uid)
                prefillEditableFields()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEditingBasicInfo = false
                }
            }
        }
    }

    private func handleSignOut() {
        authViewModel.signOut()
        authViewModel.resetProfileSaveState()
        isEditingBasicInfo = false
    }

    // MARK: - Validation

    private func validateFields() -> String? {
        guard !editableName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Name is required."
        }
        let phone = editablePhone.trimmingCharacters(in: .whitespaces)
        if !phone.isEmpty {
            let digits = phone.filter { $0.isNumber }
            guard digits.count >= 7 else {
                return "Phone number must have at least 7 digits."
            }
        }
        let link = editablePortfolioLink.trimmingCharacters(in: .whitespaces)
        if !link.isEmpty {
            guard link.contains(".") else {
                return "Portfolio link must be a valid URL."
            }
            if !link.hasPrefix("http://") && !link.hasPrefix("https://") {
                return "Portfolio link must start with https://"
            }
        }
        return nil
    }

    // MARK: - Edit Helpers

    private func prefillEditableFields() {
        guard let profile = viewModel.profile else { return }
        editableName = profile.name
        editableCollege = profile.college
        editablePhone = profile.phone
        editableDomain = profile.domain
        editableExperienceLevel = profile.experienceLevel
        editableSkills = profile.skills
        editablePortfolioLink = profile.portfolioLink
    }

    private func discardEdits(profile: UserProfile) {
        editableName = profile.name
        editableCollege = profile.college
        editablePhone = profile.phone
        editableDomain = profile.domain
        editableExperienceLevel = profile.experienceLevel
        editableSkills = profile.skills
        editablePortfolioLink = profile.portfolioLink
        newSkillText = ""
        authViewModel.resetProfileSaveState()
    }

    private var hasEdits: Bool {
        guard let profile = viewModel.profile else { return false }
        return editableName != profile.name
            || editableCollege != profile.college
            || editablePhone != profile.phone
            || editableDomain != profile.domain
            || editableExperienceLevel != profile.experienceLevel
            || editableSkills != profile.skills
            || editablePortfolioLink != profile.portfolioLink
    }

    // MARK: - Computed

    private var profileDisplayName: String {
        viewModel.profile?.name ?? (appState.username.isEmpty ? "Guest" : appState.username)
    }

    // MARK: - Document Picker Handler

    private func handleDocumentPicker(_ result: Result<URL, Error>) {
        viewModel.showDocumentPicker = false

        guard case .success(let pickerURL) = result else {
            viewModel.setPipelineStep(.failed("Could not access the selected file."))
            return
        }

        // Access the security-scoped resource
        let didGainAccess = pickerURL.startAccessingSecurityScopedResource()
        defer { pickerURL.stopAccessingSecurityScopedResource() }

        guard didGainAccess else {
            viewModel.setPipelineStep(
                .failed("Permission denied: the app cannot read the selected file.")
            )
            return
        }

        guard let uid = authService.user?.uid, !uid.isEmpty else {
            viewModel.setPipelineStep(.failed("You must be signed in to upload a resume."))
            return
        }

        // Securely copy the file into the app's Documents/Resumes/ directory
        let persistentURL: URL
        do {
            persistentURL = try StorageService.secureCopyResumeFromPicker(pickerURL)
        } catch {
            viewModel.setPipelineStep(.failed("Could not copy resume: \(error.localizedDescription)"))
            return
        }

        // Read data from the persistent copy (not the temporary picker URL)
        let data: Data
        do {
            data = try StorageService.readData(from: persistentURL)
        } catch {
            viewModel.setPipelineStep(.failed("Could not read copied resume: \(error.localizedDescription)"))
            return
        }

        print("[ProfileView] Resume securely copied to: \(persistentURL.path)")

        Task {
            await viewModel.processResume(data: data, userId: uid)
        }
    }
}

// MARK: - Dashboard Section

public enum DashboardSection: String, Hashable, Identifiable, CaseIterable {
    case projects
    case experience
    case skills

    public var id: String { rawValue }
}

// MARK: - Flow Layout

/// A simple flow/wrapping layout that arranges views left-to-right, top-to-bottom.
struct FlowLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct ArrangementResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var size: CGSize = .zero
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        var result = ArrangementResult()
        let maxWidth = proposal.width ?? .infinity

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            result.sizes.append(size)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            result.positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        result.size = CGSize(width: min(x - spacing, maxWidth), height: y + rowHeight)
        return result
    }
}
