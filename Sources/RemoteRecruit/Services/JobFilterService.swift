// JobFilterService.swift
// RemoteRecruit

import Foundation

// MARK: - Protocol

public protocol JobFiltering: Sendable {
    func filterJobs(
        jobs: [Job],
        discipline: AcademicDiscipline,
        level: ExperienceLevel
    ) -> [Job]

    func filterJobsByRoles(
        jobs: [Job],
        preferredRoles: [TechnicalRole],
        academicBranch: AcademicDomain?,
        level: ExperienceLevel
    ) -> [Job]
}

// MARK: - Implementation

public struct JobFilterService: JobFiltering {

    public init() {}

    /// High-performance filter that matches jobs by discipline (mapped roles)
    /// and experience level. Uses a single-pass `.filter` to avoid UI lag.
    ///
    /// - Parameters:
    ///   - jobs: The full list of jobs to filter.
    ///   - discipline: The academic discipline whose mapped roles are used.
    ///   - level: The experience level to match.
    /// - Returns: A filtered array (may be empty).
    public func filterJobs(
        jobs: [Job],
        discipline: AcademicDiscipline,
        level: ExperienceLevel
    ) -> [Job] {
        let mappedDomains = discipline.mappedRoles

        return jobs.filter { job in
            mappedDomains.contains(job.domain) && job.experienceLevel == level
        }
    }

    /// Role-based filter: matches jobs by the user's preferred technical roles
    /// and experience level.
    ///
    /// - If `preferredRoles` is non-empty: jobs must match at least one selected role's
    ///   mapped `JobDomain` AND the given `experienceLevel`.
    /// - If `preferredRoles` is empty: falls back to filtering by `academicBranch`'s
    ///   mapped roles (shows all roles for that branch) + `experienceLevel`.
    ///
    /// - Parameters:
    ///   - jobs: The full list of jobs to filter.
    ///   - preferredRoles: The user's selected technical roles.
    ///   - academicBranch: The user's academic branch (used as fallback).
    ///   - level: The experience level to match (intern, fresher, experienced).
    /// - Returns: A filtered array (may be empty).
    public func filterJobsByRoles(
        jobs: [Job],
        preferredRoles: [TechnicalRole],
        academicBranch: AcademicDomain?,
        level: ExperienceLevel
    ) -> [Job] {
        let targetDomains: [JobDomain]

        if !preferredRoles.isEmpty {
            // Collect all JobDomains mapped from the selected TechnicalRoles
            var domains = Set<JobDomain>()
            for role in preferredRoles {
                domains.formUnion(role.mappedJobDomains)
            }
            targetDomains = Array(domains)
        } else if let branch = academicBranch {
            // No roles selected — show all jobs for the user's branch
            targetDomains = branch.mappedJobDomains
        } else {
            targetDomains = []
        }

        guard !targetDomains.isEmpty else { return jobs.filter { $0.experienceLevel == level } }

        return jobs.filter { job in
            targetDomains.contains(job.domain) && job.experienceLevel == level
        }
    }
}
