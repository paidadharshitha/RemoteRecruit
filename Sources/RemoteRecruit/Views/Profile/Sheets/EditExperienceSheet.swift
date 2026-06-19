import SwiftUI

// MARK: - Edit Experience Sheet

public struct EditExperienceSheet: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var company: String
    @State private var role: String
    @State private var duration: String
    @State private var description: String

    private let existingExperience: WorkExperience?
    private let onSave: (WorkExperience) -> Void

    // MARK: - Initializer

    init(experience: WorkExperience?, onSave: @escaping (WorkExperience) -> Void) {
        self.existingExperience = experience
        self.onSave = onSave
        _company = State(initialValue: experience?.company ?? "")
        _role = State(initialValue: experience?.role ?? "")
        _duration = State(initialValue: experience?.duration ?? "")
        _description = State(initialValue: experience?.description ?? "")
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                Section("Job Details") {
                    TextField("Company", text: $company)
                    TextField("Role / Title", text: $role)
                    TextField("Duration (e.g. Jun 2024 – Sep 2024)", text: $duration)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(existingExperience == nil ? "Add Experience" : "Edit Experience")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExperience()
                    }
                    .disabled(company.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func saveExperience() {
        let exp = WorkExperience(
            id: existingExperience?.id ?? UUID().uuidString,
            company: company.trimmingCharacters(in: .whitespaces),
            role: role.trimmingCharacters(in: .whitespaces),
            duration: duration.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces)
        )
        onSave(exp)
        dismiss()
    }
}
