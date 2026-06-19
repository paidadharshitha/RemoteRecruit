// ResumeOptimizerResult.swift
// RemoteRecruit

import Foundation

// MARK: - Optimized Resume Section Models

/// A single optimized work experience entry.
public struct OptimizedExperienceSection: Codable, Equatable, Sendable, Identifiable {

    public var id: String
    public let company: String
    public let role: String
    public let duration: String
    public let bullets: [String]

    public init(
        id: String = UUID().uuidString,
        company: String,
        role: String,
        duration: String,
        bullets: [String]
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.duration = duration
        self.bullets = bullets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.company = (try? container.decode(String.self, forKey: .company)) ?? ""
        self.role = (try? container.decode(String.self, forKey: .role)) ?? ""
        self.duration = (try? container.decode(String.self, forKey: .duration)) ?? ""
        self.bullets = (try? container.decode([String].self, forKey: .bullets)) ?? []
    }
}

/// A single optimized project entry.
public struct OptimizedProjectSection: Codable, Equatable, Sendable, Identifiable {

    public var id: String
    public let title: String
    public let duration: String
    public let technologies: [String]
    public let bullets: [String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        duration: String,
        technologies: [String],
        bullets: [String]
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.technologies = technologies
        self.bullets = bullets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.duration = (try? container.decode(String.self, forKey: .duration)) ?? ""
        self.technologies = (try? container.decode([String].self, forKey: .technologies)) ?? []
        self.bullets = (try? container.decode([String].self, forKey: .bullets)) ?? []
    }
}

/// The full optimized resume with professional sections.
public struct OptimizedResume: Codable, Equatable, Sendable {

    public let name: String
    public let summary: String
    public let skills: [String]
    public let experience: [OptimizedExperienceSection]
    public let projects: [OptimizedProjectSection]

    public init(
        name: String,
        summary: String,
        skills: [String],
        experience: [OptimizedExperienceSection],
        projects: [OptimizedProjectSection]
    ) {
        self.name = name
        self.summary = summary
        self.skills = skills
        self.experience = experience
        self.projects = projects
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        self.skills = (try? container.decode([String].self, forKey: .skills)) ?? []
        self.experience = (try? container.decode([OptimizedExperienceSection].self, forKey: .experience)) ?? []
        self.projects = (try? container.decode([OptimizedProjectSection].self, forKey: .projects)) ?? []
    }
}

// MARK: - AI Changes Tracker

/// Describes modifications the AI made to each resume section.
public struct AIChanges: Codable, Equatable, Sendable {

    /// Skills/keywords added that were missing from the original resume.
    public let keywordsAdded: [String]

    /// Skills/keywords that were rephrased or replaced.
    public let keywordsReplaced: [String]

    /// Brief description of changes per section.
    public let sectionChanges: [SectionChange]

    public init(
        keywordsAdded: [String],
        keywordsReplaced: [String],
        sectionChanges: [SectionChange]
    ) {
        self.keywordsAdded = keywordsAdded
        self.keywordsReplaced = keywordsReplaced
        self.sectionChanges = sectionChanges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keywordsAdded = (try? container.decode([String].self, forKey: .keywordsAdded)) ?? []
        self.keywordsReplaced = (try? container.decode([String].self, forKey: .keywordsReplaced)) ?? []
        self.sectionChanges = (try? container.decode([SectionChange].self, forKey: .sectionChanges)) ?? []
    }
}

/// A single section-level change description.
public struct SectionChange: Codable, Equatable, Sendable, Identifiable {

    public var id: String
    public let section: String
    public let description: String

    public init(
        id: String = UUID().uuidString,
        section: String,
        description: String
    ) {
        self.id = id
        self.section = section
        self.description = description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.section = (try? container.decode(String.self, forKey: .section)) ?? ""
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
    }
}

// MARK: - Resume Optimizer Result

/// Complete result from the AI Resume Optimizer: ATS score, gaps, and optimized resume.
public struct ResumeOptimizerResult: Codable, Equatable, Sendable {

    /// ATS compatibility score (0-100).
    public let atsScore: Int

    /// Important keywords missing from the resume that the JD expects.
    public let missingKeywords: [String]

    /// Specific skill mismatches between resume and JD.
    public let skillGaps: [String]

    /// Experience-level gaps identified (e.g. missing leadership, quantifiable achievements).
    public let experienceGaps: [String]

    /// Actionable improvement suggestions.
    public let suggestions: [String]

    /// The AI-generated optimized resume tailored to the JD.
    public let optimizedResume: OptimizedResume

    /// Transparent record of changes the AI made.
    public let aiChanges: AIChanges

    /// Human-readable explanation of what the AI optimized and why.
    public let aiExplanation: String

    public init(
        atsScore: Int,
        missingKeywords: [String],
        skillGaps: [String],
        experienceGaps: [String],
        suggestions: [String],
        optimizedResume: OptimizedResume,
        aiChanges: AIChanges = AIChanges(keywordsAdded: [], keywordsReplaced: [], sectionChanges: []),
        aiExplanation: String = ""
    ) {
        self.atsScore = atsScore
        self.missingKeywords = missingKeywords
        self.skillGaps = skillGaps
        self.experienceGaps = experienceGaps
        self.suggestions = suggestions
        self.optimizedResume = optimizedResume
        self.aiChanges = aiChanges
        self.aiExplanation = aiExplanation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.atsScore = (try? container.decode(Int.self, forKey: .atsScore)) ?? 0
        self.missingKeywords = (try? container.decode([String].self, forKey: .missingKeywords)) ?? []
        self.skillGaps = (try? container.decode([String].self, forKey: .skillGaps)) ?? []
        self.experienceGaps = (try? container.decode([String].self, forKey: .experienceGaps)) ?? []
        self.suggestions = (try? container.decode([String].self, forKey: .suggestions)) ?? []
        self.optimizedResume = (try? container.decode(OptimizedResume.self, forKey: .optimizedResume)) ?? OptimizedResume(
            name: "",
            summary: "",
            skills: [],
            experience: [],
            projects: []
        )
        self.aiChanges = (try? container.decode(AIChanges.self, forKey: .aiChanges)) ?? AIChanges(
            keywordsAdded: [],
            keywordsReplaced: [],
            sectionChanges: []
        )
        self.aiExplanation = (try? container.decode(String.self, forKey: .aiExplanation)) ?? ""
    }
}
