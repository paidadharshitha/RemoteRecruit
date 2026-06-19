// StorageService.swift
// RemoteRecruit

import Foundation
import FirebaseStorage

// MARK: - Storage Service

/// Handles saving user resumes.
/// Uses local device storage (Documents directory) when Firebase Storage
/// is unavailable. Swap `useLocalStorage` to `false` after upgrading to Blaze.
@MainActor
public final class StorageService {

    // MARK: - Singleton

    public static let shared = StorageService()

    // MARK: - Configuration

    /// Set to `false` after upgrading Firebase to the Blaze plan and creating a Storage bucket.
    private let useLocalStorage = true

    // MARK: - Properties

    private let storage = Storage.storage()

    private init() {}

    // MARK: - Upload Resume

    /// Uploads resume data to Firebase Storage under `resumes/{userId}.pdf`,
    /// or saves locally when `useLocalStorage` is enabled.
    /// - Parameters:
    ///   - data: The raw file data (e.g., PDF bytes).
    ///   - userId: The Firebase Auth UID used as the storage path key.
    ///   - completion: Returns the download/local URL on success, or an error on failure.
    public func uploadResume(
        data: Data,
        userId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if useLocalStorage {
            saveResumeLocally(data: data, userId: userId, completion: completion)
        } else {
            uploadResumeToFirebase(data: data, userId: userId, completion: completion)
        }
    }

    // MARK: - Async Upload

    /// Async/await version of `uploadResume`. Prevents UI freezing by not requiring callbacks.
    /// - Parameters:
    ///   - data: The raw file data (e.g., PDF bytes).
    ///   - userId: The Firebase Auth UID used as the storage path key.
    /// - Returns: The download/local URL string on success.
    public func uploadResumeAsync(data: Data, userId: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            uploadResume(data: data, userId: userId) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Local Storage

    /// Saves the resume PDF to the app's Documents directory.
    /// The returned URL is a local `file://` path, which is sufficient for
    /// the parsing pipeline (PDFKit only needs `Data`).
    private func saveResumeLocally(
        data: Data,
        userId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        do {
            let directory = try createResumesDirectoryIfNeeded()
            let fileURL = directory.appendingPathComponent("\(userId).pdf")
            try data.write(to: fileURL, options: .atomic)
            completion(.success(fileURL.absoluteString))
        } catch {
            completion(.failure(StorageServiceError.localWriteFailed(error.localizedDescription)))
        }
    }

    /// Ensures the `Resumes/` subdirectory exists in Documents.
    private func createResumesDirectoryIfNeeded() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let resumesDir = documents.appendingPathComponent("Resumes", isDirectory: true)
        try FileManager.default.createDirectory(at: resumesDir, withIntermediateDirectories: true)
        return resumesDir
    }

    // MARK: - Firebase Storage Upload

    /// Uploads resume data to Firebase Storage under `resumes/{userId}.pdf`.
    private func uploadResumeToFirebase(
        data: Data,
        userId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let ref = storage.reference().child("resumes/\(userId).pdf")

        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"

        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                let firebaseError = self.classifyUploadError(error)
                completion(.failure(firebaseError))
                return
            }

            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let downloadURL = url else {
                    completion(.failure(StorageServiceError.downloadURLUnavailable))
                    return
                }
                completion(.success(downloadURL.absoluteString))
            }
        }
    }

    // MARK: - Error Classification

    /// Translates raw Firebase Storage errors into human-readable messages.
    private func classifyUploadError(_ error: Error) -> Error {
        let nsError = error as NSError
        let domain = nsError.domain
        let code = nsError.code

        // Firebase Storage uses its own error domain
        if domain == StorageErrorDomain {
            switch code {
            case StorageErrorCode.bucketNotFound.rawValue:
                return StorageServiceError.bucketNotFound
            case StorageErrorCode.unauthorized.rawValue:
                return StorageServiceError.unauthorized
            case StorageErrorCode.objectNotFound.rawValue:
                // Firebase returns this when the bucket doesn't exist yet,
                // or the path is unreachable due to rules.
                return StorageServiceError.bucketNotFound
            case StorageErrorCode.quotaExceeded.rawValue:
                return StorageServiceError.quotaExceeded
            case StorageErrorCode.unauthenticated.rawValue:
                return StorageServiceError.unauthenticated
            case StorageErrorCode.retryLimitExceeded.rawValue:
                return StorageServiceError.networkError("Upload timed out. Check your connection and try again.")
            default:
                return StorageServiceError.uploadFailed(error.localizedDescription)
            }
        }

        // Network-level errors
        if domain == NSURLErrorDomain {
            return StorageServiceError.networkError("Network error: \(error.localizedDescription)")
        }

        // Fallback
        return StorageServiceError.uploadFailed(error.localizedDescription)
    }

    // MARK: - Secure Copy from Document Picker

    /// Copies a security-scoped file (from `UIDocumentPickerViewController` / `.fileImporter`)
    /// into the app's `Documents/Resumes/` directory so it persists across launches.
    ///
    /// - Parameter pickerURL: The temporary, security-scoped URL returned by the document picker.
    /// - Returns: The persistent local `file://` URL inside the app's sandbox, or throws on failure.
    public static func secureCopyResumeFromPicker(_ pickerURL: URL) throws -> URL {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StorageServiceError.localWriteFailed("Could not locate Documents directory.")
        }
        let resumesDir = documents.appendingPathComponent("Resumes", isDirectory: true)
        try fm.createDirectory(at: resumesDir, withIntermediateDirectories: true)

        let originalFilename = pickerURL.lastPathComponent
        let ext = pickerURL.pathExtension
        let baseName = ext.isEmpty ? originalFilename :
            String(originalFilename.dropLast(ext.count + 1))

        // Resolve a unique destination to avoid collisions
        var destinationURL = resumesDir.appendingPathComponent(originalFilename)
        if fm.fileExists(atPath: destinationURL.path) {
            var counter = 1
            repeat {
                let name = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
                destinationURL = resumesDir.appendingPathComponent(name)
                counter += 1
            } while fm.fileExists(atPath: destinationURL.path)
        }

        // Perform the copy (remove any previous file at that path first)
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.copyItem(at: pickerURL, to: destinationURL)

        // Verify the copy succeeded
        guard fm.fileExists(atPath: destinationURL.path) else {
            throw StorageServiceError.localWriteFailed(
                "File copy verification failed: expected file at \(destinationURL.path)"
            )
        }

        print("[StorageService] Secure copy complete: \(destinationURL.path)")
        return destinationURL
    }

    /// Reads raw data from a persistent local file URL after a secure copy.
    /// Returns the file data or throws a descriptive error.
    public static func readData(from localURL: URL) throws -> Data {
        let fm = FileManager.default
        guard fm.fileExists(atPath: localURL.path) else {
            throw StorageServiceError.localWriteFailed(
                "File does not exist at \(localURL.path)"
            )
        }
        return try Data(contentsOf: localURL)
    }
}

// MARK: - Resume Path Resolver

/// Centralized utility for resolving a stored `resumeURL` string into a validated local path.
/// Handles `file://` (local), `gs://` / `https://` (Firebase), and malformed URLs.
public enum ResumePathResult: Equatable {
    /// The file exists at the resolved local path.
    case found(localPath: String)
    /// A local `file://` URL that does not point to an existing file.
    case notFound(resolvedPath: String, rawURL: String)
    /// The URL is remote (Firebase/HTTPS) — no local file check performed.
    case remote(urlString: String)
    /// The string is empty, nil, or not a valid URL.
    case invalidFormat(raw: String)
}

public enum ResumePathResolver {

    /// Resolves a `resumeURL` string from Firestore into a validated result.
    ///
    /// - For `file://` URLs: decodes the path and checks `FileManager` for existence.
    /// - For `https://` / `gs://` URLs: treats as remote (no local check).
    /// - For empty/invalid strings: returns `.invalidFormat`.
    public static func resolve(_ urlString: String?) -> ResumePathResult {
        // Guard against nil / empty
        let raw = urlString ?? ""
        guard !raw.isEmpty else {
            print("[ResumePathResolver] resumeURL is nil or empty.")
            return .invalidFormat(raw: "")
        }

        // Attempt to parse as URL
        guard let url = URL(string: raw) else {
            print("[ResumePathResolver] Cannot parse as URL: \"\(raw)\"")
            return .invalidFormat(raw: raw)
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // Remote URLs (Firebase download URL or HTTPS) — pass through
        if scheme == "https" || scheme == "gs" {
            print("[ResumePathResolver] Remote URL detected, skipping local check: \(raw)")
            return .remote(urlString: raw)
        }

        // Local file:// URL — resolve to filesystem path
        if scheme == "file" {
            // Use standard URL path resolution
            let resolvedPath = url.path(percentEncoded: false)
            print("[ResumePathResolver] Resolved file:// path: \(resolvedPath)")
            print("[ResumePathResolver] Original URL string: \(raw)")
            print("[ResumePathResolver] URL.path(): \(url.path())")
            print("[ResumePathResolver] URL.path(percentEncoded: false): \(url.path(percentEncoded: false))")
            print("[ResumePathResolver] URL.lastPathComponent: \(url.lastPathComponent)")

            // Also try the alternative: extracting path after "file://"
            if let altPath = URL(string: raw)?.standardized.path {
                print("[ResumePathResolver] URL.standardized.path: \(altPath)")
            }

            let fm = FileManager.default
            let exists = fm.fileExists(atPath: resolvedPath)
            print("[ResumePathResolver] FileManager.fileExists(\"\(resolvedPath)\") = \(exists)")

            if exists {
                return .found(localPath: resolvedPath)
            } else {
                // Fallback: check if file exists with the lastPathComponent in Documents/Resumes/
                let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                if let documents,
                   let fallbackURL = documents.appendingPathComponent("Resumes/").appendingPathComponent(url.lastPathComponent).standardizedFileURL as URL?,
                   fm.fileExists(atPath: fallbackURL.path) {
                    print("[ResumePathResolver] Fallback found at Documents/Resumes/\(url.lastPathComponent)")
                    return .found(localPath: fallbackURL.path)
                }
                return .notFound(resolvedPath: resolvedPath, rawURL: raw)
            }
        }

        // Unknown scheme — treat as raw string
        print("[ResumePathResolver] Unknown URL scheme (\(scheme)) in: \(raw)")
        return .invalidFormat(raw: raw)
    }
}

// MARK: - Errors

public enum StorageServiceError: LocalizedError, Sendable {
    case downloadURLUnavailable
    case bucketNotFound
    case unauthorized
    case unauthenticated
    case quotaExceeded
    case networkError(String)
    case uploadFailed(String)
    case localWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .downloadURLUnavailable:
            return "Could not retrieve the download URL for the uploaded resume."
        case .bucketNotFound:
            return "Storage bucket not found. Open the Firebase Console → Storage and create a bucket, then ensure your GoogleService-Info.plist matches the project."
        case .unauthorized:
            return "Permission denied: your Firebase Storage rules block this upload. Check the rules in the Firebase Console."
        case .unauthenticated:
            return "Upload failed: you must be signed in before uploading a resume."
        case .quotaExceeded:
            return "Storage quota exceeded. Free plan limits may have been reached."
        case .networkError(let detail):
            return detail
        case .uploadFailed(let detail):
            return "Upload failed: \(detail)"
        case .localWriteFailed(let detail):
            return "Could not save resume locally: \(detail)"
        }
    }
}
