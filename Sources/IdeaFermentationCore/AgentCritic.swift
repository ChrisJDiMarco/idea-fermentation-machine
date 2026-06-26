import Foundation

/// A critique that actually *reasons in a loop* instead of firing one shot. It drafts a
/// critique, then interrogates THAT critique to find the single assumption the whole
/// idea rests on and the cheapest real-world test that would confirm or kill it. The
/// result fills the existing `IdeaCritique` fields, so nothing downstream changes — it's
/// just sharper.
public enum AgentCritic {
    public static func deepCritique(
        idea: IdeaSeed,
        tasteProfile: TasteProfile?,
        builderProfile: AutonomyProfile? = nil,
        provider: any LLMProvider,
        model: LLMModel,
        apiKey: String
    ) async throws -> (critique: CritiqueResult?, responses: [LLMResponse]) {
        let ideaText = "Idea: \(idea.title)\n\n\(idea.body)\n\nTags: \(idea.manualTags.joined(separator: ", "))"

        // Step 1 — draft critique: weak assumptions, real risks, internal contradictions.
        let draftRequest = LLMRequest(
            taskClass: .critique,
            prompt: "You are a sharp, fair critic. Identify the weak assumptions, real risks, and internal contradictions in this idea — specific to THIS idea, never generic filler. Return ONLY JSON matching CritiqueResult: {\"assumptions\":[\"...\"],\"risks\":[\"...\"],\"contradictions\":[\"...\"]}.",
            input: ideaText,
            maxOutputTokens: 700
        )
        let draft = try await provider.send(draftRequest, model: model, apiKey: apiKey)

        // Only accept the draft if the model produced parseable critique JSON. If it didn't,
        // the heuristic fallback would emit canned, idea-agnostic objections — that's a local
        // critique, not a "deep" one, so return nil (still surfacing the paid draft) and let
        // the caller fall back honestly instead of billing boilerplate as deep reasoning.
        guard let base = AgentResultInterpreter.decodedCritique(from: draft.text) else {
            return (nil, [draft])
        }

        // Step 2 — interrogate the draft: the ONE load-bearing assumption and the cheapest
        // test that would falsify it. This is the loop — reasoning ABOUT the first pass. A
        // transient failure here doesn't waste step 1: keep the draft, drop the interrogation.
        let interrogateRequest = LLMRequest(
            taskClass: .critique,
            prompt: BuilderContext.promptPrefix(profile: builderProfile, taste: tasteProfile) + "You are a co-founder who kills bad ideas cheaply. Given an idea and a first-pass critique, name the SINGLE assumption the whole idea rests on — if it's false, the idea collapses — and the cheapest, fastest real-world test that would confirm or kill that assumption in days, not months. Return ONLY JSON: {\"loadBearing\":\"the one assumption\",\"experiment\":\"the cheapest kill-or-confirm test\"}.",
            input: "IDEA:\n\(ideaText)\n\nFIRST-PASS CRITIQUE:\n\(draft.text)",
            maxOutputTokens: 400
        )
        var responses = [draft]
        var interrogation: Interrogation? = nil
        if let deep = try? await provider.send(interrogateRequest, model: model, apiKey: apiKey) {
            responses.append(deep)
            interrogation = decodeInterrogation(deep.text)
        }

        // Lead with the kill-or-confirm experiment and the load-bearing assumption (the UI
        // surfaces assumptions as the "Next Experiment"), then the draft's assumptions.
        var assumptions: [String] = []
        if let experiment = interrogation?.experiment, !experiment.isEmpty {
            assumptions.append("Cheapest test to kill or confirm it: \(experiment)")
        }
        if let loadBearing = interrogation?.loadBearing, !loadBearing.isEmpty {
            assumptions.append("Load-bearing assumption: \(loadBearing)")
        }
        assumptions += base.assumptions
        var seen = Set<String>()
        let deduped = assumptions.filter { seen.insert($0).inserted }

        let result = CritiqueResult(assumptions: deduped, risks: base.risks, contradictions: base.contradictions)
        guard !(result.assumptions.isEmpty && result.risks.isEmpty && result.contradictions.isEmpty) else {
            return (nil, responses)
        }
        return (result, responses)
    }

    private struct Interrogation: Codable {
        var loadBearing: String?
        var experiment: String?
    }

    private static func decodeInterrogation(_ output: String) -> Interrogation? {
        var text = output
        if let start = text.range(of: "```json")?.upperBound,
           let end = text[start...].range(of: "```")?.lowerBound {
            text = String(text[start..<end])
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        return try? JSONSupport.decoder.decode(Interrogation.self, from: Data(text[start...end].utf8))
    }
}
