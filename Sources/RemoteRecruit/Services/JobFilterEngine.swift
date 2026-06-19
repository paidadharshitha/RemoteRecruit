// JobFilterEngine.swift
// RemoteRecruit

import Foundation

// MARK: - Job Filter Engine

/// Centralised, switch-based mapping engine that translates an `AcademicDomain`
/// × `ExperienceStatus` combination into a list of eligible role titles.
///
/// Usage:
///   ```swift
///   let roles = JobFilterEngine.getEligibleRoles(
///       for: .computerScience,
///       status: .student
///   )
///   // roles == ["Software Developer Intern", "Data Engineering Intern", …]
///   ```
///
/// Extensibility: add a new `AcademicDiscipline` / `ExperienceLevel` case,
/// then add the corresponding `switch` arms below.
public enum JobFilterEngine {

    // MARK: - Public API

    /// Returns the human-readable role names a user with the given domain
    /// and experience status is eligible for.
    ///
    /// - Parameters:
    ///   - domain: The academic branch (CS, ECE, EEE, Mechanical).
    ///   - status: Whether the user is a Student, Fresher, or Experienced.
    /// - Returns: An array of role-title strings.
    public static func getEligibleRoles(
        for domain: AcademicDiscipline,
        status: ExperienceLevel
    ) -> [String] {
        switch (domain, status) {
        // ── CS ──────────────────────────────
        case (.computerScience, .student):
            return [
                "Software Development Intern",
                "Data Engineering Intern",
                "Web Development Intern",
                "AI / ML Research Intern"
            ]
        case (.computerScience, .fresher):
            return [
                "Junior Software Developer",
                "Junior Data Engineer",
                "Entry-Level Web Developer",
                "Entry-Level AI Engineer"
            ]
        case (.computerScience, .experienced):
            return [
                "Senior Software Engineer",
                "Senior Data Engineer",
                "Senior Web Developer",
                "Senior AI Specialist"
            ]

        // ── ECE ─────────────────────────────
        case (.electronicsAndCommunication, .student):
            return [
                "Embedded Systems Intern",
                "VLSI Design Intern",
                "Firmware Development Intern"
            ]
        case (.electronicsAndCommunication, .fresher):
            return [
                "Junior Embedded Engineer",
                "Junior VLSI Engineer",
                "Entry-Level Firmware Developer"
            ]
        case (.electronicsAndCommunication, .experienced):
            return [
                "Senior Embedded Engineer",
                "Senior VLSI Engineer",
                "Senior Firmware Developer"
            ]

        // ── EEE ─────────────────────────────
        case (.electricalAndElectronics, .student):
            return [
                "Power Systems Intern",
                "Control Systems Intern",
                "Electrical Design Intern"
            ]
        case (.electricalAndElectronics, .fresher):
            return [
                "Junior Power Systems Engineer",
                "Junior Control Engineer",
                "Entry-Level Electrical Designer"
            ]
        case (.electricalAndElectronics, .experienced):
            return [
                "Senior Power Systems Engineer",
                "Senior Control Engineer",
                "Senior Electrical Designer"
            ]

        // ── Mechanical ──────────────────────
        case (.mechanical, .student):
            return [
                "CAD Design Intern",
                "Product Design Intern",
                "Thermal Engineering Intern"
            ]
        case (.mechanical, .fresher):
            return [
                "Junior CAD Designer",
                "Entry-Level Product Design Engineer",
                "Junior Thermal Engineer"
            ]
        case (.mechanical, .experienced):
            return [
                "Senior CAD Designer",
                "Senior Product Design Engineer",
                "Senior Thermal Engineer"
            ]
        }
    }

    // MARK: - Convenience

    /// Returns the mapped `JobDomain` cases for a given domain × status.
    /// Useful when the caller needs enum values instead of display strings.
    public static func getEligibleDomains(
        for domain: AcademicDiscipline,
        status: ExperienceLevel
    ) -> [JobDomain] {
        domain.mappedRoles
    }
}
