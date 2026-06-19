// ResumeOptimizerViewModel.swift
// RemoteRecruit

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Resume Source

/// How the resume content was provided.
public enum ResumeSource: Equatable {
    case pastedText
    case fileUpload(fileName: String)
}

// MARK: - File Extraction State

/// Tracks the file extraction progress shown during upload.
public enum FileExtractionState: Equatable {
    case idle
    case extracting
    case success
    case error(message: String)
}

// MARK: - PDF Export State

public enum PDFExportState: Equatable {
    case idle
    case generating
    case success(url: URL)
    case error(message: String)
}

// MARK: - Resume Optimizer ViewModel

@MainActor
public final class ResumeOptimizerViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) public var viewState: ViewState<ResumeOptimizerResult> = .idle
    @Published public var resumeText: String = ""
    @Published public var jobDescription: String = ""
    @Published public var resumeSource: ResumeSource = .pastedText
    @Published private(set) public var pdfExportState: PDFExportState = .idle
    @Published public var showFileImporter = false
    @Published private(set) public var extractionState: FileExtractionState = .idle

    /// Whether a network/API error alert should be shown.
    @Published public var showAlert = false
    @Published public var alertMessage = ""

    // MARK: - Dependencies

    private let service: AIServiceProtocol

    // MARK: - Init

    public init(service: AIServiceProtocol) {
        self.service = service
    }

    // MARK: - Input Validation

    /// Whether both inputs have minimum required content.
    public var isFormValid: Bool {
        let trimmedResume = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedJD = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedResume.count >= 20 && trimmedJD.count >= 20
    }

    // MARK: - Analysis

    /// Validates inputs and runs the JD-aware AI analysis pipeline.
    public func analyzeResume() async {
        let trimmedResume = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedJD = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedResume.count >= 20 else {
            presentError("Please provide at least 20 characters of resume text.")
            return
        }
        guard trimmedJD.count >= 20 else {
            presentError("Please provide at least 20 characters of job description.")
            return
        }
        guard !viewState.isLoading else { return }

        viewState = .loading
        pdfExportState = .idle

        do {
            let result = try await service.analyzeResume(
                resumeText: trimmedResume,
                jobDescription: trimmedJD
            )
            viewState = .success(data: result)
        } catch let error as AIServiceError {
            presentError(error.localizedDescription)
        } catch let urlError as URLError {
            presentError(categorizedNetworkError(urlError))
        } catch {
            presentError("An unexpected error occurred. Please try again.")
        }
    }

    // MARK: - PDF Export

    /// Generates a PDF from the optimized resume and returns the temp file URL.
    public func exportPDF() {
        guard case .success(let result) = viewState else { return }
        pdfExportState = .generating

        let resume = result.optimizedResume

        // Run PDF generation on a background thread to avoid blocking UI
        Task.detached {
            let pdfData = PDFGenerator.generatePDF(from: resume)

            await MainActor.run {
                guard let data = pdfData else {
                    self.pdfExportState = .error(message: "Failed to generate PDF.")
                    return
                }

                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "\(resume.name.replacingOccurrences(of: " ", with: "_"))_Optimized_Resume.pdf"
                let fileURL = tempDir.appendingPathComponent(fileName)

                do {
                    try data.write(to: fileURL, options: .atomic)
                    self.pdfExportState = .success(url: fileURL)
                } catch {
                    self.pdfExportState = .error(message: "Failed to save PDF: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - File Handling

    /// Processes an uploaded file and extracts text from PDF, DOCX, or plain text.
    public func handleUploadedFile(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await processFileAsync(at: url) }

        case .failure(let error):
            presentError("File import failed: \(error.localizedDescription)")
        }
    }

    /// Reads and extracts text from a file URL asynchronously to avoid blocking.
    private func processFileAsync(at url: URL) async {
        extractionState = .extracting
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        // Access the file on a background thread
        let extractedText: String = await Task.detached {
            guard let data = try? Data(contentsOf: url) else {
                return ""
            }
            switch ext {
            case "pdf":
                return PDFTextExtractor.extractText(from: data)
            case "docx":
                return PDFTextExtractor.extractTextFromDOCX(from: data)
            default:
                return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
        }.value

        if extractedText.isEmpty {
            extractionState = .error(message: "Could not extract text. Please paste your resume manually.")
        } else {
            resumeText = extractedText
            resumeSource = .fileUpload(fileName: fileName)
            extractionState = .success
        }
    }

    // MARK: - Job-to-Resume Flow

    /// Pre-fills the job description field (called from JobDetailView navigation).
    public func preFillJobDescription(_ jd: String) {
        guard jobDescription.isEmpty else { return }
        jobDescription = jd
    }

    // MARK: - Reset

    /// Resets all state for a fresh analysis.
    public func reset() {
        resumeText = ""
        jobDescription = ""
        resumeSource = .pastedText
        viewState = .idle
        pdfExportState = .idle
        extractionState = .idle
        showAlert = false
        alertMessage = ""
    }

    // MARK: - Error Presentation

    /// Sets the alert state so the view can show a clean error alert.
    private func presentError(_ message: String) {
        viewState = .error(message: message)
        showAlert = true
        alertMessage = message
    }

    /// Dismisses the error alert.
    public func dismissAlert() {
        showAlert = false
        alertMessage = ""
    }

    // MARK: - Error Categorization

    /// Maps URLError codes to user-friendly error messages.
    private func categorizedNetworkError(_ error: URLError) -> String {
        switch error.code {
        case .timedOut:
            return "The request timed out. Please check your connection and try again."
        case .notConnectedToInternet, .networkConnectionLost:
            return "No internet connection. Please check your network and retry."
        case .cannotConnectToHost, .dnsLookupFailed:
            return "Unable to reach the server. Please check your connection or try again later."
        case .secureConnectionFailed:
            return "Secure connection failed. Please try again later."
        case .httpTooManyRedirects:
            return "Network error — too many redirects. Please try again."
        case .resourceUnavailable, .cancelled:
            return "The request was cancelled. Please try again."
        default:
            return "Network error: \(error.localizedDescription)"
        }
    }
}
