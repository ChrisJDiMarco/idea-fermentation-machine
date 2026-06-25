import Foundation

public enum AutonomousScout {
    public static func dueMissions(profile: AutonomyProfile, missions: [ScoutMission], now: Date = Date(), limit: Int = 3) -> [ScoutMission] {
        guard profile.isEnabled else { return [] }
        return missions
            .filter { $0.isEnabled }
            .filter { !matchesExcluded("\($0.title) \($0.query)", profile: profile) }
            .filter { mission in
                guard let lastRunAt = mission.lastRunAt else { return true }
                return Date(timeInterval: Double(max(1, mission.cadenceHours) * 60 * 60), since: lastRunAt) <= now
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func filterSignals(_ signals: [ScoutSignal], profile: AutonomyProfile) -> [ScoutSignal] {
        signals.filter { !matchesExcluded("\($0.title) \($0.summary) \($0.url ?? "")", profile: profile) }
    }

    public static func fallbackSignals(profile: AutonomyProfile, mission: ScoutMission) -> [ScoutSignal] {
        [
            ScoutSignal(
                title: "Scout brief: \(mission.query)",
                summary: """
                Mission: \(mission.query)
                Taste: \(profile.tasteNotes)
                Goals: \(profile.goals)
                Watch topics: \(profile.watchTopics)
                Preferred output: \(profile.preferredOutputs)
                """,
                kind: .note
            )
        ]
    }

    public static func draftIdea(profile: AutonomyProfile, mission: ScoutMission, signals: [ScoutSignal]) -> ExtractedSeed {
        let title = mission.title.isEmpty ? "Autonomous scout: \(mission.query)" : mission.title
        let signalLines = signals.prefix(5).map { signal in
            "- \(signal.title): \(signal.summary)"
        }.joined(separator: "\n")
        let body = """
        Autonomous scout mission: \(mission.query)

        Why this fits:
        \(profile.tasteNotes.isEmpty ? "Matches the active watchlist." : profile.tasteNotes)

        Signals:
        \(signalLines)

        Next step:
        Turn the strongest signal into a prototype brief and mockup prompt before spending build time.
        """
        return ExtractedSeed(title: title, body: body, tags: tags(from: profile, mission: mission))
    }

    public static func webSignals(for mission: ScoutMission, limit: Int = 4) async throws -> [ScoutSignal] {
        async let repos = githubSignals(for: mission.query, limit: max(1, limit / 2))
        async let stories = hackerNewsSignals(for: mission.query, limit: max(1, limit / 2))
        return try await Array((repos + stories).prefix(limit))
    }

    private static func tags(from profile: AutonomyProfile, mission: ScoutMission) -> [String] {
        let raw = "\(profile.watchTopics), \(mission.query)"
            .split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(raw)).sorted()
    }

    private static func matchesExcluded(_ text: String, profile: AutonomyProfile) -> Bool {
        let normalized = text.lowercased()
        return profile.excludedTopics
            .split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .contains { normalized.contains($0) }
    }

    private static func githubSignals(for query: String, limit: Int) async throws -> [ScoutSignal] {
        guard var components = URLComponents(string: "https://api.github.com/search/repositories") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "\(limit)")
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("IdeaFermentationMachine", forHTTPHeaderField: "User-Agent")
        let (data, httpResponse) = try await IFMNetworking.session.data(for: request)
        try validateScoutResponse(httpResponse, provider: "GitHub", data: data)
        let response = try JSONDecoder().decode(GitHubSearchResponse.self, from: data)
        return response.items.prefix(limit).map { repo in
            ScoutSignal(
                title: repo.fullName,
                summary: repo.description ?? "Recently updated repository matching \(query).",
                url: repo.htmlURL,
                kind: .link
            )
        }
    }

    private static func hackerNewsSignals(for query: String, limit: Int) async throws -> [ScoutSignal] {
        guard var components = URLComponents(string: "https://hn.algolia.com/api/v1/search_by_date") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "hitsPerPage", value: "\(limit)")
        ]
        guard let url = components.url else { return [] }
        let (data, httpResponse) = try await IFMNetworking.session.data(from: url)
        try validateScoutResponse(httpResponse, provider: "Hacker News", data: data)
        let response = try JSONDecoder().decode(HackerNewsSearchResponse.self, from: data)
        return response.hits.prefix(limit).map { hit in
            ScoutSignal(
                title: hit.title ?? hit.storyTitle ?? "Hacker News signal",
                summary: "Recent discussion signal for \(query).",
                url: hit.url ?? hit.storyURL,
                kind: .article
            )
        }
    }
}

/// Turn a non-2xx scout response into a clear error instead of a confusing JSON
/// decode failure. GitHub's unauthenticated search returns 403 (rate limit) with a
/// JSON error body that does not match our model — that used to surface as an opaque
/// "keyNotFound" rather than "rate limited".
private func validateScoutResponse(_ response: URLResponse, provider: String, data: Data) throws {
    guard let http = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(http.statusCode) else {
        let snippet = String((String(data: data, encoding: .utf8) ?? "").prefix(160))
        throw LLMProviderError.requestFailed("\(provider) scout request failed (\(http.statusCode)): \(snippet)")
    }
}

private struct GitHubSearchResponse: Decodable {
    var items: [GitHubRepo]
}

private struct GitHubRepo: Decodable {
    var fullName: String
    var description: String?
    var htmlURL: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case description
        case htmlURL = "html_url"
    }
}

private struct HackerNewsSearchResponse: Decodable {
    var hits: [HackerNewsHit]
}

private struct HackerNewsHit: Decodable {
    var title: String?
    var storyTitle: String?
    var url: String?
    var storyURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case storyTitle = "story_title"
        case url
        case storyURL = "story_url"
    }
}
