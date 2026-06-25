import Foundation

/// Ideas whose content may derive from a never-send source, checked in BOTH link
/// directions (idea→source via sourceIDs, and source→idea via linkedIdeaIDs) so the
/// redaction does not depend on a single fragile link being maintained. Used by every
/// cloud-bound digest to keep protected content off the wire.
func neverSendDerivedIdeaIDs(ideas: [IdeaSeed], sources: [SourceItem]) -> Set<UUID> {
    let neverSend = sources.filter(\.neverSendToCloud)
    guard !neverSend.isEmpty else { return [] }
    let neverSendSourceIDs = Set(neverSend.map(\.id))
    let neverSendLinkedIdeaIDs = Set(neverSend.flatMap(\.linkedIdeaIDs))
    return Set(
        ideas
            .filter { !Set($0.sourceIDs).isDisjoint(with: neverSendSourceIDs) || neverSendLinkedIdeaIDs.contains($0.id) }
            .map(\.id)
    )
}

/// The kinds of cross-idea observation the reasoning pass can surface. Each is a
/// portfolio-level insight — something only visible when you look at every idea at
/// once, not idea by idea.
public enum PortfolioInsightKind: String, Codable, CaseIterable, Sendable {
    case buildNext
    case merge
    case contradiction
    case gap
    case theme

    public var title: String {
        switch self {
        case .buildNext: "Build Next"
        case .merge: "Worth Merging"
        case .contradiction: "Tension"
        case .gap: "Blind Spot"
        case .theme: "Emerging Theme"
        }
    }

    public var symbol: String {
        switch self {
        case .buildNext: "bolt.fill"
        case .merge: "arrow.triangle.merge"
        case .contradiction: "arrow.left.arrow.right"
        case .gap: "circle.dashed"
        case .theme: "sparkles"
        }
    }
}

/// One cross-idea observation: a headline, the reasoning behind it, and the ideas it
/// is about (by title, so the UI can link to them).
public struct PortfolioInsight: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: PortfolioInsightKind
    public var headline: String
    public var reasoning: String
    public var relatedIdeaTitles: [String]
    public var priority: Int

    public init(
        id: UUID = UUID(),
        kind: PortfolioInsightKind,
        headline: String,
        reasoning: String,
        relatedIdeaTitles: [String] = [],
        priority: Int = 3
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.reasoning = reasoning
        self.relatedIdeaTitles = relatedIdeaTitles
        self.priority = priority
    }
}

/// The output of one reasoning pass over the whole portfolio.
public struct PortfolioReport: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var summary: String
    public var insights: [PortfolioInsight]
    public var source: String
    public var ideaCount: Int

    public init(generatedAt: Date, summary: String, insights: [PortfolioInsight], source: String, ideaCount: Int) {
        self.generatedAt = generatedAt
        self.summary = summary
        self.insights = insights
        self.source = source
        self.ideaCount = ideaCount
    }

    public var isEmpty: Bool { summary.isEmpty && insights.isEmpty }

    public func insights(of kind: PortfolioInsightKind) -> [PortfolioInsight] {
        insights.filter { $0.kind == kind }.sorted { ($0.priority, $0.headline) < ($1.priority, $1.headline) }
    }

    public var buildNext: PortfolioInsight? { insights(of: .buildNext).first }

    /// Everything except the single build-next hero, ordered for display.
    public var supportingInsights: [PortfolioInsight] {
        let order: [PortfolioInsightKind] = [.gap, .contradiction, .merge, .theme]
        return order.flatMap { insights(of: $0) }
    }
}

/// Reasons across the ENTIRE idea portfolio at once — the cross-idea pass. The cloud
/// path produces genuine reasoning (merges, tensions, blind spots, what-to-build); the
/// local path is a deterministic heuristic fallback so there is always a report.
public enum PortfolioReasoner {
    /// Upper bound on the idea count the O(n²) local clustering will scan, so the
    /// on-@MainActor fallback can't freeze the UI on a very large portfolio.
    static let localWorkingSetCap = 120

    // MARK: Cloud reasoning

    public static func reason(
        ideas: [IdeaSeed],
        connections: [IdeaConnection],
        sources: [SourceItem],
        outcomes: [BuildOutcome],
        taste: TasteModel,
        profile: AutonomyProfile,
        tasteProfile: TasteProfile? = nil,
        provider: any LLMProvider,
        model: LLMModel,
        apiKey: String,
        now: Date
    ) async throws -> (report: PortfolioReport, response: LLMResponse)? {
        let request = LLMRequest(
            taskClass: .prototypeBrief,
            prompt: prompt(profile: profile, tasteProfile: tasteProfile),
            input: digest(ideas: ideas, connections: connections, sources: sources, outcomes: outcomes, taste: taste),
            maxOutputTokens: 1_300
        )
        let response = try await provider.send(request, model: model, apiKey: apiKey)
        guard let report = decode(response.text, ideas: ideas, source: "cloud · \(provider.providerName)", now: now) else {
            return nil
        }
        return (report, response)
    }

    static func prompt(profile: AutonomyProfile, tasteProfile: TasteProfile? = nil) -> String {
        let learnedTaste = (tasteProfile?.promptContext).map { "\n\nLearned taste (distilled from real decisions):\n\($0)" } ?? ""
        return """
        You are the chief of staff for a solo builder's idea portfolio. You are handed \
        their ENTIRE set of ideas — each with status, ripeness, tags, existing \
        connections, and what they have actually built. Reason ACROSS the whole \
        portfolio, not idea by idea. Surface the non-obvious observations only someone \
        who can see everything at once would make.

        Produce these kinds of insight:
        - "buildNext": the SINGLE idea (or one tight combination) you would build next, \
        with a sharp reason grounded in the portfolio — taste, momentum, timing, or what \
        is missing. Exactly one, when anything is buildable.
        - "merge": two or more ideas that are really the same idea or should be combined.
        - "contradiction": ideas that pull against each other, or against the builder's \
        revealed taste and goals.
        - "gap": a blind spot — an angle or capability the portfolio clearly lacks given \
        its own themes.
        - "theme": an emergent through-line across several ideas the builder may not have \
        named yet.

        Builder goals: \(profile.goals.isEmpty ? "(unspecified)" : profile.goals)
        Builder taste notes: \(profile.tasteNotes.isEmpty ? "(unspecified)" : profile.tasteNotes)\(learnedTaste)

        Rules: cite ideas by their EXACT title. Be specific and opinionated — never \
        generic filler. Skip any category that has nothing real to say. At most two of \
        each except buildNext. Lower priority number = more important.

        Return ONLY JSON:
        {"summary":"2-3 sentences on the shape of the whole portfolio","insights":[\
        {"kind":"buildNext|merge|contradiction|gap|theme","headline":"<=80 chars",\
        "reasoning":"specific, cites exact titles","ideas":["Exact Title"],"priority":1}]}
        """
    }

    /// A compact, privacy-aware portrait of the portfolio. Bodies of ideas that draw on
    /// a never-send source are omitted; titles/tags/status/ripeness (the builder's own
    /// words and metadata) still go so the reasoning has something to chew on.
    static func digest(
        ideas: [IdeaSeed],
        connections: [IdeaConnection],
        sources: [SourceItem],
        outcomes: [BuildOutcome],
        taste: TasteModel
    ) -> String {
        let neverSendIdeaIDs = neverSendDerivedIdeaIDs(ideas: ideas, sources: sources)
        let titles = Dictionary(uniqueKeysWithValues: ideas.map { ($0.id, $0.title) })
        // A never-send-derived idea's title/tags may themselves be protected content, so
        // withhold them too — not just the body.
        func safeTitle(_ id: UUID) -> String { neverSendIdeaIDs.contains(id) ? "[private idea]" : (titles[id] ?? "?") }

        var lines: [String] = ["IDEAS (\(ideas.count) total):"]
        for idea in ideas.prefix(60) {
            if neverSendIdeaIDs.contains(idea.id) {
                lines.append("- [private idea] [\(idea.status.rawValue), ripeness \(Int(idea.ripeness))]")
                continue
            }
            let tags = idea.manualTags.isEmpty ? "" : " — tags: \(idea.manualTags.joined(separator: ", "))"
            lines.append("- \"\(idea.title)\" [\(idea.status.rawValue), ripeness \(Int(idea.ripeness))]\(tags) — \(snippet(idea.body, 130))")
        }

        let strong = connections
            .filter { $0.confidence >= 0.4 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(20)
        if !strong.isEmpty {
            lines.append("\nALREADY-FOUND CONNECTIONS:")
            for connection in strong {
                lines.append("- \(safeTitle(connection.fromID)) ↔ \(safeTitle(connection.toID))")
            }
        }

        if !outcomes.isEmpty {
            lines.append("\nWHAT THE BUILDER HAS ACTUALLY BUILT:")
            for outcome in outcomes.sorted(by: { $0.createdAt > $1.createdAt }).prefix(8) {
                lines.append("- \(safeTitle(outcome.ideaID)): \(outcome.result.title)")
            }
        }

        let themes = taste.topThemes(limit: 6)
        if !themes.liked.isEmpty {
            lines.append("\nBUILDER LEANS TOWARD: \(themes.liked.map(\.token).joined(separator: ", "))")
        }
        if !themes.disliked.isEmpty {
            lines.append("BUILDER LEANS AWAY FROM: \(themes.disliked.map(\.token).joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    static func decode(_ output: String, ideas: [IdeaSeed], source: String, now: Date) -> PortfolioReport? {
        var text = output
        if let start = text.range(of: "```json")?.upperBound,
           let end = text[start...].range(of: "```")?.lowerBound {
            text = String(text[start..<end])
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        guard let dto = try? JSONSupport.decoder.decode(ReportDTO.self, from: Data(text[start...end].utf8)) else { return nil }

        let validTitles = Set(ideas.map { $0.title.lowercased() })
        let parsed = (dto.insights ?? []).enumerated().compactMap { index, raw -> PortfolioInsight? in
            let headline = (raw.headline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let reasoning = (raw.reasoning ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !headline.isEmpty || !reasoning.isEmpty else { return nil }
            // Keep only cited titles that match a real idea; if none match, keep what the
            // model gave so the card still reads, but the UI just won't link them.
            let cited = raw.ideas ?? []
            let matched = cited.filter { validTitles.contains($0.lowercased()) }
            return PortfolioInsight(
                kind: normalizeKind(raw.kind),
                headline: headline.isEmpty ? reasoning : headline,
                reasoning: reasoning,
                relatedIdeaTitles: matched.isEmpty ? cited : matched,
                priority: raw.priority ?? (index + 1)
            )
        }

        // Enforce the prompt's contract on untrusted output: exactly one buildNext and
        // at most two of every other kind, chosen by priority with a stable tie-break so
        // the same response always renders identically.
        var insights: [PortfolioInsight] = []
        for kind in PortfolioInsightKind.allCases {
            let ofKind = parsed
                .filter { $0.kind == kind }
                .sorted { ($0.priority, $0.headline) < ($1.priority, $1.headline) }
            insights += ofKind.prefix(kind == .buildNext ? 1 : 2)
        }

        let summary = (dto.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !insights.isEmpty || !summary.isEmpty else { return nil }
        return PortfolioReport(generatedAt: now, summary: summary, insights: insights, source: source, ideaCount: ideas.count)
    }

    static func normalizeKind(_ raw: String?) -> PortfolioInsightKind {
        let key = (raw ?? "")
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        switch key {
        case "buildnext", "build", "next", "buildable": return .buildNext
        case "merge", "combine", "duplicate", "consolidate": return .merge
        case "contradiction", "tension", "conflict", "clash": return .contradiction
        case "gap", "blindspot", "missing", "hole": return .gap
        default: return .theme
        }
    }

    private struct ReportDTO: Codable {
        var summary: String?
        var insights: [InsightDTO]?

        struct InsightDTO: Codable {
            var kind: String?
            var headline: String?
            var reasoning: String?
            var ideas: [String]?
            var priority: Int?
        }
    }

    // MARK: Local heuristic fallback

    /// A deterministic cross-idea report for when there is no cloud key, the spend cap
    /// is reached, or the operator is offline. Weaker than the reasoned cloud pass, but
    /// still surfaces real structure: the strongest build candidate, near-duplicate
    /// pairs, the largest theme cluster, and an obvious pipeline gap.
    public static func localReport(
        ideas allIdeas: [IdeaSeed],
        connections: [IdeaConnection],
        taste: TasteModel,
        now: Date
    ) -> PortfolioReport {
        guard !allIdeas.isEmpty else {
            return PortfolioReport(generatedAt: now, summary: "", insights: [], source: "local heuristics", ideaCount: 0)
        }

        // The pair/cluster passes are O(n²) on @MainActor, so bound the working set to
        // keep a large portfolio from freezing the UI. The reported count stays true.
        let ideas = Array(allIdeas.prefix(localWorkingSetCap))
        let totalCount = allIdeas.count
        var insights: [PortfolioInsight] = []

        // Build-next: the idea with the best blend of ripeness and learned taste.
        let ranked = ideas.sorted { localScore($0, taste: taste) > localScore($1, taste: taste) }
        if let top = ranked.first(where: { $0.status == .ready }) ?? ranked.first {
            insights.append(PortfolioInsight(
                kind: .buildNext,
                headline: top.title,
                reasoning: "Strongest blend of ripeness (\(Int(top.ripeness))) and your learned taste among \(ideas.count) ideas. \(top.status == .ready ? "It is already marked ready." : "Mature it a little further, then build.")",
                relatedIdeaTitles: [top.title],
                priority: 1
            ))
        }

        // Merge: the most semantically similar pair, if they are near-duplicates.
        if let pair = nearestPair(ideas), pair.score >= 0.80 {
            insights.append(PortfolioInsight(
                kind: .merge,
                headline: "\(pair.a.title)  ≈  \(pair.b.title)",
                reasoning: "These two are \(Int(pair.score * 100))% semantically similar — they may be one idea wearing two titles.",
                relatedIdeaTitles: [pair.a.title, pair.b.title],
                priority: 2
            ))
        }

        // Theme: the largest semantic cluster.
        if let cluster = largestCluster(ideas), cluster.count >= 3 {
            let label = clusterLabel(cluster)
            insights.append(PortfolioInsight(
                kind: .theme,
                headline: label,
                reasoning: "\(cluster.count) ideas cluster tightly around this — a through-line worth naming and pushing on.",
                relatedIdeaTitles: cluster.prefix(5).map(\.title),
                priority: 3
            ))
        }

        // Gap: an obvious pipeline imbalance (counted across the full portfolio).
        let ready = allIdeas.filter { $0.status == .ready }.count
        let fermenting = allIdeas.filter { $0.status == .fermenting || $0.status == .inbox }.count
        if ready == 0 && fermenting >= 3 {
            insights.append(PortfolioInsight(
                kind: .gap,
                headline: "Nothing has reached Ready",
                reasoning: "\(fermenting) ideas are still early and none are ready to build. The portfolio is all intake, no output — pick one to push to Ready.",
                priority: 4
            ))
        }

        let themeWord = largestCluster(ideas).map(clusterLabel) ?? "mixed themes"
        let readyLine = ready > 0 ? "\(ready) ready to build" : "none ready yet"
        let summary = "\(totalCount) ideas, \(readyLine). Strongest current pull: \(themeWord). (Add a cloud key for the full reasoned synthesis.)"
        return PortfolioReport(generatedAt: now, summary: summary, insights: insights, source: "local heuristics", ideaCount: totalCount)
    }

    private static func localScore(_ idea: IdeaSeed, taste: TasteModel) -> Double {
        let affinity = taste.affinity(for: TasteModel.themeTerms(title: idea.title, tags: idea.manualTags))
        return idea.ripeness / 100.0 + affinity * 0.5
    }

    private static func nearestPair(_ ideas: [IdeaSeed]) -> (a: IdeaSeed, b: IdeaSeed, score: Double)? {
        guard ideas.count >= 2 else { return nil }
        var best: (a: IdeaSeed, b: IdeaSeed, score: Double)?
        for i in 0..<ideas.count {
            for j in (i + 1)..<ideas.count {
                let score = LocalEmbeddings.cosine(ideas[i].embedding, ideas[j].embedding)
                if score > (best?.score ?? -1) {
                    best = (ideas[i], ideas[j], score)
                }
            }
        }
        return best
    }

    private static func largestCluster(_ ideas: [IdeaSeed]) -> [IdeaSeed]? {
        guard ideas.count >= 2 else { return nil }
        let threshold = LocalEmbeddings.strongMatchFloor
        var best: [IdeaSeed] = []
        for seed in ideas {
            let cluster = ideas.filter { LocalEmbeddings.cosine(seed.embedding, $0.embedding) >= threshold }
            if cluster.count > best.count { best = cluster }
        }
        return best.count >= 2 ? best : nil
    }

    private static func clusterLabel(_ cluster: [IdeaSeed]) -> String {
        let tagCounts = cluster
            .flatMap(\.manualTags)
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        if let top = tagCounts.max(by: { $0.value < $1.value })?.key {
            return top.capitalized
        }
        // Fall back to the most common distinctive title word.
        let words = cluster
            .flatMap { TasteModel.themeTerms(title: $0.title, tags: []) }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return words.max(by: { $0.value < $1.value })?.key.capitalized ?? "Shared theme"
    }

    private static func snippet(_ text: String, _ limit: Int) -> String {
        let clean = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return "\(clean.prefix(max(0, limit - 1)))…"
    }
}
