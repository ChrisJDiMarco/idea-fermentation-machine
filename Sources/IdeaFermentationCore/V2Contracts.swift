import Foundation

public struct ExtractedSeed: Codable, Equatable, Sendable {
    public var title: String
    public var body: String
    public var tags: [String]

    public init(title: String, body: String, tags: [String] = []) {
        self.title = title
        self.body = body
        self.tags = tags
    }
}

public struct TagResult: Codable, Equatable, Sendable {
    public var tags: [String]
    public var summary: String

    public init(tags: [String], summary: String) {
        self.tags = tags
        self.summary = summary
    }
}

public struct SourceSummary: Codable, Equatable, Sendable {
    public var summary: String
    public var tags: [String]
    public var linkedIdeaIDs: [UUID]

    public init(summary: String, tags: [String] = [], linkedIdeaIDs: [UUID] = []) {
        self.summary = summary
        self.tags = tags
        self.linkedIdeaIDs = linkedIdeaIDs
    }
}

public struct ConnectionCandidate: Codable, Equatable, Sendable {
    public var fromID: UUID
    public var toID: UUID
    public var explanation: String
    public var confidence: Double

    public init(fromID: UUID, toID: UUID, explanation: String, confidence: Double) {
        self.fromID = fromID
        self.toID = toID
        self.explanation = explanation
        self.confidence = confidence
    }
}

public struct CritiqueResult: Codable, Equatable, Sendable {
    public var assumptions: [String]
    public var risks: [String]
    public var contradictions: [String]

    public init(assumptions: [String] = [], risks: [String] = [], contradictions: [String] = []) {
        self.assumptions = assumptions
        self.risks = risks
        self.contradictions = contradictions
    }
}

public struct RipenessResult: Codable, Equatable, Sendable {
    public var novelty: Double
    public var clarity: Double
    public var evidence: Double
    public var personalResonance: Double
    public var feasibility: Double
    public var timing: Double

    public var average: Double {
        (novelty + clarity + evidence + personalResonance + feasibility + timing) / 6
    }

    public init(novelty: Double, clarity: Double, evidence: Double, personalResonance: Double, feasibility: Double, timing: Double) {
        self.novelty = novelty
        self.clarity = clarity
        self.evidence = evidence
        self.personalResonance = personalResonance
        self.feasibility = feasibility
        self.timing = timing
    }
}

public struct PrototypeBriefDraft: Codable, Equatable, Sendable {
    public var audience: String
    public var mvpScope: String
    public var risks: String
    public var nextActions: [String]
    public var markdown: String

    public init(audience: String, mvpScope: String, risks: String, nextActions: [String], markdown: String) {
        self.audience = audience
        self.mvpScope = mvpScope
        self.risks = risks
        self.nextActions = nextActions
        self.markdown = markdown
    }
}

public struct SourceMetadata: Codable, Equatable, Sendable {
    public var originalFileName: String?
    public var fileSize: Int64?
    public var contentType: String?
    public var importedAt: Date
    // Web-capture enrichment. All optional + decoded with a `try?`-with-default
    // fallback in IdeaStore.decodeSource, so older rows lacking these keys stay valid.
    public var siteName: String?
    public var author: String?
    public var excerpt: String?
    public var faviconURL: String?
    public var publishedTime: String?
    /// How the source entered the app, e.g. "chrome-extension". nil for older/manual sources.
    public var capturedVia: String?
    /// Human-readable category label (e.g. "Article", "Repository") layered on top of SourceType.
    public var category: String?
    /// Auto-derived theme tags for the source (sources have no first-class tag field).
    public var tags: [String]?

    public init(
        originalFileName: String? = nil,
        fileSize: Int64? = nil,
        contentType: String? = nil,
        importedAt: Date = Date(),
        siteName: String? = nil,
        author: String? = nil,
        excerpt: String? = nil,
        faviconURL: String? = nil,
        publishedTime: String? = nil,
        capturedVia: String? = nil,
        category: String? = nil,
        tags: [String]? = nil
    ) {
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.contentType = contentType
        self.importedAt = importedAt
        self.siteName = siteName
        self.author = author
        self.excerpt = excerpt
        self.faviconURL = faviconURL
        self.publishedTime = publishedTime
        self.capturedVia = capturedVia
        self.category = category
        self.tags = tags
    }
}

public struct SchedulerSettings: Codable, Equatable, Sendable {
    public var localCadenceMinutes: Int
    public var revisitCadenceDays: Int
    public var maxLocalJobsPerPass: Int
    public var dailySpendCapUSD: Double
    public var monthlySpendCapUSD: Double
    public var cloudAutoRun: Bool
    public var nextLocalRunAt: Date?

    public init(localCadenceMinutes: Int = 60, revisitCadenceDays: Int = 3, maxLocalJobsPerPass: Int = 25, dailySpendCapUSD: Double = 1, monthlySpendCapUSD: Double = 20, cloudAutoRun: Bool = false, nextLocalRunAt: Date? = nil) {
        self.localCadenceMinutes = localCadenceMinutes
        self.revisitCadenceDays = revisitCadenceDays
        self.maxLocalJobsPerPass = maxLocalJobsPerPass
        self.dailySpendCapUSD = dailySpendCapUSD
        self.monthlySpendCapUSD = monthlySpendCapUSD
        self.cloudAutoRun = cloudAutoRun
        self.nextLocalRunAt = nextLocalRunAt
    }
}

public struct ProviderSettings: Codable, Equatable, Sendable {
    public var fallbackProviderLabel: String
    public var fallbackBaseURL: String
    public var fallbackModelName: String
    public var fallbackInputCostPerMillion: Double?
    public var fallbackOutputCostPerMillion: Double?

    public init(fallbackProviderLabel: String = "OpenAI Compatible", fallbackBaseURL: String = "https://api.openai.com/v1/", fallbackModelName: String = "gpt-4.1-mini", fallbackInputCostPerMillion: Double? = nil, fallbackOutputCostPerMillion: Double? = nil) {
        self.fallbackProviderLabel = fallbackProviderLabel
        self.fallbackBaseURL = fallbackBaseURL
        self.fallbackModelName = fallbackModelName
        self.fallbackInputCostPerMillion = fallbackInputCostPerMillion
        self.fallbackOutputCostPerMillion = fallbackOutputCostPerMillion
    }
}

public struct AutonomyProfile: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var tasteNotes: String
    public var goals: String
    public var watchTopics: String
    public var excludedTopics: String
    public var preferredOutputs: String
    public var allowWebScouting: Bool
    public var requireApprovalBeforeBuildHandoff: Bool

    public init(
        isEnabled: Bool = false,
        tasteNotes: String = "",
        goals: String = "",
        watchTopics: String = "",
        excludedTopics: String = "",
        preferredOutputs: String = "idea brief, prototype scope, mockup prompt",
        allowWebScouting: Bool = true,
        requireApprovalBeforeBuildHandoff: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.tasteNotes = tasteNotes
        self.goals = goals
        self.watchTopics = watchTopics
        self.excludedTopics = excludedTopics
        self.preferredOutputs = preferredOutputs
        self.allowWebScouting = allowWebScouting
        self.requireApprovalBeforeBuildHandoff = requireApprovalBeforeBuildHandoff
    }
}

public struct ScoutMission: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var query: String
    public var cadenceHours: Int
    public var isEnabled: Bool
    public var lastRunAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        query: String,
        cadenceHours: Int = 24,
        isEnabled: Bool = true,
        lastRunAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.query = query
        self.cadenceHours = cadenceHours
        self.isEnabled = isEnabled
        self.lastRunAt = lastRunAt
    }
}

public struct ScoutSignal: Codable, Equatable, Sendable {
    public var title: String
    public var summary: String
    public var url: String?
    public var kind: SourceType

    public init(title: String, summary: String, url: String? = nil, kind: SourceType = .article) {
        self.title = title
        self.summary = summary
        self.url = url
        self.kind = kind
    }
}
