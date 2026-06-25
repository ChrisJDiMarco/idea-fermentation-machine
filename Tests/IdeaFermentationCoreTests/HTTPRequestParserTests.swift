import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("HTTP request parser")
struct HTTPRequestParserTests {
    private func bytes(_ string: String) -> Data { Data(string.utf8) }

    @Test func parsesValidCapturePost() {
        let body = #"{"url":"https://x.com"}"#
        let raw = "POST /capture HTTP/1.1\r\nHost: 127.0.0.1:51720\r\nAuthorization: Bearer secret-token\r\nOrigin: chrome-extension://abc\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        guard case let .complete(request) = HTTPRequestParser.parse(bytes(raw)) else {
            Issue.record("expected complete")
            return
        }
        #expect(request.method == "POST")
        #expect(request.path == "/capture")
        #expect(request.bearerToken == "secret-token")
        #expect(request.origin == "chrome-extension://abc")
        #expect(request.host == "127.0.0.1:51720")
        #expect(String(data: request.body, encoding: .utf8) == body)
    }

    @Test func needsMoreWhenHeadersIncomplete() {
        #expect(HTTPRequestParser.parse(bytes("POST /capture HTTP/1.1\r\nHost: 127.0.0.1")) == .needMore)
    }

    @Test func needsMoreWhenBodyIncomplete() {
        let raw = "POST /capture HTTP/1.1\r\nContent-Length: 50\r\n\r\nonly-ten--"
        #expect(HTTPRequestParser.parse(bytes(raw)) == .needMore)
    }

    @Test func bodylessGetHealthCompletesImmediately() {
        guard case let .complete(request) = HTTPRequestParser.parse(bytes("GET /health HTTP/1.1\r\nHost: 127.0.0.1:51720\r\n\r\n")) else {
            Issue.record("expected complete")
            return
        }
        #expect(request.method == "GET")
        #expect(request.path == "/health")
        #expect(request.body.isEmpty)
    }

    @Test func optionsPreflightCompletes() {
        guard case let .complete(request) = HTTPRequestParser.parse(bytes("OPTIONS /capture HTTP/1.1\r\nHost: x\r\n\r\n")) else {
            Issue.record("expected complete")
            return
        }
        #expect(request.method == "OPTIONS")
    }

    @Test func stripsQueryFromPath() {
        guard case let .complete(request) = HTTPRequestParser.parse(bytes("GET /health?probe=1 HTTP/1.1\r\nHost: x\r\n\r\n")) else {
            Issue.record("expected complete")
            return
        }
        #expect(request.path == "/health")
        #expect(request.rawTarget == "/health?probe=1")
    }

    @Test func rejectsChunkedEncoding() {
        let raw = "POST /capture HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"
        #expect(HTTPRequestParser.parse(bytes(raw)) == .failure(status: 400, message: "Chunked transfer encoding is not supported"))
    }

    @Test func rejectsPostWithoutContentLength() {
        #expect(HTTPRequestParser.parse(bytes("POST /capture HTTP/1.1\r\nHost: x\r\n\r\n")) == .failure(status: 411, message: "Length required"))
    }

    @Test func rejectsOversizedBody() {
        let raw = "POST /capture HTTP/1.1\r\nContent-Length: \(HTTPRequestParser.maxBodyBytes + 1)\r\n\r\n"
        #expect(HTTPRequestParser.parse(bytes(raw)) == .failure(status: 413, message: "Payload too large"))
    }

    @Test func constantTimeEqualsBehavesAsValueEquality() {
        #expect(CaptureAuth.constantTimeEquals("abcdef", "abcdef"))
        #expect(!CaptureAuth.constantTimeEquals("abcdef", "abcdeg"))
        #expect(!CaptureAuth.constantTimeEquals("abc", "abcdef"))
        #expect(!CaptureAuth.constantTimeEquals("", ""))
    }

    @Test func generatedTokensAreUniqueAndHex() {
        let first = CaptureAuth.generateToken()
        let second = CaptureAuth.generateToken()
        #expect(first.count == 64)
        #expect(first != second)
        #expect(first.allSatisfy { $0.isHexDigit })
    }
}
