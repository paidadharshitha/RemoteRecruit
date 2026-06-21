// AdvancedFilterService.swift
// RemoteRecruit

import Foundation

// MARK: - Protocol

public protocol AdvancedFiltering: Sendable {
    /// Applies the given advanced filter to a list of jobs.
    func applyFilter(jobs: [Job], filter: AdvancedJobFilter) -> [Job]
}

// MARK: - Implementation

public struct AdvancedFilterService: AdvancedFiltering {

    public init() {}

    // MARK: - Public API

    public func applyFilter(jobs: [Job], filter: AdvancedJobFilter) -> [Job] {
        guard filter.isActive else { return jobs }

        var result = jobs

        // 1. Experience filter
        if !filter.experienceFilters.isEmpty {
            let targetLevels = filter.experienceFilters.map { $0.experienceLevel }
            result = result.filter { targetLevels.contains($0.experienceLevel) }
        }

        // 2. Work type filter (OR: job must match at least one selected work type)
        if !filter.workTypeFilters.isEmpty {
            result = result.filter { job in
                filter.workTypeFilters.contains { workType in
                    workType.matches(job: job)
                }
            }
        }

        // 3. Salary filter (OR: job must match at least one selected salary range)
        if !filter.salaryFilters.isEmpty {
            result = result.filter { job in
                filter.salaryFilters.contains { salaryRange in
                    matchesSalary(job: job, range: salaryRange)
                }
            }
        }

        return result
    }

    // MARK: - Private

    /// Parses numeric values from a salary string and checks against a salary range.
    /// Handles formats like "$70k", "$100k – $150k", "$25/hr", "₹5–10 LPA".
    private func matchesSalary(job: Job, range: SalaryRange) -> Bool {
        let salaryText = job.salaryRange.lowercased()
        let numbers = parseNumbers(from: salaryText)

        guard let minSalary = numbers.min(), let maxSalary = numbers.max() else {
            // No parseable numbers — match only if range covers 0+
            return range.minValue == 0
        }

        // Check overlap between job salary range and filter range
        let filterMin = range.minValue
        let filterMax = range.maxValue ?? Int.max

        return minSalary <= filterMax && maxSalary >= filterMin
    }

    /// Extracts numeric values (in thousands) from a salary string.
    /// E.g., "$70k" → 70000, "$100k – $150k" → [100000, 150000], "$25/hr" → 25
    private func parseNumbers(from text: String) -> [Int] {
        // Handle "k" suffix (thousands)
        let kMatches = text.matches(of: #/(\d+)[\s]*k/#).compactMap { match in
            Int(match.output.1)
        }.map { $0 * 1000 }

        // Handle "lpa" suffix (lakhs)
        let lpaMatches = text.matches(of: #/(\d+)[\s]*(?:lpa|lakh)/#).compactMap { match in
            Int(match.output.1)
        }.map { $0 * 100000 }

        // Handle plain numbers (e.g., hourly rates)
        let plainMatches = text.matches(of: #/\$(\d+)/#).compactMap { match in
            Int(match.output.1)
        }

        // If numbers have "k" or "lpa" suffix, prefer those
        if !kMatches.isEmpty { return kMatches }
        if !lpaMatches.isEmpty { return lpaMatches }
        return plainMatches
    }
}
