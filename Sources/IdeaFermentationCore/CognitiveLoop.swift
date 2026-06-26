import Foundation

/// The deterministic harness that runs one autonomous cognitive cycle. The *structure* is
/// fixed — perceive → reason (analyse + connect) → generate → reflect → assemble — but the
/// *content* is emergent. The reflect stage is metacognition: the mind judging the reasoning
/// it just did, not the ideas it produced.
///
/// Resilience mirrors the deep-critique loop: only the first (reasoning) call is load-bearing;
/// later stages degrade gracefully, and every response that actually came back is returned so
/// the caller can record real spend even on a partial cycle.
public enum CognitiveLoop {
    /// Everything one cycle reasons over. The caller is responsible for privacy: for a cloud
    /// cycle it passes only untainted ideas/sources and sets `derivedFromNeverSend = false`;
    /// the local path may include protected material and marks the cycle tainted.
    public struct Material: Sendable {
        public var ideas: [IdeaSeed]
        public var sources: [SourceItem]
        public var signals: [ScoutSignal]
        public var priorThoughts: [Thought]
        public var derivedFromNeverSend: Bool

        public init(ideas: [IdeaSeed], sources: [SourceItem] = [], signals: [ScoutSignal] = [], priorThoughts: [Thought] = [], derivedFromNeverSend: Bool = false) {
            self.ideas = ideas
            self.sources = sources
            self.signals = signals
            self.priorThoughts = priorThoughts
            self.derivedFromNeverSend = derivedFromNeverSend
        }

        public var hasEnoughToThinkAbout: Bool { ideas.count + signals.count >= 2 }
    }

    private static let maxNodes = 6

    // MARK: - Cloud cycle

    /// Runs the full reasoning loop on a real model. Returns nil only when the reasoning call
    /// itself throws (nothing billable came back). A non-nil result whose `thoughts` are empty
    /// means the cycle was paid for but produced nothing usable — the caller should record the
    /// spend and fall back to a local cycle rather than persist an empty session.
    public static func think(
        material: Material,
        taste: TasteProfile?,
        builderProfile: AutonomyProfile?,
        provider: any LLMProvider,
        model: LLMModel,
        apiKey: String,
        now: Date = Date()
    ) async throws -> CognitiveResult? {
        let sessionID = UUID()
        let builder = BuilderContext.promptPrefix(profile: builderProfile, taste: taste)
        var responses: [LLMResponse] = []

        // Stage 1+2 — Reason: analyse across the material and draw typed connections. Load-bearing.
        let reasonRequest = LLMRequest(
            taskClass: .prototypeBrief,
            prompt: builder + reasonInstruction,
            input: digest(material),
            maxOutputTokens: 1_100
        )
        let reasonResponse = try await provider.send(reasonRequest, model: model, apiKey: apiKey)
        responses.append(reasonResponse)
        guard let reason = decode(ReasonOutput.self, from: reasonResponse.text) else {
            return CognitiveResult(
                session: ThinkingSession(focus: "(unreadable cycle)", startedAt: now, source: "cloud · \(provider.providerName)", derivedFromNeverSend: material.derivedFromNeverSend),
                thoughts: [], edges: [], generated: [], responses: responses
            )
        }

        // Stage 3 — Generate: one original idea grounded in the reasoning. Best-effort.
        var generated: [ExtractedSeed] = []
        let generateRequest = LLMRequest(
            taskClass: .prototypeBrief,
            prompt: builder + generateInstruction,
            input: reasoningSummary(reason),
            maxOutputTokens: 700
        )
        if let genResponse = try? await provider.send(generateRequest, model: model, apiKey: apiKey) {
            responses.append(genResponse)
            if let seed = AutonomousScout.decodeSeed(from: genResponse.text) { generated = [seed] }
        }

        // Stage 4 — Reflect: metacognition. Critique the REASONING, not the ideas. Best-effort.
        var reflection = MindReflection()
        let reflectRequest = LLMRequest(
            taskClass: .critique,
            prompt: reflectInstruction,
            input: "FOCUS: \(reason.focus)\n\n\(reasoningSummary(reason))\n\nIDEA PROPOSED:\n\(generated.first.map { "\($0.title): \($0.body)" } ?? "(none)")",
            maxOutputTokens: 500
        )
        if let reflectResponse = try? await provider.send(reflectRequest, model: model, apiKey: apiKey) {
            responses.append(reflectResponse)
            if let decoded = decode(ReflectionOutput.self, from: reflectResponse.text) {
                reflection = decoded.asReflection
            }
        }

        // Assemble the web from the reasoning, anchoring confidence on the reflection's self-check.
        let confidence = reflection.isEmpty ? 0.55 : reflection.confidence
        let (thoughts, edges) = assemble(reason: reason, sessionID: sessionID, material: material, confidence: confidence, now: now)

        let session = ThinkingSession(
            id: sessionID,
            focus: reason.focus.isEmpty ? "Untitled cycle" : reason.focus,
            startedAt: now,
            analysis: reason.summary,
            reflection: reflection,
            thoughtIDs: thoughts.map(\.id),
            edgeIDs: edges.map(\.id),
            generatedIdeaIDs: [],
            costUSD: 0,
            source: "cloud · \(provider.providerName)",
            derivedFromNeverSend: material.derivedFromNeverSend
        )
        return CognitiveResult(session: session, thoughts: thoughts, edges: edges, generated: generated, responses: responses)
    }

    // MARK: - Local cycle (offline, degraded but real)

    /// A real cognitive pass with no model: find the strongest links among the ideas via
    /// on-device embeddings, form observation + connection nodes, and float one combining
    /// hypothesis. The mind still thinks — just bluntly — when there's no key or the cap is hit.
    public static func localThink(material: Material, now: Date = Date()) -> CognitiveResult? {
        let ideas = Array(material.ideas.sorted { $0.ripeness > $1.ripeness }.prefix(maxNodes))
        guard ideas.count >= 2 else { return nil }
        let sessionID = UUID()
        let tainted = material.derivedFromNeverSend

        var thoughts: [Thought] = []
        var nodeByIdea: [UUID: UUID] = [:]
        for idea in ideas {
            let thought = Thought(
                sessionID: sessionID, kind: .observation,
                content: "\(idea.title) is taking shape (ripeness \(Int(idea.ripeness))).",
                rationale: idea.manualTags.isEmpty ? "Drawn from the idea's current state." : "Themes: \(idea.manualTags.prefix(3).joined(separator: ", ")).",
                confidence: 0.45, relatedIdeaIDs: [idea.id], createdAt: now, derivedFromNeverSend: tainted
            )
            thoughts.append(thought)
            nodeByIdea[idea.id] = thought.id
        }

        // Edges from embedding proximity — the strongest real links the corpus already holds.
        var edges: [ThoughtEdge] = []
        var strongest: (a: IdeaSeed, b: IdeaSeed, score: Double)? = nil
        for i in ideas.indices {
            for j in (i + 1)..<ideas.count {
                let score = LocalEmbeddings.cosine(ideas[i].embedding, ideas[j].embedding)
                guard score >= 0.35, let from = nodeByIdea[ideas[i].id], let to = nodeByIdea[ideas[j].id] else { continue }
                let shared = sharedThemes(ideas[i], ideas[j])
                edges.append(ThoughtEdge(
                    sessionID: sessionID, fromThoughtID: from, toThoughtID: to,
                    type: score >= 0.55 ? .supports : .extends,
                    rationale: shared.isEmpty ? "Semantically close in concept space." : "Both touch \(shared.joined(separator: ", ")).",
                    strength: min(1, score), createdAt: now
                ))
                if strongest == nil || score > strongest!.score { strongest = (ideas[i], ideas[j], score) }
            }
        }

        var generated: [ExtractedSeed] = []
        if let pair = strongest {
            let hypothesis = Thought(
                sessionID: sessionID, kind: .hypothesis,
                content: "There may be one product that unifies \"\(pair.a.title)\" and \"\(pair.b.title)\".",
                rationale: "They are the closest pair in the current web.",
                confidence: 0.4, relatedIdeaIDs: [pair.a.id, pair.b.id], createdAt: now, derivedFromNeverSend: tainted
            )
            thoughts.append(hypothesis)
            generated = [ExtractedSeed(
                title: String("Bridge: \(pair.a.title) × \(pair.b.title)".prefix(70)),
                body: "A single tool that unifies \"\(pair.a.title)\" and \"\(pair.b.title)\" — the closest pair in the idea web. Smallest test: sketch the one workflow that needs both.",
                tags: Array(Set(pair.a.manualTags + pair.b.manualTags).prefix(5))
            )]
        }

        let reflection = MindReflection(
            weakestLink: "This cycle ran offline on embedding proximity, so the connections are statistical, not reasoned.",
            assumptions: ["Concept-space closeness implies a real product link."],
            processNote: "Add a cloud key to let the mind reason about the connections instead of only measuring them.",
            confidence: 0.4,
            nextToExplore: strongest.map { "Whether \"\($0.a.title)\" and \"\($0.b.title)\" truly belong together." } ?? "Capture more ideas to give the mind material."
        )
        let session = ThinkingSession(
            id: sessionID,
            focus: "Mapping the strongest links already in the web",
            startedAt: now, analysis: "Measured concept-space proximity across \(ideas.count) ideas and surfaced the closest links.",
            reflection: reflection, thoughtIDs: thoughts.map(\.id), edgeIDs: edges.map(\.id),
            generatedIdeaIDs: [], costUSD: 0, source: "local", derivedFromNeverSend: tainted
        )
        return CognitiveResult(session: session, thoughts: thoughts, edges: edges, generated: generated, responses: [])
    }

    // MARK: - Assembly

    private static func assemble(reason: ReasonOutput, sessionID: UUID, material: Material, confidence: Double, now: Date) -> (thoughts: [Thought], edges: [ThoughtEdge]) {
        // Nodes are observations, then hypotheses, then questions — a flat list the model's
        // connection indices point into.
        let tainted = material.derivedFromNeverSend
        func node(_ kind: ThoughtKind, _ content: String) -> Thought {
            Thought(sessionID: sessionID, kind: kind, content: content, confidence: confidence, createdAt: now, derivedFromNeverSend: tainted)
        }
        var nodes: [Thought] = []
        nodes += reason.observations.prefix(maxNodes).map { node(.observation, $0) }
        nodes += reason.hypotheses.prefix(maxNodes).map { node(.hypothesis, $0) }
        nodes += reason.questions.prefix(maxNodes).map { node(.question, $0) }

        // Edges reference node indices; clamp and skip anything out of range or self-looping.
        var edges: [ThoughtEdge] = []
        for connection in reason.connections.prefix(maxNodes * 2) {
            guard connection.from >= 0, connection.from < nodes.count,
                  connection.to >= 0, connection.to < nodes.count,
                  connection.from != connection.to else { continue }
            let type = ThoughtEdgeType(rawValue: connection.type) ?? .extends
            edges.append(ThoughtEdge(
                sessionID: sessionID,
                fromThoughtID: nodes[connection.from].id,
                toThoughtID: nodes[connection.to].id,
                type: type,
                rationale: connection.rationale,
                strength: connection.strength ?? 0.6,
                createdAt: now
            ))
        }
        return (nodes, edges)
    }

    // MARK: - Prompts

    private static let reasonInstruction = """
    You are a mind that thinks ACROSS a builder's ideas and any fresh external signals — \
    not idea by idea. Reason about the material: notice what is non-obvious, draw specific \
    connections between distinct items, and float hypotheses worth chasing. Then pick the \
    single most generative focus for this cycle.

    Return ONLY JSON:
    {
      "focus": "the one thing this cycle is really about",
      "summary": "2-3 sentences of what you reasoned through",
      "observations": ["specific things you noticed (max 6)"],
      "hypotheses": ["propositions worth testing (max 4)"],
      "questions": ["open threads to pull on (max 3)"],
      "connections": [{"from": <index>, "to": <index>, "type": "supports|contradicts|extends|questions|derivesFrom", "rationale": "why they connect", "strength": 0.0-1.0}]
    }
    "from"/"to" are indices into the concatenated list [observations, then hypotheses, then questions]. \
    Be specific and never generic. Skip a list if it has nothing real.
    """

    private static let generateInstruction = """
    From the reasoning below, propose ONE original, non-obvious idea worth building — it must \
    grow out of the CONNECTIONS, fit the builder, and be small enough for one person to prototype. \
    Not a summary of the material. Return ONLY JSON matching ExtractedSeed: \
    {"title": "<=70 chars", "body": "the idea, why the connection makes it non-obvious, and the single smallest test", "tags": ["3-5 lowercase themes"]}
    """

    private static let reflectInstruction = """
    You are the mind reflecting on the reasoning you just did. Critique the PROCESS, not the idea: \
    the single weakest link in the reasoning, the assumptions it quietly rested on, any connections \
    drawn too eagerly (pattern-matching, not real), whether you explored widely enough or overfit to \
    taste or repeated yourself, a calibrated confidence, and the one thread most worth pulling next.
    Return ONLY JSON:
    {"weakestLink":"...","assumptions":["..."],"spuriousConnections":["..."],"processNote":"...","confidence":0.0-1.0,"nextToExplore":"..."}
    """

    private static func reasoningSummary(_ reason: ReasonOutput) -> String {
        var parts = ["FOCUS: \(reason.focus)"]
        if !reason.observations.isEmpty { parts.append("OBSERVATIONS:\n" + reason.observations.map { "- \($0)" }.joined(separator: "\n")) }
        if !reason.hypotheses.isEmpty { parts.append("HYPOTHESES:\n" + reason.hypotheses.map { "- \($0)" }.joined(separator: "\n")) }
        if !reason.connections.isEmpty { parts.append("CONNECTIONS:\n" + reason.connections.prefix(8).map { "- \($0.rationale)" }.joined(separator: "\n")) }
        return parts.joined(separator: "\n\n")
    }

    private static func digest(_ material: Material) -> String {
        var parts: [String] = []
        if !material.ideas.isEmpty {
            let lines = material.ideas.prefix(14).map { idea -> String in
                let tags = idea.manualTags.isEmpty ? "" : " [\(idea.manualTags.prefix(4).joined(separator: ", "))]"
                return "- \(idea.title)\(tags): \(idea.body.prefix(140))"
            }
            parts.append("IDEAS:\n" + lines.joined(separator: "\n"))
        }
        if !material.signals.isEmpty {
            let lines = material.signals.prefix(6).map { "- \($0.title): \($0.summary.prefix(140))" }
            parts.append("FRESH SIGNALS:\n" + lines.joined(separator: "\n"))
        }
        if !material.priorThoughts.isEmpty {
            let lines = material.priorThoughts.prefix(8).map { "- (\($0.kind.label)) \($0.content.prefix(120))" }
            parts.append("WHAT YOU'VE THOUGHT BEFORE:\n" + lines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }

    /// Shared tags first, then shared content words ≥ 4 chars — a readable reason two ideas link.
    private static func sharedThemes(_ a: IdeaSeed, _ b: IdeaSeed) -> [String] {
        let aTags = Set(a.manualTags.map { $0.lowercased() })
        let bTags = Set(b.manualTags.map { $0.lowercased() })
        let shared = aTags.intersection(bTags)
        if !shared.isEmpty { return Array(shared).sorted().prefix(3).map { $0 } }
        let words = { (text: String) in Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 5 }) }
        return Array(words("\(a.title) \(a.body)").intersection(words("\(b.title) \(b.body)"))).sorted().prefix(3).map { $0 }
    }

    // MARK: - Parsing

    private struct ReasonOutput: Codable {
        var focus: String = ""
        var summary: String = ""
        var observations: [String] = []
        var hypotheses: [String] = []
        var questions: [String] = []
        var connections: [RawConnection] = []
    }

    private struct RawConnection: Codable {
        var from: Int
        var to: Int
        var type: String = "extends"
        var rationale: String = ""
        var strength: Double? = nil
    }

    private struct ReflectionOutput: Codable {
        var weakestLink: String = ""
        var assumptions: [String] = []
        var spuriousConnections: [String] = []
        var processNote: String = ""
        var confidence: Double = 0.5
        var nextToExplore: String = ""

        var asReflection: MindReflection {
            MindReflection(weakestLink: weakestLink, assumptions: assumptions, spuriousConnections: spuriousConnections, processNote: processNote, confidence: confidence, nextToExplore: nextToExplore)
        }
    }

    /// Tolerant JSON extraction — strips code fences, then decodes the first {...} / [...] block.
    private static func decode<T: Decodable>(_ type: T.Type, from output: String) -> T? {
        var text = output
        if let start = text.range(of: "```json")?.upperBound, let end = text[start...].range(of: "```")?.lowerBound {
            text = String(text[start..<end])
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            return try? JSONSupport.decoder.decode(T.self, from: Data(text[start...end].utf8))
        }
        return nil
    }
}
