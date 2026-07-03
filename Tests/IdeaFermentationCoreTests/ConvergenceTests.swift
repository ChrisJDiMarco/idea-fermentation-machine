import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Convergence & maintenance")
@MainActor
struct ConvergenceTests {
    private func idea(
        _ title: String, ripeness: Double, ageDays: Double,
        origin: IdeaOrigin = .mind, status: IdeaStatus = .fermenting,
        verified: Bool = false, now: Date
    ) -> IdeaSeed {
        IdeaSeed(
            title: title, body: "A generated body for \(title).",
            updatedAt: now.addingTimeInterval(-ageDays * 86_400),
            status: status, stage: .cooling,
            textHash: TextHashing.sha256(title + UUID().uuidString),
            embedding: LocalEmbeddings.embed(title),
            ripeness: ripeness,
            origin: origin, qualityVerified: verified
        )
    }

    @Test func archivesStaleMachineNoiseButNeverTheOperatorsOwnIdeas() throws {
        let store = try makeStore()
        let now = Date()
        try store.upsertIdea(idea("Stale mind zombie", ripeness: 20, ageDays: 40, origin: .mind, now: now))
        // A manual idea, equally stale and low-scoring, must be left completely alone —
        // the loop only ever garbage-collects its OWN output.
        try store.upsertIdea(idea("My own stale idea", ripeness: 20, ageDays: 40, origin: .manual, now: now))

        let engine = FermentationEngine(store: store)
        let archived = try engine.runMaintenance(now: now)

        #expect(archived.map(\.title) == ["Stale mind zombie"])
        let manual = try #require(store.listIdeas().first { $0.origin == .manual })
        #expect(manual.status != .archived)
    }

    @Test func sparesVerifiedRipeningAndRecentMachineIdeas() throws {
        let store = try makeStore()
        let now = Date()
        try store.upsertIdea(idea("Verified but stale", ripeness: 20, ageDays: 40, verified: true, now: now))
        try store.upsertIdea(idea("Ripening and stale", ripeness: 60, ageDays: 40, status: .ripening, now: now))
        try store.upsertIdea(idea("Fresh low-scorer", ripeness: 10, ageDays: 1, now: now))

        let engine = FermentationEngine(store: store)
        let archived = try engine.runMaintenance(now: now)

        #expect(archived.isEmpty) // quality-verified, ripening, and recent ideas are all safe
    }

    @Test func capsMachineWorkingSetByArchivingLowestValue() throws {
        let store = try makeStore()
        let now = Date()
        // Five FRESH (not stale) low-ripeness scout ideas — decay won't touch them, so this
        // isolates the working-set cap.
        for i in 0..<5 {
            try store.upsertIdea(idea("m\(i)", ripeness: Double(i * 5), ageDays: 1, origin: .scout, now: now))
        }

        let engine = FermentationEngine(store: store)
        let archived = try engine.runMaintenance(now: now, staleDays: 21, workingSetCap: 3)

        // 5 live machine ideas, cap 3 → the two lowest-ripeness (m0, m1) are reclaimed.
        #expect(Set(archived.map(\.title)) == ["m0", "m1"])
        #expect(try store.listIdeas(status: .fermenting).count == 3)
    }
}
