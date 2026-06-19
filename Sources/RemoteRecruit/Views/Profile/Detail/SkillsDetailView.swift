import SwiftUI
import FirebaseAuth

// MARK: - Cross-platform system color helpers

#if os(iOS)
private extension Color {
    static let systemBackground = Color(.systemBackground)
    static let secondarySystemBackground = Color(.secondarySystemBackground)
    static let tertiarySystemBackground = Color(.tertiarySystemBackground)
    static let systemGray4 = Color(.systemGray4)
}
#else
private extension Color {
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.controlBackgroundColor)
    static let tertiarySystemBackground = Color(NSColor.underPageBackgroundColor)
    static let systemGray4 = Color(NSColor.separatorColor)
}
#endif

// MARK: - Skills Detail View

public struct SkillsDetailView: View {

    // MARK: Properties

    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditMode = false
    @State private var newSkillText = ""
    @State private var editedSkills: [String] = []

    private var skills: [String] {
        viewModel.profile?.skills ?? []
    }

    private var hasChanges: Bool {
        editedSkills != skills
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            Color.secondarySystemBackground
                .ignoresSafeArea()

            if skills.isEmpty && !isEditMode {
                emptyStateView
            } else {
                skillsContent
            }
        }
        .navigationTitle("Skills")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if isEditMode {
                    Button("Save") {
                        saveSkills()
                    }
                    .foregroundStyle(.tint)
                    .disabled(!hasChanges)
                } else {
                    Button {
                        enterEditMode()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    // MARK: - Skills Content

    private var skillsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isEditMode {
                    HStack(spacing: 12) {
                        TextField("Add a skill", text: $newSkillText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Color.systemBackground,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.systemGray4, lineWidth: 1)
                            )

                        Button {
                            addSkill()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        .disabled(newSkillText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                }

                FlowLayout(spacing: DesignTokens.Spacing.md) {
                    ForEach(displayedSkills, id: \.self) { skill in
                        skillChip(for: skill)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Displayed Skills

    private var displayedSkills: [String] {
        isEditMode ? editedSkills : skills
    }

    // MARK: - Skill Chip

    private func skillChip(for skill: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(skill)
                .font(DesignTokens.Typography.captionSemibold)
                .foregroundStyle(DesignTokens.Colors.accent)

            if isEditMode {
                Button {
                    removeSkill(skill)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundStyle(DesignTokens.Colors.accent)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            DesignTokens.Colors.accent.opacity(0.1),
            in: Capsule()
        )
        .animation(DesignTokens.Animations.quickSpring, value: displayedSkills)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No skills added")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tap the edit button to add your skills")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Edit Mode

    private func enterEditMode() {
        editedSkills = skills
        isEditMode = true
    }

    // MARK: - Actions

    private func addSkill() {
        let trimmed = newSkillText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !editedSkills.contains(trimmed) else { return }

        editedSkills.append(trimmed)
        newSkillText = ""
    }

    private func removeSkill(_ skill: String) {
        editedSkills.removeAll { $0 == skill }
    }

    private func saveSkills() {
        guard let userId = AuthService.shared.user?.uid else { return }

        Task {
            await viewModel.updateSkills(editedSkills, userId: userId)
        }
        isEditMode = false
    }
}
