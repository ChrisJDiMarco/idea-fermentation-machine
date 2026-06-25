import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Web search providers")
struct WebSearchProviderTests {
    @Test func firecrawlSearchResponseParsesSignals() throws {
        let data = Data("""
        {
          "success": true,
          "data": [
            {
              "title": "Ambient agents are arriving",
              "url": "https://example.com/ambient-agents",
              "description": "A useful market signal.",
              "markdown": "Longer article text."
            }
          ]
        }
        """.utf8)

        let signals = try FirecrawlSearchProvider.parseSignals(data: data)

        #expect(signals.count == 1)
        #expect(signals[0].title == "Ambient agents are arriving")
        #expect(signals[0].url == "https://example.com/ambient-agents")
        #expect(signals[0].kind == .article)
    }

    @Test func openAIWebSearchResponseParsesOutputText() throws {
        let data = Data("""
        {
          "output": [
            {
              "type": "message",
              "content": [
                {
                  "type": "output_text",
                  "text": "1. Ambient widgets - https://example.com/widgets - People are asking for passive capture tools."
                }
              ]
            }
          ]
        }
        """.utf8)

        let signals = try OpenAIWebSearchProvider.parseSignals(data: data, fallbackQuery: "ambient widgets")

        #expect(signals.count == 1)
        #expect(signals[0].title.contains("OpenAI web search"))
        #expect(signals[0].summary.contains("Ambient widgets"))
        #expect(signals[0].kind == .article)
    }
}
