import SwiftUI

// MARK: - Edit Project Sheet

public struct EditProjectSheet: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var role: String
    @State private var duration: String
    @State private var techText: String
    private let existingProject: Project?
    private let onSave: (Project) -> Void

    // MARK: - Initializer

    init(project: Project?, onSave: @escaping (Project) -> Void) {
        self.existingProject = project
        self.onSave = onSave
        _title = State(initialValue: project?.title ?? "")
        _description = State(initialValue: project?.description ?? "")
        _role = State(initialValue: project?.role ?? "")
        _duration = State(initialValue: project?.duration ?? "")
        _techText = State(initialValue: project?.technologies.joined(separator: ", ") ?? "")
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Title", text: $title)
                    TextField("Your Role", text: $role)
                    TextField("Duration (e.g. 3 months)", text: $duration)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }

                Section("Technologies") {
                    TextField("Swift, SwiftUI, Firebase…", text: $techText)
                }
            }
            .navigationTitle(existingProject == nil ? "Add Project" : "Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProject()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func saveProject() {
        let technologies = techText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let project = Project(
            id: existingProject?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            technologies: technologies,
            role: role.trimmingCharacters(in: .whitespaces),
            duration: duration.trimmingCharacters(in: .whitespaces)
        )
        onSave(project)
        dismiss()
    }
}
