// ProfileEditView.swift
// RemoteRecruit

import SwiftUI
import FirebaseAuth

// MARK: - Profile Edit View

/// Cohesive profile form organized into three logical sections:
///   1. **Status** – Student / Fresher / Experienced (segmented control)
///   2. **Academic Details** – Domain (single source of truth for branch),
///      Year of Study (Student only), Graduation Year (Fresher only),
///      Years of Experience + Designation (Experienced only), Batch Year
///   3. **Job Preferences** – Preferred Roles (multi-select tags)
struct ProfileEditView: View {

    // MARK: - Dependencies

    @ObservedObject var viewModel: ProfileViewModel
    @StateObject private var authService = AuthService.shared

    // MARK: - Status

    /// The user's current professional status selection.
    @State private var userStatus: ExperienceLevel = .student

    // MARK: - Academic Details

    /// Academic discipline — the single source of truth for both the
    /// experience-level domain and the academic branch displayed below.
    @State private var selectedDiscipline: AcademicDiscipline = .computerScience

    /// Year of study (1–4), shown only when `userStatus == .student`.
    @State private var yearOfStudy: Int = 1

    /// Graduation year, shown when `userStatus == .fresher`.
    @State private var graduationYear: Int = Calendar.current.component(.year, from: Date())

    /// Years of professional experience (0–15), shown only when `userStatus == .experienced`.
    @State private var yearsOfExperience: Double = 1

    /// Current designation, shown only when `userStatus == .experienced`.
    @State private var currentDesignation: String = ""

    /// Batch / graduation year for academic profile.
    @State private var batchYearText: String = ""

    // MARK: - Job Preferences

    /// Selected preferred roles for multi-selection.
    @State private var selectedRoles: Set<TechnicalRole> = []

    // MARK: - UI State

    /// No blocking `isSaving` — optimistic UI means the button is never disabled.

    // MARK: - Computed

    /// The `AcademicDomain` derived from `selectedDiscipline` — no separate picker needed.
    private var resolvedAcademicBranch: AcademicDomain {
        switch selectedDiscipline {
        case .computerScience: return .cse
        case .electronicsAndCommunication: return .ece
        case .electricalAndElectronics: return .eee
        case .mechanical: return .mechanical
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // MARK: Section 1 – Status
            statusSection

            // MARK: Section 2 – Academic Details
            academicDetailsSection
                .animation(.easeInOut(duration: 0.25), value: userStatus)

            // MARK: Section 3 – Job Preferences
            jobPreferencesSection
        }
        .onAppear { syncFromProfile() }
        .onChange(of: viewModel.profile) { _, _ in syncFromProfile() }
    }

    // MARK: - Section 1: Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text("Status")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()

                saveStatusIndicator(status: viewModel.academicSaveStatus)
            }
            .padding(.bottom, 12)

            Divider()

            SmartStatusToggle(selection: Binding(
                get: { userStatus },
                set: { userStatus = $0 }
            ))
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Section 2: Academic Details

    private var academicDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text("Academic Details")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.bottom, 12)

            Divider()

            // Domain picker (single source of truth)
            domainPickerRow
                .padding(.vertical, 12)

            Divider()

            // Conditional fields based on status
            conditionalFields

            Divider()

            // Batch Year (always visible)
            batchYearRow
                .padding(.vertical, 12)

            Divider()

            // Save button
            saveButton
                .padding(.top, 12)
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Domain Picker

    private var domainPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Label("Domain / Branch", systemImage: "rectangle.3.group.bubble.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(resolvedAcademicBranch.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            Picker("Domain", selection: $selectedDiscipline) {
                ForEach(AcademicDiscipline.allCases) { discipline in
                    HStack {
                        Image(systemName: discipline.iconName)
                        Text(discipline.rawValue)
                    }
                    .tag(discipline)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(height: 100)
        }
    }

    // MARK: Conditional Fields

    @ViewBuilder
    private var conditionalFields: some View {
        switch userStatus {
        case .student:
            yearOfStudyRow
                .padding(.vertical, 12)

        case .fresher:
            graduationYearRow
                .padding(.vertical, 12)

        case .experienced:
            VStack(spacing: 0) {
                Divider()
                yearsOfExperienceRow
                    .padding(.vertical, 12)
                Divider()
                currentDesignationRow
                    .padding(.vertical, 12)
            }
        }
    }

    // MARK: Year of Study (Student only)

    private var yearOfStudyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Year of Study", systemImage: "graduationcap")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Year of Study", selection: $yearOfStudy) {
                ForEach(1...4, id: \.self) { year in
                    Text(yearSuffix(year)).tag(year)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(height: 100)
        }
    }

    // MARK: Graduation Year (Fresher only)

    private var graduationYearRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Graduation Year", systemImage: "graduationcap.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Graduation Year", selection: $graduationYear) {
                let currentYear = Calendar.current.component(.year, from: Date())
                ForEach((currentYear - 5)...(currentYear + 3), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(height: 100)
        }
    }

    // MARK: Years of Experience (Experienced only)

    private var yearsOfExperienceRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Years of Experience", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(yearsOfExperience)) year\(Int(yearsOfExperience) == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                Text("0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $yearsOfExperience, in: 0...15, step: 1)
                Text("15")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Current Designation (Experienced only)

    private var currentDesignationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Current Designation", systemImage: "briefcase")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. Senior Software Engineer", text: $currentDesignation)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    // MARK: Batch Year

    private var batchYearRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Batch Year", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. 2026", text: $batchYearText)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(maxWidth: 200)
        }
    }

    // MARK: Section 3: Job Preferences

    /// Save feedback for the preferences section is driven by `viewModel.preferencesSaveStatus`.

    private var jobPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "star.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text("Job Preferences")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()

                if !selectedRoles.isEmpty {
                    Text("\(selectedRoles.count) selected")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 12)

            Divider()

            preferredRolesSection
                .padding(.vertical, 12)

            Divider()

            // Save Preferences Button
            savePreferencesButton
                .padding(.top, 12)
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Preferred Roles Section

    private var preferredRolesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let branchRoles = TechnicalRole.roles(forBranch: resolvedAcademicBranch)
            let otherRoles = TechnicalRole.allCases.filter { !branchRoles.contains($0) }

            if !branchRoles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(resolvedAcademicBranch.rawValue + " Roles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    multiSelectTags(roles: branchRoles)
                }
            }

            if !otherRoles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Other Roles")
                        .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                    multiSelectTags(roles: otherRoles)
                }
            }
        }
    }

    // MARK: Multi-Select Tags

    private func multiSelectTags(roles: [TechnicalRole]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(roles) { role in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedRoles.contains(role) {
                                selectedRoles.remove(role)
                            } else {
                                selectedRoles.insert(role)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: role.iconName)
                                .font(.caption2)
                            Text(role.rawValue)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
#if os(iOS)
                        .background(
                            selectedRoles.contains(role) ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(uiColor: .systemGray)),
                            in: Capsule()
                        )
#else
                        .background(
                            selectedRoles.contains(role) ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(NSColor.systemGray)),
                            in: Capsule()
                        )
#endif
                        .foregroundStyle(selectedRoles.contains(role) ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Save Preferences Button

    private var savePreferencesButton: some View {
        Button {
            handleSavePreferences()
        } label: {
            HStack(spacing: 6) {
                Text("Save Preferences")
                saveStatusIndicator(status: viewModel.preferencesSaveStatus)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: Save Button (Academic Details)

    private var saveButton: some View {
        Button {
            handleSave()
        } label: {
            HStack(spacing: 6) {
                Text("Save")
                saveStatusIndicator(status: viewModel.academicSaveStatus)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Save Status Indicator

    /// Subtle inline indicator shown inside the save button. Shows a spinner while
    /// syncing, a checkmark on success, and an exclamation mark on failure.
    @ViewBuilder
    private func saveStatusIndicator(status: OptimisticSaveStatus) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .syncing:
            ProgressView()
                .controlSize(.small)
                .tint(.white.opacity(0.8))
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.5)))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .transition(.opacity.combined(with: .scale(scale: 0.5)))
        }
    }

    // MARK: - Helpers

    private func yearSuffix(_ year: Int) -> String {
        switch year {
        case 1: return "1st Year"
        case 2: return "2nd Year"
        case 3: return "3rd Year"
        default: return "\(year)th Year"
        }
    }

    // MARK: - Sync from Profile

    private func syncFromProfile() {
        guard let profile = viewModel.profile else { return }

        // Resolve status enum
        if let resolved = ExperienceLevel(rawValue: profile.experienceLevel) {
            userStatus = resolved
        }

        // Restore yearOfStudy
        if let yos = profile.yearOfStudy, (1...4).contains(yos) {
            yearOfStudy = yos
        }

        // Restore yearsOfExperience
        if let yoe = profile.yearsOfExperience, yoe >= 0 {
            yearsOfExperience = Double(yoe)
        }

        // Restore discipline from domain mapping (best-effort)
        if let firstDomain = profile.domain.isEmpty ? nil : JobDomain(rawValue: profile.domain) {
            for discipline in AcademicDiscipline.allCases where discipline.mappedRoles.contains(firstDomain) {
                selectedDiscipline = discipline
                break
            }
        }

        // Restore from academic branch if available (overrides domain mapping)
        if let branch = profile.academicBranch {
            selectedDiscipline = branch.discipline
        }

        // Restore batch year
        if let by = profile.batchYear {
            batchYearText = String(by)
        }

        // Restore preferred roles
        if !profile.preferredRoles.isEmpty {
            selectedRoles = Set(profile.preferredRoles)
        }
    }

    // MARK: - Validation

    private func validate() -> String? {
        switch userStatus {
        case .student:
            guard (1...4).contains(yearOfStudy) else {
                return "Please select a valid year of study."
            }
        case .fresher:
            break
        case .experienced:
            guard yearsOfExperience >= 0 else {
                return "Years of experience cannot be negative."
            }
            if currentDesignation.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Please enter your current designation."
            }
        }
        return nil
    }

    // MARK: - Save Academic Details Action (Optimistic)

    private func handleSave() {
        if validate() != nil {
            return
        }

        guard let uid = authService.user?.uid, !uid.isEmpty else { return }

        let resolvedYearOfStudy: Int? = userStatus == .student ? yearOfStudy : nil
        let resolvedYearsOfExperience: Int? = userStatus == .experienced ? Int(yearsOfExperience) : nil
        let resolvedBatchYear: Int? = Int(batchYearText)
        let rolesArray = selectedRoles.sorted { $0.rawValue < $1.rawValue }

        // Fire-and-forget: updates local state immediately, writes to Firestore in background
        viewModel.optimisticSaveAcademicDetails(
            experienceLevel: userStatus,
            yearOfStudy: resolvedYearOfStudy,
            yearsOfExperience: resolvedYearsOfExperience,
            batchYear: resolvedBatchYear,
            academicBranch: resolvedAcademicBranch,
            preferredRoles: rolesArray,
            userId: uid
        )
    }

    // MARK: - Save Preferences Action (Optimistic)

    private func handleSavePreferences() {
        guard let uid = authService.user?.uid, !uid.isEmpty else { return }

        let resolvedBatchYear: Int? = Int(batchYearText)
        let rolesArray = selectedRoles.sorted { $0.rawValue < $1.rawValue }

        // Fire-and-forget: updates local state immediately, writes to Firestore in background
        viewModel.optimisticSavePreferences(
            batchYear: resolvedBatchYear,
            academicBranch: resolvedAcademicBranch,
            preferredRoles: rolesArray,
            userId: uid
        )
    }
}
