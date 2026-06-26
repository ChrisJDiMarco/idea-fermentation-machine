import Foundation
import Testing
@testable import IdeaFermentationCore

/// Returns a different structured reply for each of the loop's three stages, keyed off the
/// instruction text so the test exercises the real branching, not a single canned response.
struct CognitiveStubProvider: LLMProvider {
    let providerName = "Stub"
    let availableModels = [
        LLMModel(provider: "Stub", name: "stub", displayName: "Stub", inputCostPerMillion: 0.1, outputCostPerMillion: 0.1, pricingURL: "local", verifiedOn: "test")
    ]

    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        let text: String
        if request.prompt.contains("reflecting on the reasoning") {
            text = #"{"weakestLink":"thin evidence","assumptions":["users care enough"],"spuriousConnections":[],"processNote":"explored adequately","confidence":0.7,"nextToExplore":"talk to five users"}"#
        } else if request.prompt.contains("propose ONE original") {
            text = #"{"title":"Bridge tool","body":"Unifies the two closest ideas; smallest test is one shared workflow.","tags":["ambient","capture"]}"#
        } else {
            text = #"{"focus":"ambient capture","summary":"They share a friction-removal core.","observations":["A removes a step","B overlaps A"],"hypotheses":["one tool could do both"],"questions":["is it yours to build"],"connections":[{"from":0,"to":1,"type":"extends","rationale":"shared theme","strength":0.8},{"from":0,"to":2,"type":"supports","rationale":"obs feeds hypothesis","strength":0.7}]}"#
        }
        return LLMResponse(text: text, inputTokens: 60, outputTokens: 60, provider: providerName, model: model.name)
    }
}

/// The reasoning (first, load-bearing) call returns unparseable text.
struct GarbageReasonProvider: LLMProvider {
    let providerName = "Stub"
    let availableModels = [
        LLMModel(provider: "Stub", name: "stub", displayName: "Stub", inputCostPerMillion: 0.1, outputCostPerMillion: 0.1, pricingURL: "local", verifiedOn: "test")
    ]
    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        LLMResponse(text: "I'm sorry, I can't structure that.", inputTokens: 60, outputTokens: 60, provider: providerName, model: model.name)
    }
}

@Suite("Cognitive loop")
struct CognitiveLoopTests {
    private func idea(_ title: String, _ embedding: [Double], ripeness: Double, tags: [String] = []) -> IdeaSeed {
        IdeaSeed(title: title, body: "\(title) body text long enough to matter.", manualTags: tags, embedding: embedding, ripeness: ripeness)
    }

    @Test func cloudCycleFormsAWebGeneratesAnIdeaAndReflects() async throws {
        let material = CognitiveLoop.Material(ideas: [
            idea("Ambient capture", [1, 0, 0], ripeness: 60, tags: ["capture"]),
            idea("Frictionless notes", [0.9, 0.1, 0], ripeness: 50, tags: ["capture"])
        ])
        let provider = CognitiveStubProvider()

        let result = try await CognitiveLoop.think(material: material, taste: nil, builderProfile: nil, provider: provider, model: provider.availableModels[0], apiKey: "k")
        let r = try #require(result)

        #expect(r.responses.count == 3) // reason + generate + reflect
        #expect(r.thoughts.count == 4)  // 2 observations + 1 hypothesis + 1 question
        #expect(r.edges.count == 2)     // both connections index-mapped to valid nodes
        #expect(r.generated.count == 1)
        #expect(r.generated.first?.title == "Bridge tool")
        #expect(r.session.focus == "ambient capture")
        #expect(r.session.reflection.confidence == 0.7)
        // Thought confidence is anchored on the reflection's self-check, not left at the default.
        #expect(r.thoughts.allSatisfy { $0.confidence == 0.7 })
        // A contradiction/extends edge points between two real thought nodes.
        let ids = Set(r.thoughts.map(\.id))
        #expect(r.edges.allSatisfy { ids.contains($0.fromThoughtID) && ids.contains($0.toThoughtID) })
    }

    @Test func degradedReasoningSurfacesThePaidCallButFormsNoWeb() async throws {
        let material = CognitiveLoop.Material(ideas: [
            idea("A", [1, 0, 0], ripeness: 10), idea("B", [0, 1, 0], ripeness: 10)
        ])
        let provider = GarbageReasonProvider()

        let result = try await CognitiveLoop.think(material: material, taste: nil, builderProfile: nil, provider: provider, model: provider.availableModels[0], apiKey: "k")
        let r = try #require(result)
        #expect(r.thoughts.isEmpty)      // nothing usable
        #expect(r.responses.count == 1)  // but the reasoning call was paid for — surface it
        #expect(r.generated.isEmpty)
    }

    @Test func localThinkFormsWebFromEmbeddingProximity() throws {
        // Explicit embeddings make the proximity deterministic regardless of the NL backend.
        let material = CognitiveLoop.Material(ideas: [
            idea("Ambient capture", [1, 0, 0], ripeness: 70, tags: ["capture"]),
            idea("Frictionless notes", [0.95, 0.05, 0], ripeness: 60, tags: ["capture"]),
            idea("Unrelated finance app", [0, 0, 1], ripeness: 40, tags: ["finance"])
        ])
        let maybe = CognitiveLoop.localThink(material: material)
        let result = try #require(maybe)
        #expect(result.thoughts.filter { $0.kind == .observation }.count == 3)
        #expect(result.thoughts.contains { $0.kind == .hypothesis })
        #expect(result.edges.count == 1)               // only the close pair links; finance is orthogonal
        #expect(result.generated.count == 1)
        #expect(result.session.source == "local")
    }

    @Test func taintedLocalMaterialMarksThoughtsNeverSend() throws {
        let material = CognitiveLoop.Material(ideas: [
            idea("Private A", [1, 0, 0], ripeness: 50), idea("Private B", [0.9, 0.1, 0], ripeness: 40)
        ], derivedFromNeverSend: true)
        let maybe = CognitiveLoop.localThink(material: material)
        let result = try #require(maybe)
        #expect(result.session.derivedFromNeverSend)
        #expect(result.thoughts.allSatisfy { $0.derivedFromNeverSend })
    }
}

@Suite("Thought web persistence")
struct ThoughtWebPersistenceTests {
    @Test func sessionThoughtsAndEdgesRoundTrip() throws {
        let store = try makeStore()
        let sessionID = UUID()
        let t1 = Thought(sessionID: sessionID, kind: .observation, content: "A removes a step", confidence: 0.6)
        let t2 = Thought(sessionID: sessionID, kind: .hypothesis, content: "One tool could do both", confidence: 0.6, derivedFromNeverSend: true)
        let edge = ThoughtEdge(sessionID: sessionID, fromThoughtID: t1.id, toThoughtID: t2.id, type: .extends, rationale: "shared core", strength: 0.8)
        let session = ThinkingSession(
            id: sessionID, focus: "ambient capture",
            analysis: "reasoned across two ideas",
            reflection: MindReflection(weakestLink: "thin evidence", assumptions: ["users care"], confidence: 0.65, nextToExplore: "talk to users"),
            thoughtIDs: [t1.id, t2.id], edgeIDs: [edge.id], generatedIdeaIDs: [UUID()], costUSD: 0.012,
            source: "cloud · Stub", derivedFromNeverSend: true
        )

        try store.saveThinkingSession(session, thoughts: [t1, t2], edges: [edge])

        let maybeLatest = try store.latestThinkingSession()
        let latest = try #require(maybeLatest)
        #expect(latest.focus == "ambient capture")
        #expect(latest.reflection.weakestLink == "thin evidence")
        #expect(latest.reflection.confidence == 0.65)
        #expect(latest.source == "cloud · Stub")
        #expect(latest.derivedFromNeverSend)
        #expect(latest.generatedIdeaIDs.count == 1)

        let thoughtCount = try store.thoughtCount()
        let edgeCount = try store.thoughtEdgeCount()
        #expect(thoughtCount == 2)
        #expect(edgeCount == 1)
        let thoughts = try store.thoughts()
        #expect(thoughts.contains { $0.kind == .hypothesis && $0.derivedFromNeverSend })
        let edges = try store.thoughtEdges()
        #expect(edges.first?.type == .extends)
        #expect(edges.first?.strength == 0.8)

        try store.clearMind()
        let clearedThoughts = try store.thoughtCount()
        let clearedSessions = try store.thinkingSessions()
        #expect(clearedThoughts == 0)
        #expect(clearedSessions.isEmpty)
    }
}
