import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Build outcome loop")
struct BuildOutcomeTests {
    @Test func persistsOneOutcomePerIdeaAndCascadesOnDelete() throws {
        let store = try makeStore()
        let idea = try store.createIdea(title: "Shipped idea", body: "Built and shipped.")
        try store.saveBuildOutcome(BuildOutcome(ideaID: idea.id, result: .shipped, note: "Users loved it."))
        #expect(try store.buildOutcome(for: idea.id)?.result == .shipped)
        #expect(try store.buildOutcome(for: idea.id)?.note == "Users loved it.")

        // Recording again replaces the prior — exactly one outcome per idea.
        try store.saveBuildOutcome(BuildOutcome(ideaID: idea.id, result: .flopped, note: "Actually, no."))
        #expect(try store.buildOutcomes().filter { $0.ideaID == idea.id }.count == 1)
        #expect(try store.buildOutcome(for: idea.id)?.result == .flopped)

        // Deleting the idea cascades to its outcome.
        try store.deleteIdea(idea.id)
        #expect(try store.buildOutcomes().isEmpty)
    }

    @Test func tasteSignalsAreSignedAndWeightedAboveAMarkReady() {
        #expect(BuildResult.shipped.tasteLabel == 1)
        #expect(BuildResult.built.tasteLabel == 1)
        #expect(BuildResult.abandoned.tasteLabel == -1)
        #expect(BuildResult.flopped.tasteLabel == -1)
        // Acting on an idea is a stronger statement than merely flagging it ready.
        #expect(BuildResult.shipped.tasteRate > TasteModel.defaultLearningRate)
        // A flop pushes more gently than a clean abandon — the idea still pulled you in.
        #expect(BuildResult.flopped.tasteRate < BuildResult.abandoned.tasteRate)
        #expect(BuildResult.shipped.isPositive)
        #expect(!BuildResult.flopped.isPositive)
    }

    @Test func agentMemorySurfacesBuildOutcomesAsLeadLessons() {
        let idea = IdeaSeed(title: "Shipped CRM", body: "A focused CRM.")
        let outcome = BuildOutcome(ideaID: idea.id, result: .shipped, note: "Narrow scope won.")
        let context = AgentLearning.promptContext(
            ideas: [idea], sources: [], logs: [], jobs: [], connections: [], outcomes: [outcome]
        )
        #expect(context.contains("Build outcome: Shipped"))
        #expect(context.contains("Shipped CRM"))
        #expect(context.contains("Narrow scope won"))
    }
}
