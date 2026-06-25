import Foundation

public struct CloudPayloadPreview: Codable, Equatable, Sendable {
    public var title: String
    public var taskClass: ModelTaskClass
    public var characterCount: Int
    public var blockedSourceTitles: [String]
    public var payload: String
    public var maySend: Bool

    public init(title: String, taskClass: ModelTaskClass, characterCount: Int, blockedSourceTitles: [String], payload: String, maySend: Bool) {
        self.title = title
        self.taskClass = taskClass
        self.characterCount = characterCount
        self.blockedSourceTitles = blockedSourceTitles
        self.payload = payload
        self.maySend = maySend
    }
}

public enum PrivacyPolicy {
    public static func preview(idea: IdeaSeed, sources: [SourceItem], taskClass: ModelTaskClass) -> CloudPayloadPreview {
        let blocked = sources.filter(\.neverSendToCloud)
        let allowed = sources.filter { !$0.neverSendToCloud }
        let sourceText = allowed.map { "- \($0.title): \($0.body)" }.joined(separator: "\n")
        let payload = """
        Idea: \(idea.title)

        \(idea.body)

        Allowed sources:
        \(sourceText)
        """
        // The never-send flag protects *sources*, not the idea itself. The idea's
        // own title and body are the user's words and are always part of the
        // payload, so a job is sendable whenever there is any non-blocked content —
        // even if every linked source is blocked, or there are no sources at all.
        // (The previous `blocked.count != sources.count` test wrongly blocked
        // source-less ideas, since `0 != 0` is false.)
        let hasIdeaText = !"\(idea.title)\(idea.body)".trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return CloudPayloadPreview(
            title: idea.title,
            taskClass: taskClass,
            characterCount: payload.count,
            blockedSourceTitles: blocked.map(\.title),
            payload: payload,
            maySend: hasIdeaText || !allowed.isEmpty
        )
    }
}
