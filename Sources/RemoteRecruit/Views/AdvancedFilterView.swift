// AdvancedFilterView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Advanced Filter View

/// A sheet-style view for selecting multiple job filters.
public struct AdvancedFilterView: View {

    @Binding var filter: AdvancedJobFilter
    @Environment(\.dismiss) private var dismiss

    public init(filter: Binding<AdvancedJobFilter>) {
        self._filter = filter
    }

    public var body: some View {
        NavigationStack {
            Form {
                experienceSection
                workTypeSection
                salarySection
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .principal) {
                    if filter.isActive {
                        Button("Clear All") {
                            withAnimation { filter.clearAll() }
                        }
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Experience Section

    private var experienceSection: some View {
        Section {
            ForEach(ExperienceFilter.allCases) { level in
                FilterToggleRow(
                    title: level.displayName,
                    icon: experienceIcon(for: level),
                    isSelected: filter.experienceFilters.contains(level)
                ) {
                    withAnimation { toggleExperience(level) }
                }
            }
        } header: {
            Text("Experience Level")
                .font(DesignTokens.Typography.captionSemibold)
        }
    }

    // MARK: - Work Type Section

    private var workTypeSection: some View {
        Section {
            ForEach(WorkType.allCases) { type in
                FilterToggleRow(
                    title: type.displayName,
                    icon: type.iconName,
                    isSelected: filter.workTypeFilters.contains(type)
                ) {
                    withAnimation { toggleWorkType(type) }
                }
            }
        } header: {
            Text("Work Type")
                .font(DesignTokens.Typography.captionSemibold)
        }
    }

    // MARK: - Salary Section

    private var salarySection: some View {
        Section {
            ForEach(SalaryRange.allCases) { range in
                FilterToggleRow(
                    title: range.rawValue,
                    icon: "banknote",
                    isSelected: filter.salaryFilters.contains(range)
                ) {
                    withAnimation { toggleSalary(range) }
                }
            }
        } header: {
            Text("Salary Range")
                .font(DesignTokens.Typography.captionSemibold)
        }
    }

    // MARK: - Toggle Helpers

    private func toggleExperience(_ level: ExperienceFilter) {
        if filter.experienceFilters.contains(level) {
            filter.experienceFilters.remove(level)
        } else {
            filter.experienceFilters.insert(level)
        }
    }

    private func toggleWorkType(_ type: WorkType) {
        if filter.workTypeFilters.contains(type) {
            filter.workTypeFilters.remove(type)
        } else {
            filter.workTypeFilters.insert(type)
        }
    }

    private func toggleSalary(_ range: SalaryRange) {
        if filter.salaryFilters.contains(range) {
            filter.salaryFilters.remove(range)
        } else {
            filter.salaryFilters.insert(range)
        }
    }

    private func experienceIcon(for level: ExperienceFilter) -> String {
        switch level {
        case .internship: return "graduationcap"
        case .fresher: return "leaf"
        case .experienced: return "star.fill"
        }
    }
}

// MARK: - Filter Toggle Row

private struct FilterToggleRow: View {

    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? DesignTokens.Colors.accent : .secondary)
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
