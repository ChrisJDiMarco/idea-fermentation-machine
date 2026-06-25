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

public struct BeautifulSoupSearchProvider: WebSearchProvider {
    public let providerName = "BeautifulSoup HTML Fallback"

    public init() {}

    public func search(query: String, limit: Int = 3, apiKey: String = "") async throws -> [ScoutSignal] {
        guard var components = URLComponents(string: "https://duckduckgo.com/html/") else { return [] }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("IdeaFermentationMachine/1.0 (+local scout; polite single-request fallback)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await IFMNetworking.session.data(for: request)
        try validateSearchResponse(response, provider: providerName, data: data)
        let html = String(data: data, encoding: .utf8) ?? ""
        return Self.parseSignals(html: html, limit: min(max(limit, 1), 3))
    }

    static func parseSignals(html: String, limit: Int) -> [ScoutSignal] {
        let pattern = #"<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        let matches = regexMatches(pattern, in: html)
        return matches.enumerated().compactMap { index, match in
            guard index < limit,
                  let href = capture(1, in: html, match: match),
                  let titleHTML = capture(2, in: html, match: match)
            else { return nil }
            let tailStart = match.range.location + match.range.length
            let tailEnd = index + 1 < matches.count ? matches[index + 1].range.location : html.utf16.count
            let tail = substring(html, NSRange(location: tailStart, length: max(0, tailEnd - tailStart))) ?? ""
            let title = htmlText(titleHTML)
            let summary = snippet(from: tail) ?? extractedURL(from: href) ?? title
            guard !title.isEmpty else { return nil }
            return ScoutSignal(title: title, summary: summary, url: extractedURL(from: href), kind: .article)
        }
    }

    private static func snippet(from html: String) -> String? {
        let pattern = #"class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</"#
        guard let match = regexMatches(pattern, in: html).first,
              let raw = capture(1, in: html, match: match)
        else { return nil }
        let text = htmlText(raw)
        return text.isEmpty ? nil : text
    }

    private static func extractedURL(from raw: String) -> String? {
        var value = htmlDecode(raw)
        if value.hasPrefix("//") { value = "https:" + value }
        if value.hasPrefix("/") { value = "https://duckduckgo.com" + value }
        guard let url = URL(string: value) else { return nil }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let decoded = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
           !decoded.isEmpty {
            return decoded
        }
        return url.host?.contains("duckduckgo.com") == true ? nil : value
    }

    private static func htmlText(_ html: String) -> String {
        collapseWhitespace(htmlDecode(html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)))
    }

    private static func htmlDecode(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func regexMatches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]))
            .map { $0.matches(in: text, range: NSRange(text.startIndex..., in: text)) } ?? []
    }

    private static func capture(_ index: Int, in text: String, match: NSTextCheckingResult) -> String? {
        substring(text, match.range(at: index))
    }

    private static func substring(_ text: String, _ range: NSRange) -> String? {
        guard let range = Range(range, in: text) else { return nil }
        return String(text[range])
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
