import Foundation

/// One scoring criterion in the builder's taste rubric — a mechanism or pattern that
/// makes an idea more (or less) "them", in their own revealed terms. This is the unit
/// that turns taste from a list of liked words into something you can reason against.
public struct TasteCriterion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// +1 = draws them in, −1 = pushes them away.
    public var direction: Int
    public var note: String

    public init(id: UUID = UUID(), name: String, direction: Int, note: String = "") {
        self.id = id
        self.name = name
        self.direction = direction
        self.note = note
    }

    public var isLike: Bool { direction >= 0 }
}

/// A distilled, conceptual model of the builder's taste: a short natural-language
/// portrait plus a rubric of criteria, learned from what they actually committed to
/// and abandoned. Unlike `TasteModel` (a bag of liked/disliked WORDS), this captures
/// the underlying mechanisms — "tools that remove a step", not "productivity" — and is
/// what the cloud judgment agents reason against.
public struct TasteProfile: Codable, Equatable, Sendable {
    public var portrait: String
    public var criteria: [TasteCriterion]
    public var generatedAt: Date
    public var source: String
    public var decisionCount: Int

    public init(portrait: String, criteria: [TasteCriterion], generatedAt: Date, source: String, decisionCount: Int) {
        self.portrait = portrait
        self.criteria = criteria
        self.generatedAt = generatedAt
        self.source = source
        self.decisionCount = decisionCount
    }

    public var isEmpty: Bool { portrait.isEmpty && criteria.isEmpty }
    public var likes: [TasteCriterion] { criteria.filter(\.isLike) }
    public var avoids: [TasteCriterion] { criteria.filter { !$0.isLike } }

    /// A compact rendering for use as context inside another agent's prompt, so cloud
    /// judgment (critique, scout synthesis, portfolio reasoning) reasons against the
    /// builder's actual taste rather than a thin word list.
    public var promptContext: String {
        guard !isEmpty else { return "" }
        var lines: [String] = []
        if !portrait.isEmpty { lines.append("Taste portrait: \(portrait)") }
        if !likes.isEmpty { lines.append("Drawn to: " + likes.map(\.name).joined(separator: "; ")) }
        if !avoids.isEmpty { lines.append("Pushed away by: " + avoids.map(\.name).joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }
}

/// Distills a `TasteProfile` from the builder's decisions. The cloud path writes a
/// reasoned portrait + rubric; the local path derives an honest (if blunter) portrait
/// from the learned theme weights so there is always something to show.
public enum TasteDistiller {
    // MARK: Cloud distillation

    public static func distill(
        liked: [IdeaSeed],
        disliked: [IdeaSeed],
        outcomes: [BuildOutcome],
        sources: [SourceItem],
        existingNotes: String,
        provider: any LLMProvider,
        model: LLMModel,
        apiKey: String,
        now: Date
    ) async throws -> (profile: TasteProfile, response: LLMResponse)? {
        let decisionCount = liked.count + disliked.count
        let request = LLMRequest(
            taskClass: .prototypeBrief,
            prompt: prompt(existingNotes: existingNotes),
            input: digest(liked: liked, disliked: disliked, outcomes: outcomes, sources: sources),
            maxOutputTokens: 700
        )
        let response = try await provider.send(request, model: model, apiKey: apiKey)
        guard let profile = decode(response.text, source: "cloud · \(provider.providerName)", decisionCount: decisionCount, now: now) else {
            return nil
        }
        return (profile, response)
    }

    static func prompt(existingNotes: String) -> String {
        """
        You are distilling a solo builder's TASTE from their real decisions — the ideas \
        they committed to and built versus the ones they abandoned. Infer the underlying \
        PATTERN, not the surface topic.

        Write:
        1. A 2-4 sentence "portrait" of what genuinely pulls this builder in — the \
        MECHANISMS, shapes, and aesthetics they favor (e.g. "tools that remove a step \
        from an existing workflow" or "single-purpose utilities over platforms"), not \
        broad topic words like "productivity" or "AI".
        2. A rubric of 3-6 "criteria" you could apply to a NEW idea to judge how much it \
        fits this person — each marked "like" (draws them in) or "avoid" (pushes them \
        away), with a one-line note.

        \(existingNotes.isEmpty ? "" : "The builder also wrote this about themselves: \(existingNotes)\n")
        Be specific and grounded in the decisions below. Do not invent preferences with \
        no support. Return ONLY JSON:
        {"portrait":"...","criteria":[{"name":"<short>","direction":"like|avoid","note":"<one line>"}]}
        """
    }

    /// Privacy-aware: bodies of ideas derived from a never-send source are withheld;
    /// titles and tags (the builder's own words) and outcomes still go.
    static func digest(liked: [IdeaSeed], disliked: [IdeaSeed], outcomes: [BuildOutcome], sources: [SourceItem]) -> String {
        // A never-send-derived idea may have a title and tags taken from the protected
        // source (a captured page's title; tags mined from its body), so withhold the
        // WHOLE line, not just the body. Local storage keeps the content; the cloud gets
        // a placeholder.
        let redacted = neverSendDerivedIdeaIDs(ideas: liked + disliked, sources: sources)
        func line(_ idea: IdeaSeed) -> String {
            guard !redacted.contains(idea.id) else { return "- [private idea — content withheld]" }
            let tags = idea.manualTags.isEmpty ? "" : " — tags: \(idea.manualTags.joined(separator: ", "))"
            return "- \"\(idea.title)\"\(tags) — \(snippet(idea.body, 120))"
        }

        var lines: [String] = []
        lines.append("COMMITTED TO / BUILT (liked):")
        lines += liked.isEmpty ? ["- (none yet)"] : liked.prefix(25).map(line)
        lines.append("\nABANDONED / ARCHIVED (disliked):")
        lines += disliked.isEmpty ? ["- (none yet)"] : disliked.prefix(25).map(line)

        if !outcomes.isEmpty {
            lines.append("\nBUILD OUTCOMES:")
            let titles = Dictionary(uniqueKeysWithValues: (liked + disliked).map { ($0.id, $0.title) })
            for outcome in outcomes.sorted(by: { $0.createdAt > $1.createdAt }).prefix(10) {
                let title = redacted.contains(outcome.ideaID) ? "[private idea]" : (titles[outcome.ideaID] ?? "An idea")
                lines.append("- \(title): \(outcome.result.title)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func decode(_ output: String, source: String, decisionCount: Int, now: Date) -> TasteProfile? {
        var text = output
        if let start = text.range(of: "```json")?.upperBound,
           let end = text[start...].range(of: "```")?.lowerBound {
            text = String(text[start..<end])
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        guard let dto = try? JSONSupport.decoder.decode(ProfileDTO.self, from: Data(text[start...end].utf8)) else { return nil }

        // Bound untrusted output so a runaway response can't be stored verbatim and
        // re-rendered into every downstream prompt.
        let portrait = String((dto.portrait ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(700))
        let criteria = (dto.criteria ?? []).compactMap { raw -> TasteCriterion? in
            let name = String((raw.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            guard !name.isEmpty else { return nil }
            let note = String((raw.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
            return TasteCriterion(name: name, direction: directionValue(raw.direction), note: note)
        }
        guard !portrait.isEmpty || !criteria.isEmpty else { return nil }
        return TasteProfile(portrait: portrait, criteria: Array(criteria.prefix(8)), generatedAt: now, source: source, decisionCount: decisionCount)
    }

    private static func directionValue(_ raw: String?) -> Int {
        let key = (raw ?? "").lowercased()
        // Check the negative vocabulary first so "not a like", "dislike", "anti", etc.
        // can't be swallowed by a naive positive default.
        let avoidTokens = ["avoid", "dislike", "away", "negative", "anti", "against", "repel", "-1", "minus"]
        if avoidTokens.contains(where: key.contains) || key.hasPrefix("-") { return -1 }
        let likeTokens = ["like", "draw", "positive", "favor", "toward", "attract", "+1", "plus", "pull"]
        if likeTokens.contains(where: key.contains) { return 1 }
        // Unclear → treat as a like (the default), but only after explicit avoid lost.
        return 1
    }

    private struct ProfileDTO: Codable {
        var portrait: String?
        var criteria: [CriterionDTO]?
        struct CriterionDTO: Codable {
            var name: String?
            var direction: String?
            var note: String?
        }
    }

    // MARK: Local fallback

    /// A blunt but honest portrait from the learned theme weights — used when there is
    /// no cloud key, the cap is reached, or the operator is offline.
    public static func localProfile(taste: TasteModel, decisionCount: Int, now: Date) -> TasteProfile {
        let themes = taste.topThemes(limit: 6)
        let liked = themes.liked.map(\.token)
        let disliked = themes.disliked.map(\.token)

        var portrait = ""
        if !liked.isEmpty {
            portrait = "You gravitate toward " + phrase(liked) + "."
        }
        if !disliked.isEmpty {
            portrait += (portrait.isEmpty ? "You tend to drop " : " You tend to drop ") + phrase(disliked) + "."
        }
        if portrait.isEmpty {
            portrait = "Not enough decisions yet to describe a taste — mark ideas Ready, build, or archive to teach it."
        } else {
            portrait += " (Add a cloud key for a reasoned portrait of why.)"
        }

        var criteria = liked.map { TasteCriterion(name: $0.capitalized, direction: 1, note: "A theme you keep committing to.") }
        criteria += disliked.map { TasteCriterion(name: $0.capitalized, direction: -1, note: "A theme you keep dropping.") }

        return TasteProfile(portrait: portrait, criteria: Array(criteria.prefix(8)), generatedAt: now, source: "local heuristics", decisionCount: decisionCount)
    }

    private static func phrase(_ words: [String]) -> String {
        let shown = words.prefix(4).map { $0 }
        switch shown.count {
        case 0: return "a range of things"
        case 1: return shown[0]
        case 2: return "\(shown[0]) and \(shown[1])"
        default: return shown.dropLast().joined(separator: ", ") + ", and " + (shown.last ?? "")
        }
    }

    private static func snippet(_ text: String, _ limit: Int) -> String {
        let clean = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return "\(clean.prefix(max(0, limit - 1)))…"
    }
}
