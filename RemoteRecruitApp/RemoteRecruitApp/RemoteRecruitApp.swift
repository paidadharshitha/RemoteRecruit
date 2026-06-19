//
//  RemoteRecruitApp.swift
//  RemoteRecruitApp
//
//  Created by RemoteRecruit
//

import SwiftUI
import RemoteRecruit
import Firebase

@main
struct RemoteRecruitApp: App {

    @StateObject private var authManager = AuthManager()
    private let container: DIContainer

    init() {
        FirebaseApp.configure()

        let jobService: JobServiceProtocol = MockJobService()
        let aiService: AIServiceProtocol = Self.makeAIService()
        container = DIContainer(jobService: jobService, aiService: aiService)
    }

    var body: some Scene {
            WindowGroup {
                RootView(container: container)
            }
    }

    // MARK: - Service Factory

    /// Reads the Gemini API key from Config.plist and returns a live or mock AI service.
    private static func makeAIService() -> AIServiceProtocol {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let config = NSDictionary(contentsOf: url) as? [String: Any],
              let apiKey = config["GeminiAPIKey"] as? String,
              !apiKey.isEmpty,
              apiKey != "YOUR_GEMINI_API_KEY_HERE"
        else {
            return MockAIService()
        }
        return GeminiAIService(apiKey: apiKey)
    }
}
