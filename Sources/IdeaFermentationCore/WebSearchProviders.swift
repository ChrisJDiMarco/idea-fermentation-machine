import Foundation

public protocol WebSearchProvider: Sendable {
    var providerName: String { get }
    func search(query: String, limit: Int, apiKey: String) async throws -> [ScoutSignal]
}

public struct FirecrawlSearchProvider: WebSearchProvider {
    public let providerName = "Firecrawl"

    public init() {}

    public func search(query: String, limit: Int = 5, apiKey: String) async throws -> [ScoutSignal] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey(providerName)
        }
        guard let url = URL(string: "https://api.firecrawl.dev/v2/search") else {
            throw LLMProviderError.requestFailed("Invalid Firecrawl URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "limit": limit
        ])

        let (data, response) = try await IFMNetworking.session.data(for: request)
        try validateSearchResponse(response, provider: providerName, data: data)
        return try Self.parseSignals(data: data)
    }

    public static func parseSignals(data: Data) throws -> [ScoutSignal] {
        let response = try JSONDecoder().decode(FirecrawlSearchResponse.self, from: data)
        return response.data.compactMap { item in
            let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = item.description ?? item.markdown ?? item.url ?? ""
            guard let title, !title.isEmpty, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return ScoutSignal(title: title, summary: summary, url: item.url, kind: .article)
        }
    }
}

public struct OpenAIWebSearchProvider: WebSearchProvider {
    public let providerName = "OpenAI Web Search"
    public var modelName: String

    public init(modelName: String = "gpt-5.4-mini") {
        self.modelName = modelName
    }

    public func search(query: String, limit: Int = 5, apiKey: String) async throws -> [ScoutSignal] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey(providerName)
        }
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw LLMProviderError.requestFailed("Invalid OpenAI URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let prompt = """
        Search the web for current, concrete signals about "\(query)".
        Return up to \(limit) concise bullets. Include source URLs when available.
        Focus on app ideas, user pain, new products, technical shifts, and market timing.
        """
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": modelName,
            "input": prompt,
            "tools": [["type": "web_search"]],
            "max_output_tokens": 900
        ])

        let (data, response) = try await IFMNetworking.session.data(for: request)
        try validateSearchResponse(response, provider: providerName, data: data)
        return try Self.parseSignals(data: data, fallbackQuery: query)
    }

    public static func parseSignals(data: Data, fallbackQuery: String) throws -> [ScoutSignal] {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = responseOutputText(from: object)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return [
            ScoutSignal(
                title: "OpenAI web search: \(fallbackQuery)",
                summary: text,
                kind: .article
            )
        ]
    }
}

private struct FirecrawlSearchResponse: Decodable {
    var data: [FirecrawlSearchItem]
}

private struct FirecrawlSearchItem: Decodable {
    var title: String?
    var url: String?
    var description: String?
    var markdown: String?
}

private func validateSearchResponse(_ response: URLResponse, provider: String, data: Data) throws {
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw LLMProviderError.requestFailed("\(provider) request failed: \(body)")
    }
}

private func responseOutputText(from object: [String: Any]?) -> String {
    if let outputText = object?["output_text"] as? String {
        return outputText
    }
    let output = object?["output"] as? [[String: Any]] ?? []
    let parts = output.flatMap { item -> [String] in
        let content = item["content"] as? [[String: Any]] ?? []
        return content.compactMap { contentItem in
            contentItem["text"] as? String
        }
    }
    return parts.joined(separator: "\n")
}
