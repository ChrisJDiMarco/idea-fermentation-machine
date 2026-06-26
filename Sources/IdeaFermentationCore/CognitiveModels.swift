import Foundation

/// The kinds of node the mind forms as it thinks. Distinct from an `IdeaSeed` (a candidate
/// to build) — a `Thought` is a unit of the mind's *reasoning*: something it noticed, a link
/// it drew, a hypothesis it floated, or a question it wants to chase next.
public enum ThoughtKind: String, Codable, CaseIterable, Sendable {
    case observation   // something noticed in the material
    case connection    // a link drawn between two things
    case hypothesis    // a proposition the mind is entertaining
    case question      // an open thread to pull on next

    public var label: String {
        switch self {
        case .observation: return "Observation"
        case .connection: return "Connection"
        case .hypothesis: return "Hypothesis"
        case .question: return "Question"
        }
    }

    public var symbol: String {
        switch self {
        case .observation: return "eye"
        case .connection: return "point.topleft.down.to.point.bottomright.curvepath"
        case .hypothesis: return "lightbulb"
        case .question: return "questionmark.circle"
        }
    }
}

/// A single node in the mind's evolving web. Persisted, so the web grows across sessions and
/// later thinking can reference earlier thoughts.
public struct Thought: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sessionID: UUID
    public var kind: ThoughtKind
    public var content: String
    /// Why the mind formed this — the reasoning behind the node, not just the claim.
    public var rationale: String
    /// 0…1 — how sure the mind is of this thought. Set by the reflection pass.
    public var confidence: Double
    /// Ideas this thought drew on, so the web links back into the portfolio.
    public var relatedIdeaIDs: [UUID]
    public var createdAt: Date
    /// True when the thought drew on never-send material — keeps it (and anything derived
    /// from it) off the wire on future cloud cycles, mirroring `IdeaSeed.derivedFromNeverSend`.
    public var derivedFromNeverSend: Bool

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        kind: ThoughtKind,
        content: String,
        rationale: String = "",
        confidence: Double = 0.5,
        relatedIdeaIDs: [UUID] = [],
        createdAt: Date = Date(),
        derivedFromNeverSend: Bool = false
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kind = kind
        self.content = content
        self.rationale = rationale
        self.confidence = min(1, max(0, confidence))
        self.relatedIdeaIDs = relatedIdeaIDs
        self.createdAt = createdAt
        self.derivedFromNeverSend = derivedFromNeverSend
    }
}

/// How one thought relates to another — the typed, labelled edges of the web.
public enum ThoughtEdgeType: String, Codable, CaseIterable, Sendable {
    case supports
    case contradicts
    case extends
    case questions
    case derivesFrom

    public var label: String {
        switch self {
        case .supports: return "supports"
        case .contradicts: return "contradicts"
        case .extends: return "extends"
        case .questions: return "questions"
        case .derivesFrom: return "derives from"
        }
    }

    /// Contradictions are the productive tension worth surfacing; colour them apart.
    public var isTension: Bool { self == .contradicts || self == .questions }
}

/// A typed connection between two thoughts. The web is `[Thought]` + `[ThoughtEdge]`.
public struct ThoughtEdge: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sessionID: UUID
    public var fromThoughtID: UUID
    public var toThoughtID: UUID
    public var type: ThoughtEdgeType
    public var rationale: String
    /// 0…1 — how strong the link is.
    public var strength: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        fromThoughtID: UUID,
        toThoughtID: UUID,
        type: ThoughtEdgeType,
        rationale: String = "",
        strength: Double = 0.5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.fromThoughtID = fromThoughtID
        self.toThoughtID = toThoughtID
        self.type = type
        self.rationale = rationale
        self.strength = min(1, max(0, strength))
        self.createdAt = createdAt
    }
}

/// The metacognition layer — the mind thinking about *how it just thought*. Not a critique of
/// the ideas, but of the reasoning that produced them: what it leaned on, where it's weakest,
/// which links might be spurious, and what to chase next. This is the "checking how it thinks
/// about what it thinks" step.
public struct MindReflection: Codable, Equatable, Sendable {
    /// The single weakest link in this cycle's reasoning.
    public var weakestLink: String
    /// Assumptions the reasoning quietly rested on.
    public var assumptions: [String]
    /// Connections the mind suspects it drew too eagerly (pattern-matching, not real).
    public var spuriousConnections: [String]
    /// A note on the *process* — did it explore widely enough, or overfit to taste / repeat itself?
    public var processNote: String
    /// 0…1 — calibrated confidence in this cycle's output after the self-check.
    public var confidence: Double
    /// The thread the mind judges most worth pulling on next session.
    public var nextToExplore: String

    public init(
        weakestLink: String = "",
        assumptions: [String] = [],
        spuriousConnections: [String] = [],
        processNote: String = "",
        confidence: Double = 0.5,
        nextToExplore: String = ""
    ) {
        self.weakestLink = weakestLink
        self.assumptions = assumptions
        self.spuriousConnections = spuriousConnections
        self.processNote = processNote
        self.confidence = min(1, max(0, confidence))
        self.nextToExplore = nextToExplore
    }

    public var isEmpty: Bool {
        weakestLink.isEmpty && assumptions.isEmpty && spuriousConnections.isEmpty
            && processNote.isEmpty && nextToExplore.isEmpty
    }
}

/// One complete cognitive cycle — the unit of the mind's autonomous thinking. Persisted as a
/// readable trace: what it set out to think about, what it concluded, what it generated, and
/// how it judged its own reasoning.
public struct ThinkingSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    /// What this cycle set out to think about.
    public var focus: String
    public var startedAt: Date
    /// The narrative of what the mind reasoned through this cycle.
    public var analysis: String
    public var reflection: MindReflection
    public var thoughtIDs: [UUID]
    public var edgeIDs: [UUID]
    public var generatedIdeaIDs: [UUID]
    public var costUSD: Double
    /// "cloud · <provider>" or "local" — provenance, mirroring the rest of the app.
    public var source: String
    public var derivedFromNeverSend: Bool

    public init(
        id: UUID = UUID(),
        focus: String,
        startedAt: Date = Date(),
        analysis: String = "",
        reflection: MindReflection = MindReflection(),
        thoughtIDs: [UUID] = [],
        edgeIDs: [UUID] = [],
        generatedIdeaIDs: [UUID] = [],
        costUSD: Double = 0,
        source: String = "local",
        derivedFromNeverSend: Bool = false
    ) {
        self.id = id
        self.focus = focus
        self.startedAt = startedAt
        self.analysis = analysis
        self.reflection = reflection
        self.thoughtIDs = thoughtIDs
        self.edgeIDs = edgeIDs
        self.generatedIdeaIDs = generatedIdeaIDs
        self.costUSD = costUSD
        self.source = source
        self.derivedFromNeverSend = derivedFromNeverSend
    }

    public var isCloud: Bool { source.hasPrefix("cloud") }
}

/// A VC-grade idea thesis the mind discovers when handed a *space* rather than an idea. This is
/// the "researcher + VC" output: not just an idea, but the bet, why it's timely, how to enter, why
/// it would compound, what would kill it, and how much conviction it carries.
public struct DiscoveredThesis: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    /// The core bet — what it is and why it's non-obvious.
    public var thesis: String
    /// The timing thesis — what changed that makes this possible *now*.
    public var whyNow: String
    /// The smallest beachhead to enter the market.
    public var wedge: String
    /// Why it compounds / gets harder to copy over time.
    public var moat: String
    /// The single assumption that would kill it if false.
    public var riskiestAssumption: String
    /// 0…1 — how fundable / worth building right now, the VC's honest read.
    public var conviction: Double
    public var tags: [String]

    public init(id: UUID = UUID(), title: String, thesis: String, whyNow: String = "", wedge: String = "", moat: String = "", riskiestAssumption: String = "", conviction: Double = 0.5, tags: [String] = []) {
        self.id = id
        self.title = title
        self.thesis = thesis
        self.whyNow = whyNow
        self.wedge = wedge
        self.moat = moat
        self.riskiestAssumption = riskiestAssumption
        self.conviction = min(1, max(0, conviction))
        self.tags = tags
    }

    /// The full thesis as an idea body for the inbox — the bet plus the VC read.
    public var ideaBody: String {
        var lines = [thesis]
        if !whyNow.isEmpty { lines.append("\n**Why now:** \(whyNow)") }
        if !wedge.isEmpty { lines.append("**Wedge:** \(wedge)") }
        if !moat.isEmpty { lines.append("**Moat:** \(moat)") }
        if !riskiestAssumption.isEmpty { lines.append("**Riskiest assumption:** \(riskiestAssumption)") }
        return lines.joined(separator: "\n")
    }
}

/// What a discovery run returns: the persistable cognitive result (the space map + theses as a
/// web), the structured theses for the Discover UI, and every response paid for.
public struct DiscoveryOutcome: Sendable {
    public var result: CognitiveResult?
    public var theses: [DiscoveredThesis]
    public var responses: [LLMResponse]

    public init(result: CognitiveResult?, theses: [DiscoveredThesis], responses: [LLMResponse]) {
        self.result = result
        self.theses = theses
        self.responses = responses
    }
}

/// What the engine returns from one cycle — assembled here, persisted by the store, and (for
/// generated ideas) admitted into the inbox by the view model. Generated ideas are `ExtractedSeed`
/// (the same shape the scout produces) so the downstream save path is shared.
public struct CognitiveResult: Sendable {
    public var session: ThinkingSession
    public var thoughts: [Thought]
    public var edges: [ThoughtEdge]
    public var generated: [ExtractedSeed]
    public var responses: [LLMResponse]

    public init(session: ThinkingSession, thoughts: [Thought], edges: [ThoughtEdge], generated: [ExtractedSeed], responses: [LLMResponse]) {
        self.session = session
        self.thoughts = thoughts
        self.edges = edges
        self.generated = generated
        self.responses = responses
    }
}
