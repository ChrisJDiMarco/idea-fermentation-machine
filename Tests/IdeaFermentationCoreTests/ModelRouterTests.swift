import Testing
@testable import IdeaFermentationCore

@Suite("Model routing and cost")
struct ModelRouterTests {
    @Test func cheapTasksUseCheapestCapableModel() {
        let router = ModelRouter()
        let route = router.route(taskClass: .tag, inputTokens: 1_000, outputTokens: 500)
        #expect(route.model == "glm-4.5-flash")
        #expect(route.needsApproval == false)
    }

    @Test func prototypeBriefsRequireApproval() {
        let router = ModelRouter(budget: AppBudget(approvalThresholdUSD: 99))
        let route = router.route(taskClass: .prototypeBrief, inputTokens: 1_000, outputTokens: 1_000)
        #expect(route.needsApproval)
    }

    @Test func estimatesKnownPricing() {
        let model = PricingCatalog.zai.first { $0.name == "glm-4.6" }!
        let estimate = CostEstimator.estimate(model: model, inputTokens: 1_000_000, outputTokens: 1_000_000) ?? 0
        #expect(abs(estimate - 2.8) < 0.0001)
    }

    @Test func catalogIncludesVerifiedV2ProvidersAndFallback() {
        #expect(PricingCatalog.zai.contains { $0.name == "glm-5.2" })
        #expect(PricingCatalog.zai.contains { $0.name == "glm-4.7-flashx" })
        #expect(PricingCatalog.kimi.first { $0.name == "kimi-k2.7" }?.inputCostPerMillion == nil)
        #expect(PricingCatalog.openai.contains { $0.name == "gpt-5.5" })
        #expect(PricingCatalog.anthropic.contains { $0.name == "claude-opus-4-8" })
        #expect(PricingCatalog.anthropic.contains { $0.name == "claude-fable-5" })

        let settings = ProviderSettings(fallbackProviderLabel: "Local Gateway", fallbackBaseURL: "http://localhost:11434/v1/", fallbackModelName: "qwen3")
        let providers = ProviderFactory.defaultProviders(settings: settings)
        #expect(providers.contains { $0.providerName == "OpenAI" })
        #expect(providers.contains { $0.providerName == "Claude" })
        #expect(providers.contains { $0.providerName == "Local Gateway" })
    }

    @Test func premiumModelsAreAvailableButNotUsedForCheapTasks() {
        let router = ModelRouter()
        let route = router.route(taskClass: .tag, inputTokens: 2_000, outputTokens: 800)

        #expect(route.provider == "Z.ai")
        #expect(route.model != "gpt-5.5")
        #expect(route.model != "claude-fable-5")
        #expect(route.needsApproval == false)
    }

    @Test func premiumOnlyRoutesRequireApproval() {
        let premiumModels = PricingCatalog.openai.filter { $0.name == "gpt-5.5" }
        let router = ModelRouter(models: premiumModels, budget: AppBudget(approvalThresholdUSD: 0.001))
        let route = router.route(taskClass: .prototypeBrief, inputTokens: 1_000, outputTokens: 1_000)

        #expect(route.provider == "OpenAI")
        #expect(route.model == "gpt-5.5")
        #expect(route.needsApproval)
    }

    @Test func judgmentTasksRouteToStrongestAvailableKey() {
        // Operator holds both a flash-tier and a premium key. Judgment work should
        // land on the strongest one, not the cheapest — otherwise the premium key
        // the operator paid for never gets used.
        let router = ModelRouter(availableProviders: ["Z.ai", "Claude"])
        let critique = router.route(taskClass: .critique, inputTokens: 1_500, outputTokens: 800)
        #expect(critique.model == "claude-opus-4-8")

        let connect = router.route(taskClass: .connect, inputTokens: 1_500, outputTokens: 800)
        #expect(connect.model == "claude-opus-4-8")

        // Bulk work stays cheap even with a premium key available.
        let tag = router.route(taskClass: .tag, inputTokens: 1_500, outputTokens: 800)
        #expect(tag.provider == "Z.ai")
        #expect(tag.model != "claude-opus-4-8")
    }

    @Test func judgmentFallsBackToBestCheapModelWithoutPremiumKeys() {
        // With only Z.ai keyed, judgment work still picks Z.ai's strongest tier.
        let router = ModelRouter(availableProviders: ["Z.ai"])
        let critique = router.route(taskClass: .critique, inputTokens: 1_500, outputTokens: 800)
        #expect(critique.provider == "Z.ai")
        #expect(critique.model.contains("glm-5") || critique.model.contains("glm-4.7"))
    }

    @Test func kimiOnlyOperatorCanCloudCritique() {
        // A Kimi-only operator must be able to run cloud critiques on their own key
        // rather than being silently forced to the local heuristic.
        let router = ModelRouter(availableProviders: ["Kimi"])
        let critique = router.route(taskClass: .critique, inputTokens: 1_000, outputTokens: 800)
        #expect(critique.provider == "Kimi")
    }
}
