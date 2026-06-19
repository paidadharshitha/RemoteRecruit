// UserProfile.swift
// RemoteRecruit

import Foundation

// MARK: - User Profile

/// Represents a user's profile data stored in Firestore.
public struct UserProfile: Codable, Equatable, Sendable {

    // MARK: - Fields

    /// The user's display / full name.
    public var name: String

    /// The associated Firebase Auth UID.
    public var userId: String

    /// The user's email address.
    public var email: String

    /// College or university name (optional).
    public var college: String

    /// Phone number (optional).
    public var phone: String

    /// Current job domain preference.
    public var domain: String

    /// Career experience level.
    public var experienceLevel: String

    /// Year of study for students (e.g. 1, 2, 3, 4).
    public var yearOfStudy: Int?

    /// Number of years of professional experience (for experienced users).
    public var yearsOfExperience: Int?

    /// Download URL for the user's uploaded resume (optional).
    public var resumeURL: String?

    /// User's technical skills (e.g. ["Swift", "SwiftUI", "Core Data"]).
    public var skills: [String]

    /// Structured projects extracted from the resume or added manually.
    public var projects: [Project]

    /// Structured work experience entries extracted from the resume or added manually.
    public var workExperience: [WorkExperience]

    /// Link to the user's portfolio / personal website (optional).
    public var portfolioLink: String

    /// Batch / graduation year (e.g., 2026).
    public var batchYear: Int?

    /// Academic branch (CSE, ECE, EEE, Mechanical).
    public var academicBranch: AcademicDomain?

    /// Preferred technical roles for job filtering (multi-select, e.g., [Frontend, Backend]).
    public var preferredRoles: [TechnicalRole]

    // MARK: - Init

    public init(
        name: String = "",
        userId: String = "",
        email: String = "",
        college: String = "",
        phone: String = "",
        domain: String = "",
        experienceLevel: String = "",
        yearOfStudy: Int? = nil,
        yearsOfExperience: Int? = nil,
        resumeURL: String? = nil,
        skills: [String] = [],
        projects: [Project] = [],
        workExperience: [WorkExperience] = [],
        portfolioLink: String = "",
        batchYear: Int? = nil,
        academicBranch: AcademicDomain? = nil,
        preferredRoles: [TechnicalRole] = []
    ) {
        self.name = name
        self.userId = userId
        self.email = email
        self.college = college
        self.phone = phone
        self.domain = domain
        self.experienceLevel = experienceLevel
        self.yearOfStudy = yearOfStudy
        self.yearsOfExperience = yearsOfExperience
        self.resumeURL = resumeURL
        self.skills = skills
        self.projects = projects
        self.workExperience = workExperience
        self.portfolioLink = portfolioLink
        self.batchYear = batchYear
        self.academicBranch = academicBranch
        self.preferredRoles = preferredRoles
    }

    // MARK: - Codable (backward-compatible)

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.college = (try? c.decode(String.self, forKey: .college)) ?? ""
        self.phone = (try? c.decode(String.self, forKey: .phone)) ?? ""
        self.domain = (try? c.decode(String.self, forKey: .domain)) ?? ""
        self.experienceLevel = (try? c.decode(String.self, forKey: .experienceLevel)) ?? ""
        self.yearOfStudy = try? c.decode(Int.self, forKey: .yearOfStudy)
        self.yearsOfExperience = try? c.decode(Int.self, forKey: .yearsOfExperience)
        self.resumeURL = try? c.decode(String.self, forKey: .resumeURL)
        self.skills = (try? c.decode([String].self, forKey: .skills)) ?? []
        self.projects = (try? c.decode([Project].self, forKey: .projects)) ?? []
        self.workExperience = (try? c.decode([WorkExperience].self, forKey: .workExperience)) ?? []
        self.portfolioLink = (try? c.decode(String.self, forKey: .portfolioLink)) ?? ""
        self.batchYear = try? c.decode(Int.self, forKey: .batchYear)
        self.academicBranch = try? c.decode(AcademicDomain.self, forKey: .academicBranch)
        self.preferredRoles = (try? c.decode([TechnicalRole].self, forKey: .preferredRoles)) ?? []
    }
}
