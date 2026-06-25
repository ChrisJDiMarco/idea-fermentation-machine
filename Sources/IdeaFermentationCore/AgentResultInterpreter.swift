import Foundation

enum AgentResultInterpreter {
    static func tagResult(for idea: IdeaSeed, output: String? = nil) -> TagResult {
        if let decoded = decode(TagResult.self, from: output) { return decoded }
        let words = TextHashing.normalized("\(idea.title) \(idea.body)")
            .split(separator: " ")
            .map(String.init)
        let tags = Array(NSCountedSet(array: words).allObjects.compactMap { $0 as? String }
            .filter { $0.count > 3 }
            .prefix(5))
        return TagResult(tags: tags, summary: String(idea.body.prefix(220)))
    }

    static func sourceSummary(for source: SourceItem, ideas: [IdeaSeed], output: String? = nil) -> SourceSummary {
        if let decoded = decode(SourceSummary.self, from: output) { return decoded }
        let query = "\(source.title) \(source.body)"
        let sourceVector = LocalEmbeddings.embed(query)
        let linked = ideas
            .map { (idea: $0, score: LocalEmbeddings.cosine($0.embedding, sourceVector)) }
            .filter { $0.score > 0.12 }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map(\.idea.id)
        let tags = TextHashing.normalized(query)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 4 }
            .prefix(6)
        return SourceSummary(summary: String(source.body.prefix(500)), tags: Array(tags), linkedIdeaIDs: Array(linked))
    }

    static func connections(for idea: IdeaSeed, candidates: [IdeaSeed], output: String? = nil) -> [ConnectionCandidate] {
        if let decoded = decode([ConnectionCandidate].self, from: output) { return decoded }
        return candidates
            .filter { $0.id != idea.id }
            .map { other in
                (idea: other, score: LocalEmbeddings.cosine(idea.embedding, other.embedding))
            }
            .filter { $0.score > 0.16 }
            .sorted { $0.score > $1.score }
            .prefix(4)
            .map {
                ConnectionCandidate(
                    fromID: idea.id,
                    toID: $0.idea.id,
                    explanation: connectionExplanation(idea: idea, other: $0.idea),
                    confidence: min(1, $0.score)
                )
            }
    }

    /// Names the concrete themes two ideas share so the connection reads as an
    /// insight ("both explore ambient, memory") instead of an opaque "shared
    /// signal". Prefers shared tags, then shared content words.
    private static func connectionExplanation(idea: IdeaSeed, other: IdeaSeed) -> String {
        let themes = sharedThemes(idea, other)
        guard !themes.isEmpty else {
            return "\"\(idea.title)\" and \"\(other.title)\" share a strong underlying signal."
        }
        return "\"\(idea.title)\" and \"\(other.title)\" both explore \(themes.joined(separator: ", "))."
    }

    private static func sharedThemes(_ first: IdeaSeed, _ second: IdeaSeed) -> [String] {
        let firstTags = Set(first.manualTags.map { $0.lowercased() })
        let secondTags = Set(second.manualTags.map { $0.lowercased() })
        let sharedTags = firstTags.intersection(secondTags)
        if !sharedTags.isEmpty {
            return Array(sharedTags).sorted().prefix(3).map { $0 }
        }
        let shared = displayWords("\(first.title) \(first.body)").intersection(displayWords("\(second.title) \(second.body)"))
        return Array(shared).sorted().prefix(3).map { $0 }
    }

    /// Human-readable content words (no stemming, length ≥ 4) for explanations.
    private static func displayWords(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !Tokenizer.stopwords.contains($0) })
    }

    static func critique(for idea: IdeaSeed, output: String? = nil) -> CritiqueResult {
        if let decoded = decode(CritiqueResult.self, from: output) { return decoded }

        // Derive objections from the idea's actual signals so the critique is
        // specific to *this* idea rather than generic filler.
        var assumptions = ["The target user feels this problem often enough to change behavior."]
        var risks: [String] = []
        var contradictions: [String] = []

        if idea.sourceIDs.isEmpty {
            risks.append("Evidence is thin — no sources are linked yet. Capture one before building.")
        } else if idea.sourceIDs.count < 3 {
            risks.append("Only \(idea.sourceIDs.count) source(s) back this; the evidence base may be biased toward recent captures.")
        }
        if idea.body.count < 140 {
            risks.append("The idea is under-described — clarity will suffer until the core loop is written down.")
            assumptions.append("The unstated details resolve in the obvious way.")
        }
        if idea.manualTags.isEmpty {
            risks.append("No themes are tagged, so cross-pollination and pattern detection will miss this idea.")
        }
        if idea.feasibility < 45 {
            contradictions.append("Ambition outruns feasibility (\(Int(idea.feasibility))) — the smallest test may still be too large.")
        }
        if idea.novelty >= 65 && idea.personalResonance < 40 {
            contradictions.append("It scores novel (\(Int(idea.novelty))) but low on personal resonance (\(Int(idea.personalResonance))) — interesting, but is it yours to build?")
        }
        if idea.novelty < 40 && idea.feasibility >= 70 {
            contradictions.append("Easy to build but not very novel — what makes this worth your attention over the obvious alternative?")
        }

        if risks.isEmpty { risks = ["Evidence may still be biased toward recent captures."] }
        if contradictions.isEmpty { contradictions = ["Novelty and usability may be pulling in opposite directions."] }
        return CritiqueResult(assumptions: assumptions, risks: risks, contradictions: contradictions)
    }

    static func ripeness(for idea: IdeaSeed, output: String? = nil) -> RipenessResult {
        if let decoded = decode(RipenessResult.self, from: output) { return decoded }
        return RipenessResult(
            novelty: idea.novelty,
            clarity: localClarity(for: idea),
            evidence: idea.evidence,
            personalResonance: idea.personalResonance,
            feasibility: idea.feasibility,
            timing: idea.timing
        )
    }

    /// Clarity proxy from body length, shared between the local fermentation pass
    /// and the persisted ripeness score so the two never disagree.
    static func localClarity(for idea: IdeaSeed) -> Double {
        min(100, max(20, Double(idea.body.count) / 6))
    }

    static func brief(for idea: IdeaSeed, output: String? = nil) -> PrototypeBriefDraft {
        if let decoded = decode(PrototypeBriefDraft.self, from: output) { return decoded }
        let actions = [
            "Define the smallest user-facing workflow.",
            "Build a one-day prototype around the core loop.",
            "Test with one real user or one real personal workflow."
        ]
        let markdown = """
        # \(idea.title)

        **Audience:** People who feel the problem described in this idea.

        **MVP Scope:** \(String(idea.body.prefix(260)))

        **Risks:** Evidence, retention, and scope creep.

        **Next actions:**
        \(actions.map { "- \($0)" }.joined(separator: "\n"))
        """
        return PrototypeBriefDraft(audience: "Early users with this workflow pain", mvpScope: String(idea.body.prefix(260)), risks: "Evidence, retention, and scope creep.", nextActions: actions, markdown: markdown)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from output: String?) -> T? {
        guard var output else { return nil }
        if let start = output.range(of: "```json")?.upperBound, let end = output[start...].range(of: "```")?.lowerBound {
            output = String(output[start..<end])
        }
        if let start = output.firstIndex(of: "{"), let end = output.lastIndex(of: "}") {
            return try? JSONSupport.decoder.decode(T.self, from: Data(output[start...end].utf8))
        }
        if let start = output.firstIndex(of: "["), let end = output.lastIndex(of: "]") {
            return try? JSONSupport.decoder.decode(T.self, from: Data(output[start...end].utf8))
        }
        return nil
    }
}

