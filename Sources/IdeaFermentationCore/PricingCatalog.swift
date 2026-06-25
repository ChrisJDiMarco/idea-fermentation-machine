import Foundation

public enum PricingCatalog {
    public static let verifiedOn = "2026-06-24"

    public static let gemini = [
        LLMModel(
            provider: "Gemini",
            name: "gemini-3.1-flash-lite",
            displayName: "Gemini 3.1 Flash-Lite",
            inputCostPerMillion: 0.25,
            outputCostPerMillion: 1.50,
            pricingURL: "https://ai.google.dev/gemini-api/docs/pricing",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "Gemini",
            name: "gemini-3.5-flash",
            displayName: "Gemini 3.5 Flash",
            inputCostPerMillion: 1.50,
            outputCostPerMillion: 9.00,
            pricingURL: "https://ai.google.dev/gemini-api/docs/pricing",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "Gemini",
            name: "gemini-3.1-pro-preview",
            displayName: "Gemini 3.1 Pro Preview",
            inputCostPerMillion: 2.00,
            outputCostPerMillion: 12.00,
            pricingURL: "https://ai.google.dev/gemini-api/docs/pricing",
            verifiedOn: verifiedOn,
            supportsVision: true
        )
    ]

    public static let zai = [
        LLMModel(
            provider: "Z.ai",
            name: "glm-5.2",
            displayName: "GLM-5.2",
            inputCostPerMillion: 1.40,
            outputCostPerMillion: 4.40,
            pricingURL: "https://docs.z.ai/guides/overview/pricing",
            verifiedOn: verifiedOn
        ),
        LLMModel(
            provider: "Z.ai",
            name: "glm-4.7",
            displayName: "GLM-4.7",
            inputCostPerMillion: 0.60,
            outputCostPerMillion: 2.20,
            pricingURL: "https://docs.z.ai/guides/overview/pricing",
            verifiedOn: verifiedOn
        ),
        LLMModel(
            provider: "Z.ai",
            name: "glm-4.7-flashx",
            displayName: "GLM-4.7-FlashX",
            inputCostPerMillion: 0.07,
            outputCostPerMillion: 0.40,
            pricingURL: "https://docs.z.ai/guides/overview/pricing",
            verifiedOn: verifiedOn
        ),
        LLMModel(
            provider: "Z.ai",
            name: "glm-4.5-flash",
            displayName: "GLM-4.5-Flash",
            inputCostPerMillion: 0,
            outputCostPerMillion: 0,
            pricingURL: "https://docs.z.ai/guides/overview/pricing",
            verifiedOn: verifiedOn
        ),
        LLMModel(
            provider: "Z.ai",
            name: "glm-4.5-air",
            displayName: "GLM-4.5-Air",
            inputCostPerMillion: 0.20,
            outputCostPerMillion: 1.10,
            pricingURL: "https://docs.z.ai/guides/overview/pricing",
            verifiedOn: verifiedOn
        ),
        LLMModel(
            provider: "Z.ai",
            name: "glm-4.6",
            displayName: "GLM-4.6",
            inputCostPerMillion: 0.60,
            outputCostPerMillion: 2.20,
            pricingURL: "https://docs.z.ai/guides/overview/pricing",
            verifiedOn: verifiedOn
        )
    ]

    public static let kimi = [
        LLMModel(
            provider: "Kimi",
            name: "kimi-k2.7",
            displayName: "Kimi K2.7",
            inputCostPerMillion: nil,
            outputCostPerMillion: nil,
            pricingURL: "https://platform.kimi.ai/docs/pricing/chat",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "Kimi",
            name: "kimi-k2.6",
            displayName: "Kimi K2.6",
            inputCostPerMillion: nil,
            outputCostPerMillion: nil,
            pricingURL: "https://platform.kimi.ai/docs/pricing/chat-k26",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "Kimi",
            name: "moonshot-v1-128k",
            displayName: "Moonshot V1 128K",
            inputCostPerMillion: nil,
            outputCostPerMillion: nil,
            pricingURL: "https://platform.kimi.ai/docs/pricing/chat-v1",
            verifiedOn: verifiedOn
        )
    ]

    public static let openai = [
        LLMModel(
            provider: "OpenAI",
            name: "gpt-5.4-mini",
            displayName: "GPT-5.4 Mini",
            inputCostPerMillion: 0.75,
            outputCostPerMillion: 4.50,
            pricingURL: "https://developers.openai.com/api/docs/models/gpt-5.4-mini",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "OpenAI",
            name: "gpt-5.5",
            displayName: "GPT-5.5",
            inputCostPerMillion: 5.00,
            outputCostPerMillion: 30.00,
            pricingURL: "https://developers.openai.com/api/docs/models/gpt-5.5",
            verifiedOn: verifiedOn,
            supportsVision: true
        )
    ]

    public static let anthropic = [
        LLMModel(
            provider: "Claude",
            name: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            inputCostPerMillion: 3.00,
            outputCostPerMillion: 15.00,
            pricingURL: "https://docs.anthropic.com/en/docs/about-claude/models/overview",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "Claude",
            name: "claude-opus-4-8",
            displayName: "Claude Opus 4.8",
            inputCostPerMillion: 5.00,
            outputCostPerMillion: 25.00,
            pricingURL: "https://docs.anthropic.com/en/docs/about-claude/models/overview",
            verifiedOn: verifiedOn,
            supportsVision: true
        ),
        LLMModel(
            provider: "Claude",
            name: "claude-fable-5",
            displayName: "Claude Fable 5",
            inputCostPerMillion: 10.00,
            outputCostPerMillion: 50.00,
            pricingURL: "https://docs.anthropic.com/en/docs/about-claude/models/overview",
            verifiedOn: verifiedOn,
            supportsVision: true
        )
    ]

    public static var all: [LLMModel] {
        gemini + zai + kimi + openai + anthropic
    }

    public static func openAICompatible(_ settings: ProviderSettings) -> [LLMModel] {
        [
            LLMModel(
                provider: settings.fallbackProviderLabel,
                name: settings.fallbackModelName,
                displayName: settings.fallbackModelName,
                inputCostPerMillion: settings.fallbackInputCostPerMillion,
                outputCostPerMillion: settings.fallbackOutputCostPerMillion,
                pricingURL: settings.fallbackBaseURL,
                verifiedOn: "user-configured"
            )
        ]
    }
}

public enum CostEstimator {
    public static func estimate(model: LLMModel, inputTokens: Int, outputTokens: Int) -> Double? {
        guard let input = model.inputCostPerMillion, let output = model.outputCostPerMillion else {
            return nil
        }
        return (Double(inputTokens) / 1_000_000 * input) + (Double(outputTokens) / 1_000_000 * output)
    }

    public static func roughTokenCount(_ text: String) -> Int {
        max(1, Int(ceil(Double(text.count) / 4.0)))
    }
}

public struct ModelRouter: Sendable {
    public var models: [LLMModel]
    public var budget: AppBudget
    public var providerPriority: [String]
    /// When non-empty, routing only considers providers the operator actually has
    /// keys for, so a queued cloud job is always runnable instead of being routed
    /// to a provider that fails at run time with "add an API key first". An empty
    /// set (the default) means "no key information" → consider every provider.
    public var availableProviders: Set<String>

    public init(
        models: [LLMModel] = PricingCatalog.all,
        budget: AppBudget = AppBudget(),
        providerPriority: [String] = ["Z.ai", "Gemini", "Kimi", "OpenAI", "Claude"],
        availableProviders: Set<String> = []
    ) {
        self.models = models
        self.budget = budget
        self.providerPriority = providerPriority
        self.availableProviders = availableProviders
    }

    public func route(taskClass: ModelTaskClass, inputTokens: Int, outputTokens: Int) -> ModelRoute {
        let capable = models.filter { model in
            switch taskClass {
            case .extract, .tag, .summarize:
                true
            case .connect, .critique, .scoreRipeness:
                model.name.contains("air") || model.name.contains("flash") || model.name.contains("glm-4.6") || model.name.contains("glm-4.7") || model.name.contains("glm-5") || model.name.contains("gemini-3.5") || model.name.contains("gpt-5.4-mini") || model.name.contains("sonnet") || model.name.contains("opus") || model.name.contains("fable")
            case .prototypeBrief:
                model.name.contains("pro") || model.name.contains("glm-4.6") || model.name.contains("glm-4.7") || model.name.contains("glm-5") || model.name.contains("kimi") || model.name.contains("gpt-5") || model.name.contains("claude") || model.name.contains("sonnet") || model.name.contains("opus") || model.name.contains("fable")
            }
        }

        // Prefer models from providers the operator can actually run. If that
        // leaves nothing (e.g. only an unmatched custom fallback key), fall back to
        // every capable model so a route is always produced.
        let keyed = availableProviders.isEmpty ? capable : capable.filter { availableProviders.contains($0.provider) }
        let candidates = keyed.isEmpty ? capable : keyed

        let sorted = candidates.sorted { lhs, rhs in
            let lhsCost = CostEstimator.estimate(model: lhs, inputTokens: inputTokens, outputTokens: outputTokens) ?? .greatestFiniteMagnitude
            let rhsCost = CostEstimator.estimate(model: rhs, inputTokens: inputTokens, outputTokens: outputTokens) ?? .greatestFiniteMagnitude
            if lhsCost == rhsCost {
                return priority(lhs.provider) < priority(rhs.provider)
            }
            return lhsCost < rhsCost
        }

        let selected = sorted.first ?? models[0]
        let cost = CostEstimator.estimate(model: selected, inputTokens: inputTokens, outputTokens: outputTokens)
        let needsApproval = taskClass == .prototypeBrief || (cost ?? budget.approvalThresholdUSD + 1) > budget.approvalThresholdUSD
        return ModelRoute(
            provider: selected.provider,
            model: selected.name,
            taskClass: taskClass,
            rationale: "Selected cheapest configured model capable of \(taskClass.rawValue).",
            estimatedCostUSD: cost,
            needsApproval: needsApproval
        )
    }

    private func priority(_ provider: String) -> Int {
        providerPriority.firstIndex(of: provider) ?? Int.max
    }
}
