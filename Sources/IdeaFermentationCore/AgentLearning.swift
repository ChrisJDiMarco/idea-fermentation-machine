import Foundation

public enum AgentLearning {
    public static func promptContext(
        ideas: [IdeaSeed],
        sources: [SourceItem],
        logs: [AgentRunLog],
        jobs: [FermentationJob],
        connections: [IdeaConnection],
        outcomes: [BuildOutcome] = [],
        limit: Int = 6,
        maxCharacters: Int = 1_200
    ) -> String {
        let ideaTitles = Dictionary(uniqueKeysWithValues: ideas.map { ($0.id, $0.title) })
        var notes: [String] = []

        // Defense in depth: an idea whose evidence includes a never-send source may
        // carry source-derived text in its body, so keep that body out of the cloud
        // digest. The idea's title still goes (the operator's own words), but the body
        // is redacted for these ideas. Checked in both link directions.
        let neverSendIdeaIDs = neverSendDerivedIdeaIDs(ideas: ideas, sources: sources)

        notes += jobs
            .filter { $0.status == .failed && ($0.lastError?.isEmpty == false) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(2)
            .map { "Failure pattern: \($0.taskClass.rawValue) failed with \(trim($0.lastError ?? "", to: 120))." }

        // Build outcomes are the strongest lessons: what the operator actually built
        // and how it went. They lead the digest.
        let outcomeIdeaIDs = Set(outcomes.map(\.ideaID))
        notes += outcomes
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { outcome in
                let title = ideaTitles[outcome.ideaID] ?? "Idea"
                let lesson = outcome.note.isEmpty ? "" : " — \(trim(outcome.note, to: 120))"
                return "Build outcome: \(outcome.result.title) — \(title)\(lesson)."
            }

        notes += ideas
            .filter { $0.status == .archived && !outcomeIdeaIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { idea in
                let tags = idea.manualTags.isEmpty ? "" : " Themes: \(idea.manualTags.joined(separator: ", "))."
                let body = neverSendIdeaIDs.contains(idea.id) ? "[private]" : trim(idea.body, to: 140)
                return "Archive lesson: \(idea.title) — \(body).\(tags)"
            }

        notes += connections
            .filter { $0.confidence >= 0.35 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(2)
            .map {
                "Durable connection: \(ideaTitles[$0.fromID] ?? "Idea") <-> \(ideaTitles[$0.toID] ?? "Idea") - \(trim($0.explanation, to: 120))."
            }

        let blockedCount = sources.filter(\.neverSendToCloud).count
        if blockedCount > 0 {
            notes.append("Privacy constraint: \(blockedCount) source(s) are marked never-send; keep them out of cloud synthesis.")
        }

        // A run log's verbatim output can echo source content (a local summarize of a
        // never-send source writes its body into the log). Redact the output for any
        // log whose work traces back to never-send material; keep the agent name so the
        // memory note still carries signal.
        let neverSendTraceIDs = Set(sources.filter(\.neverSendToCloud).map { $0.id.uuidString })
            .union(neverSendIdeaIDs.map { $0.uuidString })
        notes += logs
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(2)
            .map { log in
                let safeOutput = neverSendTraceIDs.contains(log.inputTrace) ? "[private]" : trim(log.output, to: 120)
                return "Recent run: \(log.agentName) produced \(safeOutput)."
            }

        guard !notes.isEmpty else { return "" }
        return trim("Local agent memory:\n" + notes.prefix(limit).map { "- \($0)" }.joined(separator: "\n"), to: maxCharacters)
    }

    public static func appendContext(
        to payload: String,
        ideas: [IdeaSeed],
        sources: [SourceItem],
        logs: [AgentRunLog],
        jobs: [FermentationJob],
        connections: [IdeaConnection],
        outcomes: [BuildOutcome] = [],
        limit: Int = 6
    ) -> String {
        let context = promptContext(ideas: ideas, sources: sources, logs: logs, jobs: jobs, connections: connections, outcomes: outcomes, limit: limit)
        guard !context.isEmpty else { return payload }
        return "\(payload)\n\n\(context)"
    }

    private static func trim(_ value: String, to limit: Int) -> String {
        let clean = value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return "\(clean.prefix(max(0, limit - 3)))..."
    }
}
