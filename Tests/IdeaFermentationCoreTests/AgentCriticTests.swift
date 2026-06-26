import Foundation
import Testing
@testable import IdeaFermentationCore

/// Returns a first-pass critique on the draft call, and an interrogation result on the
/// second call (detected by the "FIRST-PASS CRITIQUE" marker in the input).
struct DeepCriticStubProvider: LLMProvider {
    let providerName = "Stub"
    let availableModels = [
        LLMModel(provider: "Stub", name: "stub", displayName: "Stub", inputCostPerMillion: 0.1, outputCostPerMillion: 0.1, pricingURL: "local", verifiedOn: "test")
    ]

    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        let text: String
        if request.input.contains("FIRST-PASS CRITIQUE") {
            text = #"{"loadBearing":"Users will switch from their current tool","experiment":"Show five target users a mockup and ask if they would switch this week"}"#
        } else {
            text = #"{"assumptions":["The user feels this often enough to change behavior"],"risks":["Evidence is thin"],"contradictions":["Novel but low personal resonance"]}"#
        }
        return LLMResponse(text: text, inputTokens: 50, outputTokens: 50, provider: providerName, model: model.name)
    }
}

/// Draft call returns non-JSON garbage (so it can't be parsed into real critique JSON);
/// the interrogation call would still answer, but the loop should never reach it usefully.
struct GarbageDraftStubProvider: LLMProvider {
    let providerName = "Stub"
    let availableModels = [
        LLMModel(provider: "Stub", name: "stub", displayName: "Stub", inputCostPerMillion: 0.1, outputCostPerMillion: 0.1, pricingURL: "local", verifiedOn: "test")
    ]

    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        LLMResponse(text: "I'm sorry, I can't help with that.", inputTokens: 50, outputTokens: 50, provider: providerName, model: model.name)
    }
}

/// Draft succeeds with real JSON; the interrogation call throws (transient failure).
struct FlakyInterrogateStubProvider: LLMProvider {
    let providerName = "Stub"
    let availableModels = [
        LLMModel(provider: "Stub", name: "stub", displayName: "Stub", inputCostPerMillion: 0.1, outputCostPerMillion: 0.1, pricingURL: "local", verifiedOn: "test")
    ]

    struct Boom: Error {}

    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        if request.input.contains("FIRST-PASS CRITIQUE") { throw Boom() }
        return LLMResponse(text: #"{"assumptions":["Users switch tools easily"],"risks":["Thin evidence"],"contradictions":["Novel but unproven"]}"#,
                           inputTokens: 50, outputTokens: 50, provider: providerName, model: model.name)
    }
}

@Suite("Agentic critique")
struct AgentCriticTests {
    @Test func deepCritiqueRunsTwoStepsAndLeadsWithTheKillerExperiment() async throws {
        let idea = IdeaSeed(title: "Ambient capture", body: "Capture ideas with zero friction.", manualTags: ["capture"])
        let provider = DeepCriticStubProvider()

        let outcome = try await AgentCritic.deepCritique(idea: idea, tasteProfile: nil, provider: provider, model: provider.availableModels[0], apiKey: "test")
        let critique = try #require(outcome.critique)

        #expect(outcome.responses.count == 2) // a real loop: draft + interrogate
        // The interrogation's cheapest test and load-bearing assumption lead the list.
        #expect(critique.assumptions.first?.contains("Cheapest test") == true)
        #expect(critique.assumptions.contains { $0.contains("mockup") })
        #expect(critique.assumptions.contains { $0.contains("Load-bearing") && $0.contains("switch") })
        // The draft's risks/contradictions are preserved.
        #expect(critique.risks.contains { $0.contains("Evidence is thin") })
        #expect(critique.contradictions.contains { $0.contains("personal resonance") })
    }

    @Test func degradedFirstPassReturnsNilCritiqueButStillSurfacesThePaidCall() async throws {
        // The model gave back garbage that won't parse — that's a local critique, not a deep
        // one. We must NOT bill canned heuristic objections as "deep", so the critique is nil,
        // but the paid draft response is still returned so the caller can record the spend.
        let idea = IdeaSeed(title: "Ambient capture", body: "Capture ideas with zero friction.", manualTags: ["capture"])
        let provider = GarbageDraftStubProvider()

        let outcome = try await AgentCritic.deepCritique(idea: idea, tasteProfile: nil, provider: provider, model: provider.availableModels[0], apiKey: "test")
        #expect(outcome.critique == nil)
        #expect(outcome.responses.count == 1) // the draft was paid for — surface it for the ledger
    }

    @Test func transientInterrogationFailureKeepsTheAlreadyPaidDraftCritique() async throws {
        // Step 2 throwing must not waste step 1: the draft critique survives, minus the
        // load-bearing/experiment lines, and only the one billable response is returned.
        let idea = IdeaSeed(title: "Ambient capture", body: "Capture ideas with zero friction.", manualTags: ["capture"])
        let provider = FlakyInterrogateStubProvider()

        let outcome = try await AgentCritic.deepCritique(idea: idea, tasteProfile: nil, provider: provider, model: provider.availableModels[0], apiKey: "test")
        let critique = try #require(outcome.critique)
        #expect(outcome.responses.count == 1) // only the draft came back
        #expect(critique.risks.contains { $0.contains("Thin evidence") })
        // No interrogation, so no kill-or-confirm experiment line leads the assumptions.
        #expect(critique.assumptions.contains { $0.contains("Cheapest test") } == false)
    }
}
