import Foundation

/// Turns a web capture into an organized, auto-linked Source (and optionally an
/// Idea), reusing the same intelligence the in-app importer uses. `@MainActor`
/// because `IdeaStore`/`SQLiteDatabase` hold a single unsynchronized sqlite
/// handle that is only ever safe to touch from the main actor — making this
/// isolation a compile-time guarantee, not a convention.
@MainActor
public enum CaptureIntake {
    private static let maxBodyCharacters = 60_000

    public static func ingest(_ payload: CapturePayload, into store: IdeaStore, taste: TasteSignals = TasteSignals()) throws -> CaptureResult {
        let url = payload.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = SourceClassifier.host(of: url)
        let (type, category) = SourceClassifier.classify(url: url, kindHint: payload.kindHint)

        let selection = clean(payload.selectionText)
        let pageText = clean(payload.pageText)
        let note = clean(payload.note)
        var body = pageText.isEmpty ? (selection.isEmpty ? clean(payload.excerpt) : selection) : pageText
        if !note.isEmpty { body = body.isEmpty ? note : "\(note)\n\n\(body)" }
        body = String(body.prefix(maxBodyCharacters))

        let title = firstNonEmpty(clean(payload.title), clean(payload.siteName), host, url)
        let neverSend = payload.neverSendToCloud ?? false
        let hash = TextHashing.sha256("\(title)\n\(body)")

        // Dedup against the same hash createSource computes.
        if let existing = try store.source(textHash: hash) {
            return CaptureResult(
                ok: true,
                deduped: true,
                sourceID: existing.id.uuidString,
                type: existing.type.rawValue,
                category: existing.metadata.category ?? category,
                title: existing.title,
                tags: existing.metadata.tags ?? [],
                linkedIdeas: linkedIdeaTitles(for: existing, store: store),
                message: "Already saved · \(existing.title)"
            )
        }

        let tags = deriveTags(title: title, body: body, userTags: payload.tags ?? [], taste: taste)
        let metadata = SourceMetadata(
            contentType: "public.url",
            siteName: clean(payload.siteName).isEmpty ? nil : clean(payload.siteName),
            author: clean(payload.author).isEmpty ? nil : clean(payload.author),
            excerpt: clean(payload.excerpt).isEmpty ? nil : String(clean(payload.excerpt).prefix(400)),
            faviconURL: payload.faviconURL,
            publishedTime: payload.publishedTime,
            capturedVia: "chrome-extension",
            category: category,
            tags: tags
        )

        var source = SourceItem(
            type: type,
            title: title,
            body: body,
            url: url.isEmpty ? nil : url,
            extractionStatus: .captured,
            neverSendToCloud: neverSend,
            textHash: hash,
            metadata: metadata
        )

        // Auto-link to related ideas immediately so the response can name them.
        let summary = AgentResultInterpreter.sourceSummary(for: source, ideas: try store.listIdeas())
        source.linkedIdeaIDs = summary.linkedIdeaIDs
        source.extractionStatus = source.linkedIdeaIDs.isEmpty ? .captured : .connected

        let stored = try store.createSource(source)
        // Same pipeline as ShellViewModel.importFile: keeps links fresh on the scheduler.
        try store.enqueue(FermentationJob(sourceID: stored.id, taskClass: .extract, inputHash: stored.textHash))

        var ideaID: String?
        if payload.mode == .idea {
            let ideaBody = selection.isEmpty ? body : selection
            if let idea = try createOrFetchIdea(title: title, body: ideaBody, tags: tags, store: store) {
                ideaID = idea.id.uuidString
                try crossLink(source: stored, idea: idea, store: store)
            }
        }

        let linked = linkedIdeaTitles(for: try store.source(id: stored.id), store: store)
        return CaptureResult(
            ok: true,
            deduped: false,
            sourceID: stored.id.uuidString,
            ideaID: ideaID,
            type: type.rawValue,
            category: category,
            title: title,
            tags: tags,
            linkedIdeas: linked,
            message: composeMessage(category: category, tags: tags, linked: linked, ideaCreated: ideaID != nil)
        )
    }

    // MARK: - Helpers

    private static func createOrFetchIdea(title: String, body: String, tags: [String], store: IdeaStore) throws -> IdeaSeed? {
        do {
            return try store.createIdea(title: title, body: body, tags: tags)
        } catch IdeaStoreError.duplicate {
            let hash = TextHashing.sha256("\(title)\n\(body)\n\(tags.joined(separator: " "))")
            return try store.idea(textHash: hash)
        }
    }

    private static func crossLink(source: SourceItem, idea: IdeaSeed, store: IdeaStore) throws {
        var nextSource = source
        if !nextSource.linkedIdeaIDs.contains(idea.id) { nextSource.linkedIdeaIDs.append(idea.id) }
        try store.upsertSource(nextSource)
        var nextIdea = idea
        if !nextIdea.sourceIDs.contains(source.id) { nextIdea.sourceIDs.append(source.id) }
        // An idea minted from a never-send capture has the protected content in its body,
        // so it inherits the taint (sticky via the upsert's OR).
        if source.neverSendToCloud { nextIdea.derivedFromNeverSend = true }
        try store.upsertIdea(nextIdea)
    }

    private static func linkedIdeaTitles(for source: SourceItem, store: IdeaStore) -> [String] {
        let ideas = (try? store.listIdeas()) ?? []
        let titlesByID = Dictionary(ideas.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        return source.linkedIdeaIDs.compactMap { titlesByID[$0] }
    }

    /// Readable, deduped tags: user tags first, then watch-topic matches, then the
    /// most frequent content words. Unstemmed so they read naturally in the UI.
    private static func deriveTags(title: String, body: String, userTags: [String], taste: TasteSignals) -> [String] {
        let words = "\(title) \(body)".lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !Tokenizer.stopwords.contains($0) }
        let counts = NSCountedSet(array: words)
        let byFrequency = counts.allObjects.compactMap { $0 as? String }
            .sorted { counts.count(for: $0) > counts.count(for: $1) }

        // Words whose stem matches a taste interest are highly relevant — surface first.
        let tasteMatches = byFrequency.filter { taste.interests.contains(Tokenizer.stem($0)) }

        var ordered: [String] = []
        var seen = Set<String>()
        for tag in userTags.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }).filter({ !$0.isEmpty })
            + tasteMatches + byFrequency {
            guard seen.insert(tag).inserted else { continue }
            ordered.append(tag)
            if ordered.count >= 6 { break }
        }
        return ordered
    }

    private static func composeMessage(category: String, tags: [String], linked: [String], ideaCreated: Bool) -> String {
        var parts = ["Saved as \(category)"]
        if !tags.isEmpty { parts.append("tagged \(tags.prefix(3).joined(separator: ", "))") }
        if !linked.isEmpty { parts.append("linked to \(linked.count) idea\(linked.count == 1 ? "" : "s")") }
        if ideaCreated { parts.append("created an idea") }
        return parts.joined(separator: " · ")
    }

    private static func clean(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func firstNonEmpty(_ values: String...) -> String {
        values.first { !$0.isEmpty } ?? "Untitled capture"
    }
}
