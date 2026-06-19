//
//  DomainRoleSectionCard.swift
//  RemoteRecruit
//
//  Dedicated card for Domain & Experience Level selection.
//

import SwiftUI

// MARK: - DomainRoleSectionCard

/// A settings-style card with Domain and Experience Level pickers displayed as navigation rows.
struct DomainRoleSectionCard: View {

    // MARK: Properties

    @Binding var domain: String
    @Binding var experienceLevel: String

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "person.badge.key")
                    .font(.subheadline.weight(.semibold))
.foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text("Domain & Role")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.bottom, 12)

            // Domain row
            NavigationLink {
                DomainPickerView(selection: $domain)
            } label: {
                HStack {
                    Image(systemName: "briefcase")
                        .font(.body)
                        .foregroundStyle(.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Domain")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(domain.isEmpty ? "Select a domain" : domain)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(domain.isEmpty ? .tertiary : .primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider()

            // Experience Level row
            NavigationLink {
                ExperienceLevelPickerView(selection: $experienceLevel)
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.body)
                        .foregroundStyle(.purple)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Experience Level")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(experienceLevel.isEmpty ? "Select level" : experienceLevel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(experienceLevel.isEmpty ? .tertiary : .primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }
}

// MARK: - DomainPickerView

/// A full-screen picker for selecting a Job Domain.
struct DomainPickerView: View {

    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(JobDomain.allCases) { domain in
                Button {
                    selection = domain.rawValue
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: domainIcon(for: domain))
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        Text(domain.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == domain.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Domain")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func domainIcon(for domain: JobDomain) -> String {
        switch domain {
        case .iosDeveloper: return "iphone"
        case .backendEngineer: return "server.rack"
        case .productDesigner: return "paintbrush"
        case .dataScientist: return "chart.bar.doc.horizontal"
        case .softwareDeveloper: return "chevron.left.forwardslash.chevron.right"
        case .dataEngineer: return "cylinder.split.1x2.fill"
        case .embeddedSystemsEngineer: return "chip"
        case .hardwareEngineer: return "internaldrive"
        case .powerSystemsEngineer: return "bolt.fill"
        case .controlSystemsEngineer: return "gauge.with.dots.needle.bottom.50percent"
        case .webDeveloper: return "globe"
        case .aiSpecialist: return "brain"
        case .vlsiEngineer: return "memorychip"
        case .firmwareDeveloper: return "hammer"
        case .electricalDesigner: return "lightbulb.led"
        case .cadDesigner: return "pencil.and.ruler"
        case .productDesignEngineer: return "cube"
        case .thermalEngineer: return "thermometer.medium"
        }
    }
}

// MARK: - ExperienceLevelPickerView

/// A full-screen picker for selecting an Experience Level.
struct ExperienceLevelPickerView: View {

    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(ExperienceLevel.allCases) { level in
                Button {
                    selection = level.rawValue
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: levelIcon(for: level))
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        Text(level.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == level.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Experience Level")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func levelIcon(for level: ExperienceLevel) -> String {
        switch level {
        case .student: return "graduationcap"
        case .fresher: return "sprout"
        case .experienced: return "star.circle"
        }
    }
}
