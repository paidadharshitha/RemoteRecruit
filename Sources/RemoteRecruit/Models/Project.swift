// Project.swift
// RemoteRecruit

import Foundation

/// Represents a single project from a user's resume or manually added entry.
public struct Project: Codable, Equatable, Sendable, Identifiable {

    public var id: String
    public var title: String
    public var description: String
    public var technologies: [String]
    public var role: String
    public var duration: String

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        description: String = "",
        technologies: [String] = [],
        role: String = "",
        duration: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.technologies = technologies
        self.role = role
        self.duration = duration
    }

    // Backward-compatible decoder — missing keys default to empty values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
        self.technologies = (try? container.decode([String].self, forKey: .technologies)) ?? []
        self.role = (try? container.decode(String.self, forKey: .role)) ?? ""
        self.duration = (try? container.decode(String.self, forKey: .duration)) ?? ""
    }
}
