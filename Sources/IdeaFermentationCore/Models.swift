import Foundation

public enum IdeaStatus: String, Codable, CaseIterable, Sendable {
    case inbox
    case fermenting
    case ripening
    case ready
    case archived
}

public enum FermentationStage: String, Codable, CaseIterable, Sendable {
    case seed
    case cooling
    case brewing
    case crossPollinating
    case needsDistance
    case readyToPrototype

    public var title: String {
        switch self {
        case .seed: "Seed"
        case .cooling: "Cooling"
        case .brewing: "Brewing"
        case .crossPollinating: "Cross-Pollinating"
        case .needsDistance: "Needs Distance"
        case .readyToPrototype: "Ready To Prototype"
        }
    }
}

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case screenshot
    case voiceMemo
    case article
    case note
    case conversation
    case document
    case link
    case quote
    case sketch
    case file
}

public enum SourceExtractionStatus: String, Codable, CaseIterable, Sendable {
    case captured
    case summarized
    case tagged
    case connected
    case revisitScheduled
    case failed
}

public enum JobStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case running
    case complete
    case failed
    case paused
    case needsApproval
}

public enum ArchiveOutcome: String, Codable, CaseIterable, Sendable {
    case shipped
    case killed
    case merged
    case paused
    case learnedFrom
}

public enum ModelTaskClass: String, Codable, CaseIterable, Sendable {
    case extract
    case tag
    case summarize
    case connect
    case critique
    case scoreRipeness
    case prototypeBrief
}

public struct IdeaSeed: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var status: IdeaStatus
    public var stage: FermentationStage
    public var sourceIDs: [UUID]
    public var manualTags: [String]
    public var textHash: String
    public var embedding: [Double]
    public var ripeness: Double
    public var novelty: Double
    public var feasibility: Double
    public var evidence: Double
    public var personalResonance: Double
    public var timing: Double
    /// True when this idea's content derives from a never-send source (created from one,
    /// or scout evidence attached). Set once at creation/link time so every cloud digest
    /// checks ONE flag instead of re-deriving it — and sticky, so an idea that ever held
    /// protected content stays protected.
    public var derivedFromNeverSend: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: IdeaStatus = .inbox,
        stage: FermentationStage = .seed,
        sourceIDs: [UUID] = [],
        manualTags: [String] = [],
        textHash: String = "",
        embedding: [Double] = [],
        ripeness: Double = 0,
        novelty: Double = 0,
        feasibility: Double = 0,
        evidence: Double = 0,
        personalResonance: Double = 0,
        timing: Double = 0,
        derivedFromNeverSend: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.stage = stage
        self.sourceIDs = sourceIDs
        self.manualTags = manualTags
        self.textHash = textHash
        self.embedding = embedding
        self.ripeness = ripeness
        self.novelty = novelty
        self.feasibility = feasibility
        self.evidence = evidence
        self.personalResonance = personalResonance
        self.timing = timing
        self.derivedFromNeverSend = derivedFromNeverSend
    }
}

public struct SourceItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: SourceType
    public var title: String
    public var body: String
    public var createdAt: Date
    public var filePath: String?
    public var url: String?
    public var extractionStatus: SourceExtractionStatus
    public var linkedIdeaIDs: [UUID]
    public var neverSendToCloud: Bool
    public var textHash: String
    public var metadata: SourceMetadata

    public init(
        id: UUID = UUID(),
        type: SourceType,
        title: String,
        body: String,
        createdAt: Date = Date(),
        filePath: String? = nil,
        url: String? = nil,
        extractionStatus: SourceExtractionStatus = .captured,
        linkedIdeaIDs: [UUID] = [],
        neverSendToCloud: Bool = false,
        textHash: String = "",
        metadata: SourceMetadata = SourceMetadata()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.filePath = filePath
        self.url = url
        self.extractionStatus = extractionStatus
        self.linkedIdeaIDs = linkedIdeaIDs
        self.neverSendToCloud = neverSendToCloud
        self.textHash = textHash
        self.metadata = metadata
    }
}

public struct IdeaConnection: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var fromID: UUID
    public var toID: UUID
    public var explanation: String
    public var confidence: Double
    public var createdAt: Date

    public init(id: UUID = UUID(), fromID: UUID, toID: UUID, explanation: String, confidence: Double, createdAt: Date = Date()) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.explanation = explanation
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

public struct FermentationJob: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ideaID: UUID?
    public var sourceID: UUID?
    public var taskClass: ModelTaskClass
    public var status: JobStatus
    public var retryCount: Int
    public var estimatedCostUSD: Double
    public var modelRoute: ModelRoute?
    public var inputHash: String
    public var createdAt: Date
    public var updatedAt: Date
    public var scheduledAt: Date?
    public var completedAt: Date?
    public var lastError: String?
    public var retryAfter: Date?
    public var runID: UUID?

    public init(
        id: UUID = UUID(),
        ideaID: UUID? = nil,
        sourceID: UUID? = nil,
        taskClass: ModelTaskClass,
        status: JobStatus = .pending,
        retryCount: Int = 0,
        estimatedCostUSD: Double = 0,
        modelRoute: ModelRoute? = nil,
        inputHash: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        scheduledAt: Date? = nil,
        completedAt: Date? = nil,
        lastError: String? = nil,
        retryAfter: Date? = nil,
        runID: UUID? = nil
    ) {
        self.id = id
        self.ideaID = ideaID
        self.sourceID = sourceID
        self.taskClass = taskClass
        self.status = status
        self.retryCount = retryCount
        self.estimatedCostUSD = estimatedCostUSD
        self.modelRoute = modelRoute
        self.inputHash = inputHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
        self.lastError = lastError
        self.retryAfter = retryAfter
        self.runID = runID
    }
}

public struct FermentationRun: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var status: JobStatus
    public var jobIDs: [UUID]
    public var totalEstimatedCostUSD: Double

    public init(id: UUID = UUID(), startedAt: Date = Date(), completedAt: Date? = nil, status: JobStatus = .running, jobIDs: [UUID] = [], totalEstimatedCostUSD: Double = 0) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.jobIDs = jobIDs
        self.totalEstimatedCostUSD = totalEstimatedCostUSD
    }
}

public struct AgentRunLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var jobID: UUID
    public var agentName: String
    public var promptVersion: String
    public var inputTrace: String
    public var output: String
    public var modelUsed: String
    public var createdAt: Date

    public init(id: UUID = UUID(), jobID: UUID, agentName: String, promptVersion: String, inputTrace: String, output: String, modelUsed: String, createdAt: Date = Date()) {
        self.id = id
        self.jobID = jobID
        self.agentName = agentName
        self.promptVersion = promptVersion
        self.inputTrace = inputTrace
        self.output = output
        self.modelUsed = modelUsed
        self.createdAt = createdAt
    }
}

public struct RipenessScore: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ideaID: UUID
    public var novelty: Double
    public var clarity: Double
    public var evidence: Double
    public var personalResonance: Double
    public var feasibility: Double
    public var timing: Double
    public var createdAt: Date

    public var average: Double {
        (novelty + clarity + evidence + personalResonance + feasibility + timing) / 6
    }

    public init(id: UUID = UUID(), ideaID: UUID, novelty: Double, clarity: Double, evidence: Double, personalResonance: Double, feasibility: Double, timing: Double, createdAt: Date = Date()) {
        self.id = id
        self.ideaID = ideaID
        self.novelty = novelty
        self.clarity = clarity
        self.evidence = evidence
        self.personalResonance = personalResonance
        self.feasibility = feasibility
        self.timing = timing
        self.createdAt = createdAt
    }
}

public struct IdeaCritique: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ideaID: UUID
    public var assumptions: [String]
    public var risks: [String]
    public var contradictions: [String]
    /// "local" for the heuristic pass, or "provider/model" when a cloud critique
    /// produced it. Lets the UI show provenance and lets cloud results win.
    public var source: String
    public var createdAt: Date

    public var isEmpty: Bool { assumptions.isEmpty && risks.isEmpty && contradictions.isEmpty }

    public init(id: UUID = UUID(), ideaID: UUID, assumptions: [String], risks: [String], contradictions: [String], source: String = "local", createdAt: Date = Date()) {
        self.id = id
        self.ideaID = ideaID
        self.assumptions = assumptions
        self.risks = risks
        self.contradictions = contradictions
        self.source = source
        self.createdAt = createdAt
    }
}

public struct PrototypeBrief: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ideaID: UUID
    public var audience: String
    public var mvpScope: String
    public var risks: String
    public var nextActions: [String]
    public var markdown: String
    public var createdAt: Date

    public init(id: UUID = UUID(), ideaID: UUID, audience: String, mvpScope: String, risks: String, nextActions: [String], markdown: String, createdAt: Date = Date()) {
        self.id = id
        self.ideaID = ideaID
        self.audience = audience
        self.mvpScope = mvpScope
        self.risks = risks
        self.nextActions = nextActions
        self.markdown = markdown
        self.createdAt = createdAt
    }
}

public struct LLMUsageRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var provider: String
    public var model: String
    public var taskClass: ModelTaskClass
    public var inputTokens: Int
    public var outputTokens: Int
    public var estimatedCostUSD: Double
    public var createdAt: Date

    public init(id: UUID = UUID(), provider: String, model: String, taskClass: ModelTaskClass, inputTokens: Int, outputTokens: Int, estimatedCostUSD: Double, createdAt: Date = Date()) {
        self.id = id
        self.provider = provider
        self.model = model
        self.taskClass = taskClass
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.createdAt = createdAt
    }
}

/// The terminal outcome of taking an idea to build — the strongest taste signal the
/// app can capture, because building is a far more committed act than tentatively
/// marking an idea "ready".
public enum BuildResult: String, Codable, CaseIterable, Sendable {
    case shipped      // built and released
    case built        // built and kept / it works
    case abandoned    // got a plan, never built it
    case flopped      // built it, but it didn't pan out

    public var title: String {
        switch self {
        case .shipped: "Shipped"
        case .built: "Built & kept"
        case .abandoned: "Abandoned"
        case .flopped: "Built but flopped"
        }
    }

    /// Whether this is evidence the operator's taste was *right* about the idea.
    public var isPositive: Bool { self == .shipped || self == .built }

    /// Direction of the taste signal: +1 you should see more like this, −1 less.
    public var tasteLabel: Double { isPositive ? 1 : -1 }

    /// How hard the signal pushes — stronger than a mark-ready (0.6), because acting
    /// on an idea says more than flagging it. `flopped` pushes gently: the idea pulled
    /// you in (worth something) even though the execution didn't land.
    public var tasteRate: Double {
        switch self {
        case .shipped: 1.0
        case .built: 0.85
        case .abandoned: 0.85
        case .flopped: 0.5
        }
    }
}

public struct BuildOutcome: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ideaID: UUID
    public var result: BuildResult
    public var note: String
    public var createdAt: Date

    public init(id: UUID = UUID(), ideaID: UUID, result: BuildResult, note: String = "", createdAt: Date = Date()) {
        self.id = id
        self.ideaID = ideaID
        self.result = result
        self.note = note
        self.createdAt = createdAt
    }
}

/// A recorded *prediction*: when the app promoted an idea to Ready, it snapshotted the
/// score it was betting on. When a build outcome later lands, the forecast is resolved
/// against reality — so the app can finally measure whether its own "Ready" calls are
/// any good, instead of asking you to take its scoring on faith.
public struct ForecastLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var ideaID: UUID
    public var predictedAt: Date
    public var ripenessAtPrediction: Double
    public var predictedProbability: Double
    public var novelty: Double
    public var clarity: Double
    public var evidence: Double
    public var resonance: Double
    public var feasibility: Double
    public var timing: Double
    public var source: String
    public var resolvedAt: Date?
    public var actualPositive: Bool?
    public var outcomeResult: BuildResult?

    public init(
        id: UUID = UUID(), ideaID: UUID, predictedAt: Date = Date(),
        ripenessAtPrediction: Double, predictedProbability: Double,
        novelty: Double = 0, clarity: Double = 0, evidence: Double = 0,
        resonance: Double = 0, feasibility: Double = 0, timing: Double = 0,
        source: String = "auto",
        resolvedAt: Date? = nil, actualPositive: Bool? = nil, outcomeResult: BuildResult? = nil
    ) {
        self.id = id
        self.ideaID = ideaID
        self.predictedAt = predictedAt
        self.ripenessAtPrediction = ripenessAtPrediction
        self.predictedProbability = predictedProbability
        self.novelty = novelty
        self.clarity = clarity
        self.evidence = evidence
        self.resonance = resonance
        self.feasibility = feasibility
        self.timing = timing
        self.source = source
        self.resolvedAt = resolvedAt
        self.actualPositive = actualPositive
        self.outcomeResult = outcomeResult
    }

    public var isResolved: Bool { resolvedAt != nil }

    /// A Ready call is a positive prediction — it was right when the build went well.
    public var wasCorrect: Bool? { actualPositive }

    /// Map ripeness to a calibrated win probability so a Brier score measures real
    /// calibration rather than pinning every prediction near a flat value. The Ready
    /// threshold (78) maps to a coin flip; a perfect 100 to near-certainty.
    public static func probability(forRipeness ripeness: Double) -> Double {
        max(0.5, min(0.99, 0.5 + (ripeness - 78.0) / 44.0))
    }
}

/// How well the app's Ready predictions have actually held up. Deliberately refuses to
/// claim a hit-rate below a handful of resolved forecasts — small samples are noise.
public struct ForecastAccuracy: Equatable, Sendable {
    public var resolvedCount: Int
    public var correctCount: Int
    public var openCount: Int
    /// Mean squared error of the predicted probabilities vs. reality. 0 is perfect;
    /// 0.25 is a no-skill coin flip; above 0.25 means the Ready bar is miscalibrated.
    public var brier: Double

    public init(resolvedCount: Int = 0, correctCount: Int = 0, openCount: Int = 0, brier: Double = 0) {
        self.resolvedCount = resolvedCount
        self.correctCount = correctCount
        self.openCount = openCount
        self.brier = brier
    }

    public init(from logs: [ForecastLog]) {
        let resolved = logs.filter { $0.isResolved && $0.actualPositive != nil }
        resolvedCount = resolved.count
        correctCount = resolved.filter { $0.wasCorrect == true }.count
        openCount = logs.filter { !$0.isResolved }.count
        if resolved.isEmpty {
            brier = 0
        } else {
            brier = resolved.map { log in
                let actual = (log.actualPositive == true) ? 1.0 : 0.0
                let delta = log.predictedProbability - actual
                return delta * delta
            }.reduce(0, +) / Double(resolved.count)
        }
    }

    public var hitRate: Double { resolvedCount > 0 ? Double(correctCount) / Double(resolvedCount) : 0 }
    /// Below this many resolved forecasts we don't report a percentage — it's noise.
    public var isReliable: Bool { resolvedCount >= 5 }
    public var beatsCoinFlip: Bool { isReliable && brier < 0.25 }
}

public struct AppBudget: Codable, Equatable, Sendable {
    public var dailyUSD: Double
    public var monthlyUSD: Double
    public var approvalThresholdUSD: Double

    public init(dailyUSD: Double = 1, monthlyUSD: Double = 20, approvalThresholdUSD: Double = 0.25) {
        self.dailyUSD = dailyUSD
        self.monthlyUSD = monthlyUSD
        self.approvalThresholdUSD = approvalThresholdUSD
    }
}
