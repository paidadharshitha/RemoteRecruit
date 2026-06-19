// WorkExperience.swift
// RemoteRecruit

import Foundation

/// Represents a single work experience entry from a user's resume.
public struct WorkExperience: Codable, Equatable, Sendable, Identifiable {

    public var id: String
    public var company: String
    public var role: String
    public var duration: String
    public var description: String

    public init(
        id: String = UUID().uuidString,
        company: String = "",
        role: String = "",
        duration: String = "",
        description: String = ""
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.duration = duration
        self.description = description
    }

    // Backward-compatible decoder — missing keys default to empty values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.company = (try? container.decode(String.self, forKey: .company)) ?? ""
        self.role = (try? container.decode(String.self, forKey: .role)) ?? ""
        self.duration = (try? container.decode(String.self, forKey: .duration)) ?? ""
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
    }
}
