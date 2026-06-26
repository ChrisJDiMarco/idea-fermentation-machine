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

        // Defense in depth: an idea derived from a never-send source may carry protected
        // content in its title and tags (a captured page title; tags mined from its
        // body), not just its body — so withhold ALL of it from the cloud digest, in
        // both link directions.
        let neverSendIdeaIDs = taintedIdeaIDs(ideas: ideas, sources: sources)
        func safeTitle(_ id: UUID) -> String { neverSendIdeaIDs.contains(id) ? "[private idea]" : (ideaTitles[id] ?? "Idea") }

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
                let isPrivate = neverSendIdeaIDs.contains(outcome.ideaID)
                let lesson = (isPrivate || outcome.note.isEmpty) ? "" : " — \(trim(outcome.note, to: 120))"
                return "Build outcome: \(outcome.result.title) — \(safeTitle(outcome.ideaID))\(lesson)."
            }

        notes += ideas
            .filter { $0.status == .archived && !outcomeIdeaIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { idea in
                guard !neverSendIdeaIDs.contains(idea.id) else { return "Archive lesson: [private idea] (details withheld)." }
                let tags = idea.manualTags.isEmpty ? "" : " Themes: \(idea.manualTags.joined(separator: ", "))."
                return "Archive lesson: \(idea.title) — \(trim(idea.body, to: 140)).\(tags)"
            }

        notes += connections
            .filter { $0.confidence >= 0.35 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(2)
            .map { connection in
                // The explanation is built from idea title/body, so withhold it if either
                // endpoint is never-send-derived.
                let isPrivate = neverSendIdeaIDs.contains(connection.fromID) || neverSendIdeaIDs.contains(connection.toID)
                let detail = isPrivate ? "details withheld" : trim(connection.explanation, to: 120)
                return "Durable connection: \(safeTitle(connection.fromID)) <-> \(safeTitle(connection.toID)) - \(detail)."
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
