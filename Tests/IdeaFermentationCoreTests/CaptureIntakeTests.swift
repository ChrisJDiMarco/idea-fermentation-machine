import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Capture intake")
@MainActor
struct CaptureIntakeTests {
    @Test func classifiesCommonSites() {
        #expect(SourceClassifier.classify(url: "https://github.com/a/b").category == "Repository")
        #expect(SourceClassifier.classify(url: "https://example.com/paper.pdf").type == .document)
        #expect(SourceClassifier.classify(url: "https://www.youtube.com/watch?v=x").category == "Video")
        #expect(SourceClassifier.classify(url: "https://x.com/user/status/1").type == .conversation)
        #expect(SourceClassifier.classify(url: "https://news.example.com/post", kindHint: "article").category == "Article")
        #expect(SourceClassifier.classify(url: "https://example.com/thing").category == "Web page")
    }

    @Test func ingestCreatesCategorizedSourceWithTags() throws {
        let store = try makeStore()
        let payload = CapturePayload(
            url: "https://news.example.com/local-ai",
            title: "Local AI agents are eating the desktop",
            pageText: "A look at private local AI agents and ambient memory for desktop workflows.",
            siteName: "Example News",
            kindHint: "article",
            tags: ["ai"]
        )
        let result = try CaptureIntake.ingest(payload, into: store)

        #expect(result.ok)
        #expect(!result.deduped)
        #expect(result.category == "Article")
        #expect(result.type == SourceType.article.rawValue)
        #expect(result.tags.contains("ai"))

        let sources = try store.listSources()
        #expect(sources.count == 1)
        #expect(sources[0].metadata.capturedVia == "chrome-extension")
        #expect(sources[0].metadata.category == "Article")
        #expect(sources[0].metadata.tags == result.tags)
    }

    @Test func neverSendIdeaModeCaptureTaintsTheIdea() throws {
        // A Chrome capture marked never-send AND saved as an idea copies the protected
        // content into the idea body — that idea must inherit the taint, or a per-idea
        // cloud run would leak it.
        let store = try makeStore()
        let payload = CapturePayload(
            url: "https://internal.example.com/doc",
            title: "Confidential plan",
            selectionText: "CAPTURE-IDEA-MODE-SECRET",
            tags: ["x"],
            neverSendToCloud: true,
            saveAs: "idea"
        )
        let result = try CaptureIntake.ingest(payload, into: store)
        #expect(result.ideaID != nil)

        let ideas = try store.listIdeas()
        let idea = try #require(ideas.first)
        #expect(idea.derivedFromNeverSend)
        let digest = PortfolioReasoner.digest(ideas: ideas, connections: [], sources: try store.listSources(), outcomes: [], taste: TasteModel())
        #expect(!digest.contains("CAPTURE-IDEA-MODE-SECRET"))
    }

    @Test func ingestAutoLinksToRelatedIdea() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Ambient memory agent", body: "A private local AI memory agent that recalls context.", tags: ["memory"])
        let payload = CapturePayload(
            url: "https://example.com/ambient",
            title: "Ambient AI memory tools",
            pageText: "Private local AI memory agents that recall your context and daily workflow.",
            kindHint: "article"
        )
        let result = try CaptureIntake.ingest(payload, into: store)

        #expect(result.linkedIdeas.contains(idea.title))
        let stored = try #require(try store.listSources().first)
        #expect(stored.linkedIdeaIDs.contains(idea.id))
        #expect(stored.extractionStatus == .connected)
    }

    @Test func ingestDedupesRepeatCaptures() throws {
        let store = try makeStore()
        let payload = CapturePayload(url: "https://example.com/x", title: "Same page", pageText: "Same body content for dedup.")
        let first = try CaptureIntake.ingest(payload, into: store)
        let second = try CaptureIntake.ingest(payload, into: store)

        #expect(!first.deduped)
        #expect(second.deduped)
        #expect(second.sourceID == first.sourceID)
        #expect(try store.listSources().count == 1)
    }

    @Test func ingestCanPromoteToIdea() throws {
        let store = try makeStore()
        var payload = CapturePayload(url: "https://example.com/build", title: "A buildable idea", pageText: "Capture and recall meeting context locally and privately.")
        payload.saveAs = "idea"
        let result = try CaptureIntake.ingest(payload, into: store)

        let ideaID = try #require(result.ideaID)
        #expect(result.message.contains("created an idea"))
        let idea = try store.idea(id: UUID(uuidString: ideaID)!)
        let source = try #require(try store.listSources().first)
        #expect(idea.sourceIDs.contains(source.id))
        #expect(source.linkedIdeaIDs.contains(idea.id))
    }

    @Test func ingestRespectsNeverSend() throws {
        let store = try makeStore()
        var payload = CapturePayload(url: "https://example.com/private", title: "Private", pageText: "Sensitive content.")
        payload.neverSendToCloud = true
        _ = try CaptureIntake.ingest(payload, into: store)
        #expect(try store.listSources().first?.neverSendToCloud == true)
    }

    @Test func ingestPrefersSelectionWhenPromotingToIdea() throws {
        let store = try makeStore()
        var payload = CapturePayload(
            url: "https://example.com/long",
            title: "Long article",
            selectionText: "The one sentence I actually care about.",
            pageText: "A very long article body with lots of unrelated text around it."
        )
        payload.saveAs = "idea"
        let result = try CaptureIntake.ingest(payload, into: store)
        let idea = try store.idea(id: UUID(uuidString: try #require(result.ideaID))!)
        #expect(idea.body == "The one sentence I actually care about.")
    }
}
