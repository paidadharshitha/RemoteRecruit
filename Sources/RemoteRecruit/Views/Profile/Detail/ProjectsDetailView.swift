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

// MARK: - Projects Detail View

public struct ProjectsDetailView: View {

    // MARK: Properties

    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddProject = false
    @State private var editingProject: Project? = nil

    private var projects: [Project] {
        viewModel.profile?.projects ?? []
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            Color.secondarySystemBackground
                .ignoresSafeArea()

            if projects.isEmpty {
                emptyStateView
            } else {
                projectsList
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    editingProject = nil
                    showAddProject = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.tint)
                }
            }
        }
        .sheet(isPresented: $showAddProject) {
            EditProjectSheet(project: nil) { updated in
                handleProjectSave(updated, isNew: true)
            }
        }
        .sheet(item: $editingProject) { project in
            EditProjectSheet(project: project) { updated in
                handleProjectSave(updated, isNew: false)
            }
        }
    }

    // MARK: - Projects List

    private var projectsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(projects) { project in
                    projectCard(for: project)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Project Card

    private func projectCard(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(project.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        deleteProject(project)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        editingProject = project
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(project.duration)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Color.tertiarySystemBackground,
                in: Capsule()
            )

            if !project.description.isEmpty {
                Text(project.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !project.technologies.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(project.technologies, id: \.self) { tech in
                        Text(tech)
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.accentColor.opacity(0.1),
                                in: Capsule()
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.systemBackground, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No projects yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Tap + to add your first project")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button {
                editingProject = nil
                showAddProject = true
            } label: {
                Text("Add Project")
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

    private func handleProjectSave(_ project: Project, isNew: Bool) {
        guard let userId = AuthService.shared.user?.uid else { return }

        var updatedProjects = projects
        if isNew {
            updatedProjects.append(project)
        } else {
            if let index = updatedProjects.firstIndex(where: { $0.id == project.id }) {
                updatedProjects[index] = project
            }
        }

        Task {
            await viewModel.updateProjects(updatedProjects, userId: userId)
        }
    }

    private func deleteProject(_ project: Project) {
        guard let userId = AuthService.shared.user?.uid else { return }

        let updatedProjects = projects.filter { $0.id != project.id }
        Task {
            await viewModel.updateProjects(updatedProjects, userId: userId)
        }
    }
}
