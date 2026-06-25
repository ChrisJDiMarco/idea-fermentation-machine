import Foundation

public struct LLMModel: Identifiable, Codable, Equatable, Sendable {
    public var id: String { "\(provider):\(name)" }
    public var provider: String
    public var name: String
    public var displayName: String
    public var inputCostPerMillion: Double?
    public var outputCostPerMillion: Double?
    public var pricingURL: String
    public var verifiedOn: String
    public var supportsVision: Bool
    public var supportsJSON: Bool

    public init(provider: String, name: String, displayName: String, inputCostPerMillion: Double?, outputCostPerMillion: Double?, pricingURL: String, verifiedOn: String, supportsVision: Bool = false, supportsJSON: Bool = true) {
        self.provider = provider
        self.name = name
        self.displayName = displayName
        self.inputCostPerMillion = inputCostPerMillion
        self.outputCostPerMillion = outputCostPerMillion
        self.pricingURL = pricingURL
        self.verifiedOn = verifiedOn
        self.supportsVision = supportsVision
        self.supportsJSON = supportsJSON
    }
}

public struct LLMRequest: Codable, Equatable, Sendable {
    public var taskClass: ModelTaskClass
    public var prompt: String
    public var input: String
    public var maxOutputTokens: Int
    public var requiresApproval: Bool

    public init(taskClass: ModelTaskClass, prompt: String, input: String, maxOutputTokens: Int = 1_000, requiresApproval: Bool = false) {
        self.taskClass = taskClass
        self.prompt = prompt
        self.input = input
        self.maxOutputTokens = maxOutputTokens
        self.requiresApproval = requiresApproval
    }
}

public struct LLMResponse: Codable, Equatable, Sendable {
    public var text: String
    public var inputTokens: Int
    public var outputTokens: Int
    public var provider: String
    public var model: String
    public var raw: String?

    public init(text: String, inputTokens: Int, outputTokens: Int, provider: String, model: String, raw: String? = nil) {
        self.text = text
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.provider = provider
        self.model = model
        self.raw = raw
    }
}

public struct ModelRoute: Codable, Equatable, Sendable {
    public var provider: String
    public var model: String
    public var taskClass: ModelTaskClass
    public var rationale: String
    public var estimatedCostUSD: Double?
    public var needsApproval: Bool

    public init(provider: String, model: String, taskClass: ModelTaskClass, rationale: String, estimatedCostUSD: Double?, needsApproval: Bool) {
        self.provider = provider
        self.model = model
        self.taskClass = taskClass
        self.rationale = rationale
        self.estimatedCostUSD = estimatedCostUSD
        self.needsApproval = needsApproval
    }
}

public protocol LLMProvider: Sendable {
    var providerName: String { get }
    var availableModels: [LLMModel] { get }
    func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse
}

public enum LLMProviderError: Error, LocalizedError, Equatable {
    case missingAPIKey(String)
    case invalidResponse(String)
    case requestFailed(String)
    case approvalRequired(Double?)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider): "\(provider) API key is missing."
        case .invalidResponse(let provider): "\(provider) returned an invalid response."
        case .requestFailed(let message): message
        case .approvalRequired(let cost): "Approval required before running estimated cost \(cost.map { String(format: "$%.4f", $0) } ?? "unknown")."
        }
    }
}
