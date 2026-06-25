import Foundation

public struct GeminiProvider: LLMProvider {
    public let providerName = "Gemini"
    public let availableModels = PricingCatalog.gemini

    public init() {}

    public func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey(providerName)
        }
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model.name):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw LLMProviderError.requestFailed("Invalid Gemini URL.") }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": "\(request.prompt)\n\n\(request.input)"]]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": request.maxOutputTokens
            ]
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await IFMNetworking.session.data(for: urlRequest)
        try validate(response: response, provider: providerName, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = object?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        guard let text = parts?.compactMap({ $0["text"] as? String }).joined(separator: "\n"), !text.isEmpty else {
            throw LLMProviderError.invalidResponse(providerName)
        }
        let inputTokens = CostEstimator.roughTokenCount(request.prompt + request.input)
        let outputTokens = CostEstimator.roughTokenCount(text)
        return LLMResponse(text: text, inputTokens: inputTokens, outputTokens: outputTokens, provider: providerName, model: model.name, raw: String(data: data, encoding: .utf8))
    }
}

public struct OpenAICompatibleProvider: LLMProvider {
    public var providerName: String
    public var baseURL: URL
    public var availableModels: [LLMModel]

    public init(providerName: String, baseURL: URL, models: [LLMModel]) {
        self.providerName = providerName
        self.baseURL = baseURL
        self.availableModels = models
    }

    public func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey(providerName)
        }
        let url = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model.name,
            "messages": [
                ["role": "system", "content": request.prompt],
                ["role": "user", "content": request.input]
            ],
            "max_tokens": request.maxOutputTokens
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await IFMNetworking.session.data(for: urlRequest)
        try validate(response: response, provider: providerName, data: data)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = object?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let text = message?["content"] as? String, !text.isEmpty else {
            throw LLMProviderError.invalidResponse(providerName)
        }
        let usage = object?["usage"] as? [String: Any]
        let inputTokens = usage?["prompt_tokens"] as? Int ?? CostEstimator.roughTokenCount(request.prompt + request.input)
        let outputTokens = usage?["completion_tokens"] as? Int ?? CostEstimator.roughTokenCount(text)
        return LLMResponse(text: text, inputTokens: inputTokens, outputTokens: outputTokens, provider: providerName, model: model.name, raw: String(data: data, encoding: .utf8))
    }
}

public struct OpenAIResponsesProvider: LLMProvider {
    public let providerName = "OpenAI"
    public let availableModels = PricingCatalog.openai

    public init() {}

    public func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey(providerName)
        }
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw LLMProviderError.requestFailed("Invalid OpenAI URL.")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model.name,
            "instructions": request.prompt,
            "input": request.input,
            "max_output_tokens": request.maxOutputTokens
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await IFMNetworking.session.data(for: urlRequest)
        try validate(response: response, provider: providerName, data: data)

        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = responseText(from: object), !text.isEmpty else {
            throw LLMProviderError.invalidResponse(providerName)
        }
        let usage = object?["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? CostEstimator.roughTokenCount(request.prompt + request.input)
        let outputTokens = usage?["output_tokens"] as? Int ?? CostEstimator.roughTokenCount(text)
        return LLMResponse(text: text, inputTokens: inputTokens, outputTokens: outputTokens, provider: providerName, model: model.name, raw: String(data: data, encoding: .utf8))
    }
}

public struct AnthropicProvider: LLMProvider {
    public let providerName = "Claude"
    public let availableModels = PricingCatalog.anthropic

    public init() {}

    public func send(_ request: LLMRequest, model: LLMModel, apiKey: String) async throws -> LLMResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey(providerName)
        }
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMProviderError.requestFailed("Invalid Anthropic URL.")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model.name,
            "max_tokens": request.maxOutputTokens,
            "system": request.prompt,
            "messages": [
                ["role": "user", "content": request.input]
            ]
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await IFMNetworking.session.data(for: urlRequest)
        try validate(response: response, provider: providerName, data: data)

        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let parts = object?["content"] as? [[String: Any]]
        let text = parts?.compactMap { $0["text"] as? String }.joined(separator: "\n") ?? ""
        guard !text.isEmpty else {
            throw LLMProviderError.invalidResponse(providerName)
        }
        let usage = object?["usage"] as? [String: Any]
        let inputTokens = usage?["input_tokens"] as? Int ?? CostEstimator.roughTokenCount(request.prompt + request.input)
        let outputTokens = usage?["output_tokens"] as? Int ?? CostEstimator.roughTokenCount(text)
        return LLMResponse(text: text, inputTokens: inputTokens, outputTokens: outputTokens, provider: providerName, model: model.name, raw: String(data: data, encoding: .utf8))
    }
}

public enum ProviderFactory {
    public static func defaultProviders(settings: ProviderSettings = ProviderSettings()) -> [any LLMProvider] {
        var providers: [any LLMProvider] = [
            GeminiProvider(),
            OpenAICompatibleProvider(providerName: "Z.ai", baseURL: URL(string: "https://api.z.ai/api/paas/v4/")!, models: PricingCatalog.zai),
            OpenAICompatibleProvider(providerName: "Kimi", baseURL: URL(string: "https://api.moonshot.ai/v1/")!, models: PricingCatalog.kimi),
            OpenAIResponsesProvider(),
            AnthropicProvider()
        ]
        if let url = URL(string: settings.fallbackBaseURL), !settings.fallbackModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            providers.append(OpenAICompatibleProvider(providerName: settings.fallbackProviderLabel, baseURL: url, models: PricingCatalog.openAICompatible(settings)))
        }
        return providers
    }
}

private func validate(response: URLResponse, provider: String, data: Data) throws {
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw LLMProviderError.requestFailed("\(provider) request failed: \(body)")
    }
}

private func responseText(from object: [String: Any]?) -> String? {
    if let outputText = object?["output_text"] as? String, !outputText.isEmpty {
        return outputText
    }
    let output = object?["output"] as? [[String: Any]]
    let parts = output?.flatMap { item -> [String] in
        let content = item["content"] as? [[String: Any]] ?? []
        return content.compactMap { contentItem in
            contentItem["text"] as? String
        }
    }
    return parts?.joined(separator: "\n")
}
