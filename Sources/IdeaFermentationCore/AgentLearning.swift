import Foundation

public enum AgentLearning {
    public static func promptContext(
        ideas: [IdeaSeed],
        sources: [SourceItem],
        logs: [AgentRunLog],
        jobs: [FermentationJob],
        connections: [IdeaConnection],
        limit: Int = 6,
        maxCharacters: Int = 1_200
    ) -> String {
        let ideaTitles = Dictionary(uniqueKeysWithValues: ideas.map { ($0.id, $0.title) })
        var notes: [String] = []

        notes += jobs
            .filter { $0.status == .failed && ($0.lastError?.isEmpty == false) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(2)
            .map { "Failure pattern: \($0.taskClass.rawValue) failed with \(trim($0.lastError ?? "", to: 120))." }

        notes += ideas
            .filter { $0.status == .archived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { idea in
                let tags = idea.manualTags.isEmpty ? "" : " Themes: \(idea.manualTags.joined(separator: ", "))."
                return "Archive lesson: \(idea.title) — \(trim(idea.body, to: 140)).\(tags)"
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

        notes += logs
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(2)
            .map { "Recent run: \($0.agentName) produced \(trim($0.output, to: 120))." }

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
        limit: Int = 6
    ) -> String {
        let context = promptContext(ideas: ideas, sources: sources, logs: logs, jobs: jobs, connections: connections, limit: limit)
        guard !context.isEmpty else { return payload }
        return "\(payload)\n\n\(context)"
    }

    private static func trim(_ value: String, to limit: Int) -> String {
        let clean = value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        return "\(clean.prefix(max(0, limit - 3)))..."
    }
}
