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
}
