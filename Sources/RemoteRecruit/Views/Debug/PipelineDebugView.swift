// PipelineDebugView.swift
// RemoteRecruit — Debug / Integration Test View
//
// Drop this into any NavigationStack or present as a sheet to visually
// verify the full resume pipeline (Upload → Extract → Parse → Preview)
// without needing the Xcode console.

import SwiftUI
import Combine

// MARK: - Debug Log Entry

/// A single timestamped log line rendered in the debug overlay.
struct DebugLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let step: String
    let message: String
    let isError: Bool
}

// MARK: - Validation Result

/// Compares a single ParsedResume field against the expected MockResumeParser output.
struct FieldValidation: Identifiable {
    let id = UUID()
    let field: String
    let expected: String
    let actual: String
    var passed: Bool { expected == actual }
}

// MARK: - Pipeline Debug View Model

/// Wraps a `ProfileViewModel` (backed by `MockResumeParser`) and exposes a
/// timestamped debug log plus automated field validation.
@MainActor
final class PipelineDebugViewModel: ObservableObject {

    // MARK: - Published (forwarded from ProfileViewModel)

    @Published private(set) var pipelineStep: ResumePipelineStep = .idle
    @Published private(set) var parsedResume: ParsedResume?
    @Published private(set) var extractedSkills: [String] = []

    // MARK: - Debug-only published state

    @Published private(set) var logEntries: [DebugLogEntry] = []
    @Published private(set) var validationResults: [FieldValidation] = []
    @Published private(set) var allValidationPassed = false

    // MARK: - Private

    private let inner: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // ProfileViewModel backed by MockResumeParser — no API key needed
        inner = ProfileViewModel(resumeParser: MockResumeParser())

        // Mirror pipelineStep changes into the debug log
        inner.$pipelineStep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.onStepChanged($0) }
            .store(in: &cancellables)

        // Mirror parsedResume and run validation
        inner.$parsedResume
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.parsedResume = $0
                if let r = $0 { self?.runValidation(against: r) }
            }
            .store(in: &cancellables)

        // Mirror extracted skills
        inner.$extractedSkills
            .receive(on: DispatchQueue.main)
            .assign(to: &$extractedSkills)
    }

    // MARK: - Log

    private func onStepChanged(_ step: ResumePipelineStep) {
        pipelineStep = step
        logEntries.append(DebugLogEntry(
            timestamp: Date(),
            step: label(for: step),
            message: detail(for: step),
            isError: isFailed(step)
        ))
    }

    private func appendLog(step: String, message: String, isError: Bool) {
        logEntries.append(DebugLogEntry(
            timestamp: Date(),
            step: step,
            message: message,
            isError: isError
        ))
    }

    // MARK: - Test Actions

    /// Runs the **real** `processResume` pipeline end-to-end.
    /// Steps 1 (upload) will fail without Firebase — useful for confirming
    /// the pipeline enters the `.failed` state with a logged message.
    func runFullPipeline() {
        clearLog()
        appendLog(step: "TEST", message: "▶️ Starting full pipeline with dummy PDF data…", isError: false)

        // Dummy PDF bytes — not a real PDF, so PDFKit extraction will return empty.
        let dummyData = Data("%PDF-1.4 dummy content for testing".utf8)
        Task { await inner.processResume(data: dummyData, userId: "test-user-debug") }
    }

    /// Runs a **parse-only** test that skips Upload (Step 1) and PDF extraction (Step 2),
    /// directly feeding mock text to the MockResumeParser.
    /// This is the recommended way to verify Parse → Preview + field mapping.
    func runParseOnly() async {
        clearLog()

        let mockText = """
        Jane Doe
        Senior iOS Developer at TechCorp
        Skills: Swift, SwiftUI, UIKit, Combine, Core Data, Firebase
        Experience: 5 years in mobile development
        Domain: iOS Development
        Phone: +1 555-123-4567
        Email: jane.doe@example.com
        Portfolio: https://janedoe.dev
        """

        appendLog(step: "TEST", message: "▶️ Parse-only test — skipping Upload & PDF extraction", isError: false)

        // Simulate Step 1
        pipelineStep = .uploading
        appendLog(step: "UPLOAD", message: "⏭️ Upload step skipped (test mode)", isError: false)
        try? await Task.sleep(for: .milliseconds(500))

        // Simulate Step 2
        pipelineStep = .extracting
        appendLog(step: "EXTRACT", message: "📄 Mock extraction: \(mockText.count) characters", isError: false)
        try? await Task.sleep(for: .milliseconds(500))

        // Step 3 — real parse via MockResumeParser
        pipelineStep = .parsing
        appendLog(step: "PARSE", message: "🤖 Calling MockResumeParser.parse(text:)…", isError: false)

        do {
            let parsed = try await MockResumeParser().parse(text: mockText)
            try? await Task.sleep(for: .milliseconds(300))

            // Step 4 — success
            parsedResume = parsed
            extractedSkills = parsed.skills
            pipelineStep = .preview(parsed)
            appendLog(step: "PREVIEW",
                       message: "✅ Parse succeeded — name: \(parsed.name), skills: \(parsed.skills.count), domain: \(parsed.domain)",
                       isError: false)
        } catch {
            pipelineStep = .failed(error.localizedDescription)
            appendLog(step: "ERROR", message: "❌ Parse failed: \(error.localizedDescription)", isError: true)
        }
    }

    /// Resets all state for a fresh test run.
    func reset() {
        inner.resetPipeline()
        logEntries.removeAll()
        validationResults.removeAll()
        allValidationPassed = false
        parsedResume = nil
        extractedSkills = []
    }

    // MARK: - Validation

    private func runValidation(against parsed: ParsedResume) {
        // These are the exact values MockResumeParser returns (see MockResumeParser.parse)
        let expected = ParsedResume(
            name: "Jane Doe",
            email: "jane.doe@example.com",
            skills: ["Swift", "SwiftUI", "UIKit", "Combine", "Core Data"],
            experience: "Fresher",
            phone: "+1 555-123-4567",
            domain: "iOS Developer",
            portfolioLink: "https://janedoe.dev"
        )

        validationResults = [
            check("Name",     expected.name,          parsed.name),
            check("Email",    expected.email,         parsed.email),
            check("Skills",   expected.skills.joined(separator: ", "), parsed.skills.joined(separator: ", ")),
            check("Domain",   expected.domain,        parsed.domain),
            check("Phone",    expected.phone,         parsed.phone),
            check("Exp",      expected.experience,    parsed.experience),
            check("Portfolio", expected.portfolioLink, parsed.portfolioLink),
        ]

        allValidationPassed = validationResults.allSatisfy(\.passed)
        appendLog(step: "VALIDATE",
                  message: allValidationPassed
                    ? "✅ All 7 fields match MockResumeParser output"
                    : "⚠️  Some fields don't match — see validation below",
                  isError: !allValidationPassed)
    }

    private func check(_ field: String, _ expected: String, _ actual: String) -> FieldValidation {
        FieldValidation(field: field, expected: expected, actual: actual)
    }

    // MARK: - Helpers

    private func clearLog() {
        logEntries.removeAll()
        validationResults.removeAll()
        allValidationPassed = false
    }

    private func label(for step: ResumePipelineStep) -> String {
        switch step {
        case .idle:     return "IDLE"
        case .uploading: return "UPLOADING"
        case .extracting: return "EXTRACTING"
        case .parsing:   return "PARSING"
        case .saving:    return "SAVING"
        case .preview:  return "PREVIEW"
        case .done:      return "DONE"
        case .failed:    return "FAILED"
        }
    }

    private func detail(for step: ResumePipelineStep) -> String {
        switch step {
        case .idle:     return "Pipeline reset to idle."
        case .uploading: return "Step 1 — Uploading resume to Firebase Storage…"
        case .extracting: return "Step 2 — Extracting text from PDF via PDFKit…"
        case .parsing:   return "Step 3 — Analyzing extracted text with AI…"
        case .saving:    return "Saving merged profile to Firestore…"
        case .preview(let p):
            return "✅ Preview ready: \(p.name) · \(p.skills.count) skills · \(p.domain)"
        case .done:     return "Profile updated successfully."
        case .failed(let msg): return "❌ \(msg)"
        }
    }

    private func isFailed(_ step: ResumePipelineStep) -> Bool {
        if case .failed = step { return true }
        return false
    }
}

// MARK: - Pipeline Debug View

/// A self-contained test screen with:
/// - **Run Full Pipeline** — calls `processResume` with dummy data (needs Firebase)
/// - **Run Parse Only** — skips upload/extraction, tests Parse → Preview (no Firebase needed)
/// - **Live Debug Log** — scrollable timestamped overlay of every pipelineStep transition
/// - **Validation Panel** — checks all 7 ParsedResume fields against expected mock output
///
/// Usage:
/// ```swift
/// NavigationStack { PipelineDebugView() }
/// // or
/// .sheet(isPresented: $showDebug) { PipelineDebugView() }
/// ```
public struct PipelineDebugView: View {

    @StateObject private var debugVM = PipelineDebugViewModel()

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Current State ──
                    currentStateCard

                    // ── Action Buttons ──
                    actionButtons

                    // ── Live Debug Log ──
                    debugLogPanel

                    // ── Validation Results ──
                    if !debugVM.validationResults.isEmpty {
                        validationPanel
                    }

                    // ── ParsedResume Fields ──
                    if let parsed = debugVM.parsedResume {
                        parsedResumeCard(parsed)
                    }
                }
                .padding()
            }
            .navigationTitle("Pipeline Debugger")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    // MARK: - Current State Card

    private var currentStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Current Step", systemImage: "gauge.with.dots.needle.bottom.50percent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: stepIcon)
                    .font(.title2)
                    .foregroundStyle(stepColor)

                Text(debugVM.pipelineStep.displayName)
                    .font(.headline.monospacedDigit())

                Spacer()

                if debugVM.pipelineStep.isActive {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
#else
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
#endif
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Parse Only — the recommended test path (no Firebase needed)
            Button {
                Task { await debugVM.runParseOnly() }
            } label: {
                Label("Run Parse Only (No Firebase)", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(debugVM.pipelineStep.isActive)

            // Full Pipeline — will fail at upload without Firebase
            Button {
                debugVM.runFullPipeline()
            } label: {
                Label("Run Full Pipeline (Needs Firebase)", systemImage: "play.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(debugVM.pipelineStep.isActive)

            // Reset
            Button {
                debugVM.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    // MARK: - Debug Log Panel

    private var debugLogPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Live Debug Log", systemImage: "list.bullet.rectangle.portrait")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(debugVM.logEntries.count) entries")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            if debugVM.logEntries.isEmpty {
                Text("No log entries yet — tap a button above to start.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            logRows
                        }
                        .padding(10)
#if os(iOS)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
#else
                        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
#endif
                    }
                    .frame(maxHeight: 260)
                    .onChange(of: debugVM.logEntries.count) {
                        // Auto-scroll to latest entry
                        if let lastID = debugVM.logEntries.last?.id {
                            withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
#else
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
#endif
    }

    /// Index-based log rows to avoid ForEach overload ambiguity.
    private var logRows: some View {
        let entries = debugVM.logEntries
        return Group {
            ForEach(0..<entries.count, id: \.self) { index in
                logRow(entries[index])
            }
        }
    }

    private func logRow(_ entry: DebugLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 55, alignment: .leading)

            Text(entry.step)
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(entry.isError ? .red : .blue)
                .frame(width: 72, alignment: .leading)

            Text(entry.message)
                .font(.caption2)
                .foregroundStyle(entry.isError ? Color.red : Color.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Validation Panel

    private var validationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Field Validation", systemImage: "checkmark.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if debugVM.allValidationPassed {
                    Label("All Passed", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Label("Mismatch", systemImage: "xmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            validationRows
                .padding(10)
#if os(iOS)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
#else
                .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
#endif
        }
        .padding()
#if os(iOS)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
#else
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
#endif
    }

    /// Index-based validation rows to avoid ForEach overload ambiguity with [FieldValidation].
    private var validationRows: some View {
        let results = debugVM.validationResults
        return Group {
            ForEach(0..<results.count, id: \.self) { index in
                validationRow(results[index])
            }
        }
    }

    private func validationRow(_ v: FieldValidation) -> some View {
        HStack {
            Image(systemName: v.passed ? "checkmark.circle" : "xmark.circle")
                .font(.caption2)
                .foregroundStyle(v.passed ? .green : .red)
            Text(v.field)
                .font(.caption2.weight(.semibold))
                .frame(width: 60, alignment: .leading)
            Text(v.actual.isEmpty ? "— (empty)" : v.actual)
                .font(.caption2)
                .foregroundStyle(v.passed ? Color.primary : Color.red)
                .lineLimit(1)
        }
    }

    // MARK: - ParsedResume Fields Card

    private func parsedResumeCard(_ parsed: ParsedResume) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Parsed Resume Fields", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Name").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.name).font(.caption2.weight(.medium))
                }
                GridRow {
                    Text("Email").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.email).font(.caption2.weight(.medium))
                }
                GridRow {
                    Text("Phone").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.phone).font(.caption2.weight(.medium))
                }
                GridRow {
                    Text("Domain").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.domain).font(.caption2.weight(.medium))
                }
                GridRow {
                    Text("Exp").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.experience).font(.caption2.weight(.medium))
                }
                GridRow {
                    Text("Portfolio").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.portfolioLink).font(.caption2.weight(.medium)).lineLimit(1)
                }
                GridRow {
                    Text("Skills").font(.caption2).foregroundStyle(.secondary)
                    Text(parsed.skills.joined(separator: ", "))
                        .font(.caption2.weight(.medium))
                }
            }
            .padding(10)
#if os(iOS)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
#else
            .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
#endif
        }
        .padding()
#if os(iOS)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
#else
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
#endif
    }

    // MARK: - Step Helpers

    private var stepIcon: String {
        switch debugVM.pipelineStep {
        case .idle:     return "circle.dashed"
        case .uploading: return "square.and.arrow.up"
        case .extracting: return "doc.text"
        case .parsing:   return "sparkles"
        case .saving:    return "checkmark.circle"
        case .preview:   return "eye"
        case .done:      return "checkmark.seal"
        case .failed:    return "exclamationmark.triangle"
        }
    }

    private var stepColor: Color {
        switch debugVM.pipelineStep {
        case .idle:     return .gray
        case .uploading, .extracting, .parsing, .saving: return .blue
        case .preview:  return .green
        case .done:      return .green
        case .failed:    return .red
        }
    }
}

// MARK: - Preview

#Preview {
    PipelineDebugView()
}
