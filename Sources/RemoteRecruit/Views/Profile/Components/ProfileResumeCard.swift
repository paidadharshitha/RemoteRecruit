//
//  ProfileResumeCard.swift
//  RemoteRecruit
//
//  Resume upload, processing status, and parsed-data preview card.
//

import SwiftUI

// MARK: - PipelineStatusView

/// Displays an animated progress indicator for resume pipeline steps.
struct PipelineStatusView: View {

    let step: ResumePipelineStep

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.accentColor)

            VStack(spacing: 6) {
                Image(systemName: stepIcon)
                    .font(.title2)
                    .foregroundStyle(.tint)

                Text(step.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(stepDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var stepIcon: String {
        switch step {
        case .uploading: return "icloud.and.arrow.up"
        case .extracting: return "doc.text.viewfinder"
        case .parsing: return "text.magnifyingglass"
        case .saving: return "square.and.arrow.down"
        case .failed: return "exclamationmark.triangle"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private var stepDescription: String {
        switch step {
        case .uploading: return "Uploading your resume to the cloud…"
        case .extracting: return "Extracting text from your resume…"
        case .parsing: return "AI is analyzing your resume details…"
        case .saving: return "Saving parsed information…"
        case .failed(let message): return message
        default: return "Processing…"
        }
    }
}

// MARK: - ProfileResumeCard

/// Resume section card that handles upload, pipeline progress, and parsed-data preview.
public struct ProfileResumeCard: View {

    // MARK: Properties

    private let pipelineStep: ResumePipelineStep
    private let parsingState: ResumeParsingState
    @Binding private var showDocumentPicker: Bool
    private let resumeURL: String?

    private var onUploadTap: () -> Void
    private var onConfirm: () -> Void
    private var onDiscard: () -> Void
    private var onReset: () -> Void

    // MARK: Initializer

    public init(
        pipelineStep: ResumePipelineStep,
        parsingState: ResumeParsingState,
        showDocumentPicker: Binding<Bool>,
        resumeURL: String?,
        onUploadTap: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        self.pipelineStep = pipelineStep
        self.parsingState = parsingState
        self._showDocumentPicker = showDocumentPicker
        self.resumeURL = resumeURL
        self.onUploadTap = onUploadTap
        self.onConfirm = onConfirm
        self.onDiscard = onDiscard
        self.onReset = onReset
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader

            // Content
            cardContent
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Section Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Text("Resume")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Spacer()

            // Reset button when done or failed
            if pipelineStep == .done || pipelineStep.isFailure {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch pipelineStep {
        case .idle:
            idleContent
        case .uploading, .extracting, .parsing, .saving:
            PipelineStatusView(step: pipelineStep)
        case .preview(let parsed):
            previewContent(parsed: parsed)
        case .done:
            doneContent
        case .failed(let message):
            failedContent(message: message)
        }
    }

    // MARK: - Idle State

    private var idleContent: some View {
        VStack(spacing: 12) {
            if let resumeURL, !resumeURL.isEmpty {
                // Existing resume link
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resume uploaded")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("Tap to upload a new version")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Button(action: onUploadTap) {
                    Text("Replace Resume")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            } else {
                // No resume yet
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No resume uploaded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: onUploadTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.doc.fill")
                            Text("Upload Resume")
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Preview State

    private func previewContent(parsed: ParsedResume) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .foregroundStyle(.yellow)
                Text("Resume Parsed Successfully")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }

            Divider()

            // Info rows
            VStack(spacing: 10) {
                if !parsed.name.isEmpty {
                    infoRow(icon: "person", label: "Name", value: parsed.name)
                }
                if !parsed.email.isEmpty {
                    infoRow(icon: "envelope", label: "Email", value: parsed.email)
                }
                if !parsed.phone.isEmpty {
                    infoRow(icon: "phone", label: "Phone", value: parsed.phone)
                }
                if !parsed.domain.isEmpty {
                    infoRow(icon: "briefcase", label: "Domain", value: parsed.domain)
                }
                if !parsed.experience.isEmpty {
                    infoRow(icon: "clock", label: "Experience", value: parsed.experience)
                }
                if !parsed.portfolioLink.isEmpty {
                    infoRow(icon: "link", label: "Portfolio", value: parsed.portfolioLink)
                }
            }

            Divider()

            // Skills
            if !parsed.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Skills", systemImage: "tag.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(parsed.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            // Summaries
            HStack(spacing: 12) {
                summaryBadge(
                    icon: "folder.fill",
                    count: parsed.projects.count,
                    label: "Projects"
                )
                summaryBadge(
                    icon: "building.2.fill",
                    count: parsed.workExperience.count,
                    label: "Experience"
                )
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                // Discard
                Button(action: onDiscard) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Discard")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Confirm
                Button(action: onConfirm) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Confirm")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Done State

    private var doneContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Resume processed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Your profile has been updated with resume data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Failed State

    private func failedContent(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onReset) {
                Text("Try Again")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Reusable Helpers

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
    }

    private func summaryBadge(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.tint)

            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ResumePipelineStep Failure Helper

private extension ResumePipelineStep {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
