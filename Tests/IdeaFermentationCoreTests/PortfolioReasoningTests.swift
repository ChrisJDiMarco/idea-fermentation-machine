import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Portfolio reasoning")
struct PortfolioReasoningTests {
    @Test func localReportSurfacesBuildNextAndSummary() throws {
        let store = try makeStore()
        _ = try store.createIdea(title: "Ambient capture tool", body: "Capture ideas with zero friction from anywhere.", tags: ["capture", "ambient"])
        _ = try store.createIdea(title: "Frictionless note capture", body: "Jot notes instantly without opening an app.", tags: ["capture", "notes"])
        _ = try store.createIdea(title: "Freelancer tax dashboard", body: "Track quarterly taxes for freelancers.", tags: ["finance"])
        let ideas = try store.listIdeas()

        let report = PortfolioReasoner.localReport(ideas: ideas, connections: [], taste: TasteModel(), now: Date())

        #expect(report.ideaCount == 3)
        #expect(report.buildNext != nil)
        #expect(!report.summary.isEmpty)
        #expect(report.source == "local heuristics")
    }

    @Test func localReportIsEmptyWithNoIdeas() {
        let report = PortfolioReasoner.localReport(ideas: [], connections: [], taste: TasteModel(), now: Date())
        #expect(report.isEmpty)
        #expect(report.ideaCount == 0)
    }

    @Test func decodeParsesCloudInsightsAndLinksRealTitles() throws {
        let store = try makeStore()
        _ = try store.createIdea(title: "Ambient capture tool", body: "x")
        _ = try store.createIdea(title: "Freelancer tax dashboard", body: "y")
        let ideas = try store.listIdeas()

        let json = """
        Here is the analysis:
        ```json
        {"summary":"Two distinct directions: capture and finance.","insights":[
          {"kind":"buildNext","headline":"Build the capture tool","reasoning":"Closest to your taste and most ripe.","ideas":["Ambient capture tool"],"priority":1},
          {"kind":"gap","headline":"No retrieval anywhere","reasoning":"You capture but never retrieve.","ideas":[],"priority":2},
          {"kind":"merge","headline":"Two capture ideas overlap","reasoning":"They are the same thing.","ideas":["Ambient capture tool","A title that does not exist"],"priority":3}
        ]}
        ```
        """
        let report = try #require(PortfolioReasoner.decode(json, ideas: ideas, source: "cloud · Test", now: Date()))

        #expect(report.summary.contains("capture and finance"))
        #expect(report.buildNext?.headline == "Build the capture tool")
        #expect(report.buildNext?.relatedIdeaTitles == ["Ambient capture tool"])
        #expect(report.insights(of: .gap).count == 1)
        // The non-existent cited title is dropped; the real one is kept.
        #expect(report.insights(of: .merge).first?.relatedIdeaTitles == ["Ambient capture tool"])
    }

    @Test func decodeNormalizesKindAliases() throws {
        let store = try makeStore()
        _ = try store.createIdea(title: "An idea", body: "x")
        let ideas = try store.listIdeas()
        let json = #"{"summary":"s","insights":[{"kind":"build_next","headline":"h","reasoning":"r","ideas":[],"priority":1},{"kind":"blind-spot","headline":"g","reasoning":"r","ideas":[]}]}"#

        let report = try #require(PortfolioReasoner.decode(json, ideas: ideas, source: "cloud · Test", now: Date()))
        #expect(report.buildNext != nil)              // "build_next" → .buildNext
        #expect(report.insights(of: .gap).count == 1) // "blind-spot" → .gap
    }

    @Test func decodeEnforcesOneBuildNextAndCapsPerKind() throws {
        let store = try makeStore()
        _ = try store.createIdea(title: "An idea", body: "x")
        let ideas = try store.listIdeas()
        let json = """
        {"summary":"s","insights":[
          {"kind":"buildNext","headline":"first build","reasoning":"r","priority":2},
          {"kind":"buildNext","headline":"second build","reasoning":"r","priority":1},
          {"kind":"theme","headline":"t1","reasoning":"r","priority":1},
          {"kind":"theme","headline":"t2","reasoning":"r","priority":2},
          {"kind":"theme","headline":"t3","reasoning":"r","priority":3}
        ]}
        """
        let report = try #require(PortfolioReasoner.decode(json, ideas: ideas, source: "cloud · T", now: Date()))
        #expect(report.insights(of: .buildNext).count == 1)
        #expect(report.buildNext?.headline == "second build") // lowest priority wins, deterministically
        #expect(report.insights(of: .theme).count == 2)        // capped at two
    }

    @Test func neverSendDerivedIsCaughtViaSourceLinkedIdeaIDs() throws {
        // Even when only the source→idea link is populated (linkedIdeaIDs) and the
        // idea→source link is missing, the idea's body is still redacted.
        let store = try makeStore()
        let idea = try store.createIdea(title: "Derived idea", body: "REVERSE-LINK-SECRET")
        var secret = try store.createSource(SourceItem(type: .note, title: "Vault", body: "z", neverSendToCloud: true))
        secret.linkedIdeaIDs = [idea.id]
        try store.upsertSource(secret)

        let digest = PortfolioReasoner.digest(ideas: try store.listIdeas(), connections: [], sources: try store.listSources(), outcomes: [], taste: TasteModel())
        #expect(!digest.contains("Derived idea"))         // title withheld too
        #expect(!digest.contains("REVERSE-LINK-SECRET"))
        #expect(digest.contains("[private idea"))
    }

    @Test func taintFlagAloneWithholdsIdeaFromDigest() throws {
        // The principled fix: the durable flag protects the idea even when NO never-send
        // source is present in the digest's inputs (which the link-derivation needs).
        let store = try makeStore()
        var idea = try store.createIdea(title: "Tainted idea", body: "FLAG-ONLY-SECRET", tags: ["x"])
        idea.derivedFromNeverSend = true
        try store.upsertIdea(idea)

        let digest = PortfolioReasoner.digest(ideas: try store.listIdeas(), connections: [], sources: [], outcomes: [], taste: TasteModel())
        #expect(!digest.contains("FLAG-ONLY-SECRET"))
        #expect(!digest.contains("Tainted idea"))
        #expect(digest.contains("[private idea"))
    }

    @Test func taintFlagIsStickyAcrossWrites() throws {
        // Once tainted, a later write that forgets the flag must not clear it — the
        // protected content was already copied into the body.
        let store = try makeStore()
        var idea = try store.createIdea(title: "Idea", body: "x")
        idea.derivedFromNeverSend = true
        try store.upsertIdea(idea)
        #expect(try store.idea(id: idea.id).derivedFromNeverSend)

        var reloaded = try store.idea(id: idea.id)
        reloaded.derivedFromNeverSend = false
        reloaded.title = "Edited"
        try store.upsertIdea(reloaded)
        #expect(try store.idea(id: idea.id).derivedFromNeverSend) // sticky
    }

    @Test func digestRedactsNeverSendSourcedIdeaBodies() throws {
        let store = try makeStore()
        let secret = try store.createSource(SourceItem(type: .note, title: "Vault", body: "z", neverSendToCloud: true))
        var idea = try store.createIdea(title: "Sensitive idea", body: "PORTFOLIO-SECRET-BODY", tags: ["x"])
        idea.sourceIDs = [secret.id]
        try store.upsertIdea(idea)
        let ideas = try store.listIdeas()

        let digest = PortfolioReasoner.digest(ideas: ideas, connections: [], sources: [secret], outcomes: [], taste: TasteModel())

        #expect(!digest.contains("Sensitive idea"))         // title may be source-derived → withheld
        #expect(!digest.contains("PORTFOLIO-SECRET-BODY"))  // never-send-sourced body is withheld
        #expect(digest.contains("[private idea"))
    }
}
