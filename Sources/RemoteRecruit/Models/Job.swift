// Job.swift
// RemoteRecruit

import Foundation

struct Job: Codable, Hashable, Identifiable, Sendable {

    let id: UUID
    let title: String
    let companyName: String
    let location: String
    let salaryRange: String
    let jobDescription: String
    let tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        companyName: String,
        location: String,
        salaryRange: String,
        jobDescription: String,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.companyName = companyName
        self.location = location
        self.salaryRange = salaryRange
        self.jobDescription = jobDescription
        self.tags = tags
    }
}

// MARK: - Mock Data

enum MockData {
    static let sampleJobs: [Job] = [
        Job(
            title: "Senior iOS Engineer",
            companyName: "Stripe",
            location: "San Francisco, CA (Remote)",
            salaryRange: "$160k – $220k",
            jobDescription: "Design and build advanced applications for the iOS platform using Swift and SwiftUI. Collaborate with cross-functional teams to define and ship new features.",
            tags: ["iOS", "Swift", "SwiftUI", "Full-Time"]
        ),
        Job(
            title: "Backend Engineer",
            companyName: "Notion",
            location: "New York, NY (Remote)",
            salaryRange: "$150k – $200k",
            jobDescription: "Build scalable services that power Notion's collaboration platform. Work on API design, database optimization, and distributed systems.",
            tags: ["Backend", "Go", "Full-Time"]
        ),
        Job(
            title: "Product Designer",
            companyName: "Figma",
            location: "Seattle, WA (Remote)",
            salaryRange: "$130k – $180k",
            jobDescription: "Craft intuitive interfaces for our design tool. Work closely with engineering and product teams, conduct user research.",
            tags: ["Design", "UX/UI", "Full-Time"]
        ),
        Job(
            title: "Data Scientist",
            companyName: "Spotify",
            location: "Stockholm, Sweden (Remote)",
            salaryRange: "$120k – $170k",
            jobDescription: "Analyze large datasets to uncover insights that drive product decisions. Build recommendation systems.",
            tags: ["Data Science", "Python", "ML", "Full-Time"]
        ),
        Job(
            title: "DevOps Engineer",
            companyName: "HashiCorp",
            location: "Austin, TX (Remote)",
            salaryRange: "$140k – $190k",
            jobDescription: "Automate infrastructure, manage CI/CD pipelines, and ensure system reliability using Terraform and Kubernetes.",
            tags: ["DevOps", "Kubernetes", "Terraform", "Full-Time"]
        ),
        Job(
            title: "Frontend Engineer",
            companyName: "Vercel",
            location: "Remote (Worldwide)",
            salaryRange: "$130k – $175k",
            jobDescription: "Build performant web applications using React, Next.js, and modern web technologies.",
            tags: ["Frontend", "React", "Next.js", "Full-Time"]
        )
    ]
}
