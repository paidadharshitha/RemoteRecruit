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

// MARK: - Experience Detail View

public struct ExperienceDetailView: View {

    // MARK: Properties

    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddExperience = false
    @State private var editingExperience: WorkExperience? = nil

    private var experiences: [WorkExperience] {
        viewModel.profile?.workExperience ?? []
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            Color.secondarySystemBackground
                .ignoresSafeArea()

            if experiences.isEmpty {
                emptyStateView
            } else {
                experienceTimeline
            }
        }
        .navigationTitle("Experience")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    editingExperience = nil
                    showAddExperience = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.tint)
                }
            }
        }
        .sheet(isPresented: $showAddExperience) {
            EditExperienceSheet(experience: nil) { updated in
                handleExperienceSave(updated, isNew: true)
            }
        }
        .sheet(item: $editingExperience) { experience in
            EditExperienceSheet(experience: experience) { updated in
                handleExperienceSave(updated, isNew: false)
            }
        }
    }

    // MARK: - Timeline

    private var experienceTimeline: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(experiences.enumerated()), id: \.element.id) { index, experience in
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 12, height: 12)
                                Circle()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                                    .frame(width: 18, height: 18)
                            }
                            .padding(.top, 18)

                            if index < experiences.count - 1 {
                                Rectangle()
                                    .fill(Color.systemGray4)
                                    .frame(width: 2)
                                    .frame(minHeight: 20)
                            }
                        }
                        .frame(width: 32)
                        .padding(.top, index == 0 ? 8 : 0)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(experience.role)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)

                                    Text(experience.company)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 12) {
                                    Button {
                                        deleteExperience(experience)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }

                                    Button {
                                        editingExperience = experience
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "briefcase")
                                    .font(.caption2)
                                Text(experience.duration)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Color.tertiarySystemBackground,
                                in: Capsule()
                            )

                            if !experience.description.isEmpty {
                                Text(experience.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(16)
                        .background(Color.systemBackground, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                        .padding(.trailing, 16)
                        .padding(.leading, 8)
                        .padding(.top, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "briefcase")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No experience yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tap + to add your work experience")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button {
                editingExperience = nil
                showAddExperience = true
            } label: {
                Text("Add Experience")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func handleExperienceSave(_ experience: WorkExperience, isNew: Bool) {
        guard let userId = AuthService.shared.user?.uid else { return }

        var updated = experiences
        if isNew {
            updated.append(experience)
        } else {
            if let index = updated.firstIndex(where: { $0.id == experience.id }) {
                updated[index] = experience
            }
        }

        Task {
            await viewModel.updateWorkExperience(updated, userId: userId)
        }
    }

    private func deleteExperience(_ experience: WorkExperience) {
        guard let userId = AuthService.shared.user?.uid else { return }

        let updated = experiences.filter { $0.id != experience.id }
        Task {
            await viewModel.updateWorkExperience(updated, userId: userId)
        }
    }
}
