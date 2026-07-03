import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Taste manifold (concept space)")
struct TasteManifoldTests {
    private func idea(_ title: String, _ text: String, status: IdeaStatus) -> IdeaSeed {
        IdeaSeed(
            title: title,
            body: text,
            status: status,
            stage: status == .ready ? .readyToPrototype : .brewing,
            textHash: TextHashing.sha256(title + text + UUID().uuidString),
            embedding: LocalEmbeddings.embed(text)
        )
    }

    @Test func inactiveWithoutEnoughSignal() {
        let manifold = TasteManifold.build(
            ideas: [idea("a", "ambient capture tool", status: .ready), idea("b", "tax dashboard", status: .archived)],
            outcomes: []
        )
        #expect(!manifold.isActive)                                  // 1 per side is below the min (2)
        #expect(manifold.affinity(for: LocalEmbeddings.embed("anything")) == 0) // strict no-op
    }

    @Test func placesNewIdeasNearTheLikedRegion() {
        // Three "ambient capture" ideas are committed (ready); three "finance" ideas are
        // dropped (archived). A new capture-flavored idea should read positive.
        let liked = [
            idea("c1", "ambient capture tool for fleeting thoughts", status: .ready),
            idea("c2", "frictionless note capture from anywhere", status: .ready),
            idea("c3", "instant idea capture without opening an app", status: .ready)
        ]
        let disliked = [
            idea("f1", "quarterly tax dashboard for freelancers", status: .archived),
            idea("f2", "invoice tracker and accounting ledger", status: .archived),
            idea("f3", "expense report automation for finance teams", status: .archived)
        ]
        let manifold = TasteManifold.build(ideas: liked + disliked, outcomes: [])
        #expect(manifold.isActive)
        #expect(manifold.likedCount == 3)
        #expect(manifold.dislikedCount == 3)

        let captureLike = LocalEmbeddings.embed("a tool to capture quick notes instantly")
        let financeLike = LocalEmbeddings.embed("accounting and tax invoice tracking")
        #expect(manifold.affinity(for: captureLike) > manifold.affinity(for: financeLike))
    }

    @Test func zeroEmbeddingIsNeutral() {
        let liked = (0..<3).map { idea("l\($0)", "ambient capture \($0)", status: .ready) }
        let disliked = (0..<3).map { idea("d\($0)", "tax finance ledger \($0)", status: .archived) }
        let manifold = TasteManifold.build(ideas: liked + disliked, outcomes: [])
        #expect(manifold.affinity(for: []) == 0)
        #expect(manifold.affinity(for: [Double](repeating: 0, count: 8)) == 0)
    }

    @Test func excludingDropsTheIdeaFromItsOwnCentroid() {
        // So an idea is never scored against a centroid it helped define.
        let liked = (0..<4).map { idea("l\($0)", "ambient capture \($0)", status: .ready) }
        let disliked = (0..<3).map { idea("d\($0)", "tax finance ledger \($0)", status: .archived) }
        let all = liked + disliked

        let full = TasteManifold.build(ideas: all, outcomes: [])
        #expect(full.likedCount == 4)

        let excluded = TasteManifold.build(ideas: all, outcomes: [], excluding: liked[0].id)
        #expect(excluded.likedCount == 3)   // the scored idea is removed from its side
        #expect(excluded.dislikedCount == 3)
        #expect(excluded.isActive)          // still ≥3 each
    }

    @Test func blendWeightRampsInFromActivation() {
        func manifold(_ n: Int) -> TasteManifold {
            TasteManifold(likedCentroid: [1, 0], dislikedCentroid: [0, 1], likedCount: n, dislikedCount: n)
        }
        #expect(manifold(1).blendWeight == 0)                       // inactive (below minPerSide)
        #expect(abs(manifold(2).blendWeight - 0.125) < 0.001)       // just activated: a sliver
        #expect(abs(manifold(5).blendWeight - 0.5) < 0.001)         // matured: full half-weight
    }

    @Test func positiveOutcomeCountsAsLikedEvenIfArchived() {
        // A built idea composts to .archived but a positive outcome must keep it on the
        // LIKED side, not the disliked one.
        var built = idea("built", "shipped capture tool", status: .archived)
        let outcome = BuildOutcome(ideaID: built.id, result: .shipped, note: "")
        built.status = .archived
        let manifold = TasteManifold.build(ideas: [built], outcomes: [outcome])
        #expect(manifold.likedCount == 1)
        #expect(manifold.dislikedCount == 0)
    }
}
