// ResumeOptimizerView.swift
// RemoteRecruit

import SwiftUI
import UniformTypeIdentifiers

public struct ResumeOptimizerView: View {

    @StateObject private var viewModel: ResumeOptimizerViewModel
    @Environment(\.dismiss) private var dismiss

    /// Optional job to pre-fill the JD field (Job-to-Resume flow).
    private let preFilledJob: Job?

    /// Supported document types for file import.
    private static let supportedContentTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText, .utf8PlainText]
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        return types
    }()

    #if os(iOS)
    private static let fillColor = Color(uiColor: .systemFill)
    #else
    private static let fillColor = Color(NSColor.controlBackgroundColor)
    #endif

    public init(viewModel: ResumeOptimizerViewModel, job: Job? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.preFilledJob = job
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Resume Input
                    resumeInputSection

                    // MARK: - Job Description Input
                    jobDescriptionSection

                    // MARK: - Analyze Button
                    analyzeButton

                    // MARK: - State Content
                    stateContent
                }
                .padding()
            }
            .navigationTitle("AI Resume Optimizer")
            .overlay {
                // Extraction overlay
                if case .extracting = viewModel.extractionState {
                    ExtractionOverlay()
                }
            }
            .alert("Error", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {
                    viewModel.dismissAlert()
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            .fileImporter(
                isPresented: $viewModel.showFileImporter,
                allowedContentTypes: Self.supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleUploadedFile(result: result)
            }
            .onAppear {
                if let job = preFilledJob {
                    viewModel.preFillJobDescription(job.jobDescription)
                }
            }
        }
    }

    // MARK: - Resume Input Section

    private var resumeInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Your Resume", systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.showFileImporter = true
                } label: {
                    Label("Upload PDF", systemImage: "arrow.up.doc")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.tint.opacity(0.1), in: Capsule())
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }

            if case .fileUpload(let fileName) = viewModel.resumeSource,
               viewModel.extractionState == .success {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("extracted")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else if case .fileUpload = viewModel.resumeSource,
                      case .error(let msg) = viewModel.extractionState {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

            TextEditor(text: $viewModel.resumeText)
                .frame(minHeight: 160)
                .padding(8)
                .background(Self.fillColor, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .font(.body)

            Text("\(viewModel.resumeText.trimmingCharacters(in: .whitespacesAndNewlines).count) characters")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Job Description Section

    private var jobDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Job Description", systemImage: "briefcase")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if preFilledJob != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text("Pre-filled from \(preFilledJob?.companyName ?? "job")")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.1), in: Capsule())
                }
            }

            TextEditor(text: $viewModel.jobDescription)
                .frame(minHeight: 140)
                .padding(8)
                .background(Self.fillColor, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .font(.body)

            Text("\(viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).count) characters")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.analyzeResume() }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.viewState.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Image(systemName: "sparkles")
                    Text(viewModel.viewState.isLoading ? "Analyzing..." : "Optimize Resume with AI")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.isFormValid ? Color.blue : Self.fillColor, in: Capsule())
                .foregroundStyle(.white)
            }
            .disabled(viewModel.viewState.isLoading || !viewModel.isFormValid)

            // Smooth progress bar during analysis
            if viewModel.viewState.isLoading {
                ProgressView("Sending to AI...")
                    .tint(.blue)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.viewState {
        case .idle:
            Color.clear
                .frame(height: 0)

        case .loading:
            ResumeOptimizerShimmer()
                .transition(.opacity)

        case .success(let result):
            VStack(spacing: 28) {
                resultsSection(result)
                aiChangesSection(result.aiChanges)
                optimizedResumeSection(result: result.optimizedResume, score: result.atsScore)
                pdfExportSection
            }
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task { await viewModel.analyzeResume() }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.tint, in: Capsule())
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
            .padding(.vertical, 20)

        case .empty:
            Color.clear
                .frame(height: 0)
        }
    }

    // MARK: - Section Card

    /// Reusable card wrapper with consistent styling.
    private func sectionCard<Content: View>(
        headerIcon: String,
        headerTitle: String,
        headerColor: Color,
        bgColor: Color = ResumeOptimizerView.fillColor,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(headerTitle, systemImage: headerIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(headerColor)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results Section (ATS Score + Gaps + Keywords)

    private func resultsSection(_ result: ResumeOptimizerResult) -> some View {
        VStack(spacing: 24) {

            // ATS Score Ring — fixed size with breathing room
            VStack(spacing: 12) {
                CircularScoreRing(score: result.atsScore)
                    .padding(.top, 8)
                    .frame(height: 200)

                if !result.aiExplanation.isEmpty {
                    Text(result.aiExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue.opacity(0.15), lineWidth: 1)
                        )
                }
            }

            // Missing Keywords
            if !result.missingKeywords.isEmpty {
                sectionCard(
                    headerIcon: "exclamationmark.triangle",
                    headerTitle: "Missing Keywords",
                    headerColor: .red,
                    bgColor: .red.opacity(0.05)
                ) {
                    KeywordFlowLayout(items: result.missingKeywords, color: .red)
                }
            }

            // Skill Gaps
            if !result.skillGaps.isEmpty {
                sectionCard(
                    headerIcon: "wrench.and.screwdriver",
                    headerTitle: "Skill Gaps",
                    headerColor: .orange,
                    bgColor: .orange.opacity(0.05)
                ) {
                    ForEach(Array(result.skillGaps.enumerated()), id: \.offset) { index, gap in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                                .frame(width: 20, alignment: .leading)

                            Text(gap)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            // Experience Gaps
            if !result.experienceGaps.isEmpty {
                sectionCard(
                    headerIcon: "person.crop.circle.badge.questionmark",
                    headerTitle: "Experience Gaps",
                    headerColor: .purple,
                    bgColor: .purple.opacity(0.05)
                ) {
                    ForEach(Array(result.experienceGaps.enumerated()), id: \.offset) { index, gap in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.purple)
                                .frame(width: 20, alignment: .leading)

                            Text(gap)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            // Suggestions
            if !result.suggestions.isEmpty {
                sectionCard(
                    headerIcon: "lightbulb.fill",
                    headerTitle: "Suggestions",
                    headerColor: .secondary
                ) {
                    ForEach(Array(result.suggestions.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.blue)
                                .frame(width: 20, height: 20)

                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)

                        if index < result.suggestions.count - 1 {
                            Divider()
                                .padding(.leading, 32)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Changes Made by AI Section

    @ViewBuilder
    private func aiChangesSection(_ changes: AIChanges) -> some View {
        let hasContent = !changes.keywordsAdded.isEmpty
            || !changes.keywordsReplaced.isEmpty
            || !changes.sectionChanges.isEmpty

        if hasContent {
            VStack(alignment: .leading, spacing: 16) {
                Label("Changes Made by AI", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Keywords Added
                if !changes.keywordsAdded.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Keywords Added")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        }

                        KeywordFlowLayout(items: changes.keywordsAdded, color: .green)
                    }
                }

                // Keywords Replaced
                if !changes.keywordsReplaced.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Keywords Rephrased / Upgraded")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }

                        ForEach(changes.keywordsReplaced, id: \.self) { keyword in
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text(keyword)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // Section Changes
                if !changes.sectionChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.and.outline")
                                .font(.caption)
                                .foregroundStyle(.indigo)
                            Text("Section Enhancements")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.indigo)
                        }

                        ForEach(changes.sectionChanges) { change in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(change.section)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.indigo)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.indigo.opacity(0.1), in: Capsule())
                                }
                                Text(change.description)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
            }
            .padding(16)
            .background(.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.blue.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Optimized Resume Preview (with ATS Score)

    @ViewBuilder
    private func optimizedResumeSection(result: OptimizedResume, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with badge
            HStack {
                Label("Optimized Resume", systemImage: "doc.richtext")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "chart.donut")
                        .font(.caption)
                    Text("\(score)/100")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(scoreColor(for: score))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(scoreColor(for: score).opacity(0.12), in: Capsule())
            }

            // Summary
            if !result.summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Professional Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 4)
            }

            // Skills as tags
            if !result.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skills")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    KeywordFlowLayout(items: result.skills, color: .blue)
                }
                .padding(.bottom, 4)
            }

            // Experience
            if !result.experience.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Experience")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)

                    ForEach(result.experience) { exp in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(exp.role)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            Text("\(exp.company)  \u{2022}  \(exp.duration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(Array(exp.bullets.enumerated()), id: \.offset) { _, bullet in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(bullet)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Projects
            if !result.projects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Projects")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)

                    ForEach(result.projects) { project in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(project.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            Text("\(project.duration)  \u{2022}  \(project.technologies.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(Array(project.bullets.enumerated()), id: \.offset) { _, bullet in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(bullet)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - PDF Export Section

    private var pdfExportSection: some View {
        VStack(spacing: 12) {
            switch viewModel.pdfExportState {
            case .idle:
                Button {
                    viewModel.exportPDF()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Download Optimized Resume as PDF")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.green, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

            case .generating:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating PDF...")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Self.fillColor, in: Capsule())

            case .success(let url):
                ShareLink(item: url) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("PDF Ready — Tap to Share/Save")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.green, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

            case .error(let message):
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Retry PDF Export") {
                        viewModel.exportPDF()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                }
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .red
        }
    }
}


// MARK: - Extraction Overlay

/// Full-screen overlay shown while extracting text from an uploaded file.
private struct ExtractionOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Extracting text...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
    }
}

// MARK: - Keyword Flow Layout Helper

/// Renders keyword strings as individually-styled capsule tags inside a flow layout.
private struct KeywordFlowLayout: View {
    let items: [String]
    let color: Color

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { keyword in
                Text(keyword)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.12), in: Capsule())
                    .foregroundStyle(color)
                    .fixedSize()
            }
        }
    }
}

