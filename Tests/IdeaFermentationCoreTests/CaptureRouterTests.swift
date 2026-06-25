import Foundation
import Testing
@testable import IdeaFermentationCore

@Suite("Capture routing and access control")
struct CaptureRouterTests {
    private let token = "correct-horse-battery-staple-token"

    private func request(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) -> HTTPRequest {
        HTTPRequest(method: method, path: path, rawTarget: path, headers: headers, body: body)
    }

    private func captureBody(url: String = "https://example.com") -> Data {
        (try? JSONEncoder().encode(CapturePayload(url: url))) ?? Data()
    }

    @Test func healthIsUnauthenticatedButHostChecked() {
        let ok = CaptureRouter.decide(request(method: "GET", path: "/health", headers: ["host": "127.0.0.1:51720"]), token: token)
        #expect(ok == .health)

        let badHost = CaptureRouter.decide(request(method: "GET", path: "/health", headers: ["host": "evil.com"]), token: token)
        #expect(badHost == .reject(status: 403, message: "Forbidden host", allowOrigin: nil))
    }

    @Test func validCaptureDecodesPayload() {
        let decision = CaptureRouter.decide(
            request(method: "POST", path: "/capture", headers: ["host": "127.0.0.1", "authorization": "Bearer \(token)"], body: captureBody()),
            token: token
        )
        guard case let .capture(payload, _) = decision else {
            Issue.record("expected capture")
            return
        }
        #expect(payload.url == "https://example.com")
    }

    @Test func captureRejectsWrongToken() {
        let decision = CaptureRouter.decide(
            request(method: "POST", path: "/capture", headers: ["host": "127.0.0.1", "authorization": "Bearer wrong"], body: captureBody()),
            token: token
        )
        #expect(decision == .reject(status: 401, message: "Unauthorized", allowOrigin: nil))
    }

    @Test func captureRejectsMissingToken() {
        let decision = CaptureRouter.decide(
            request(method: "POST", path: "/capture", headers: ["host": "127.0.0.1"], body: captureBody()),
            token: token
        )
        #expect(decision == .reject(status: 401, message: "Unauthorized", allowOrigin: nil))
    }

    @Test func captureRejectsEmptyUrl() {
        let decision = CaptureRouter.decide(
            request(method: "POST", path: "/capture", headers: ["host": "127.0.0.1", "authorization": "Bearer \(token)"], body: captureBody(url: "   ")),
            token: token
        )
        #expect(decision == .reject(status: 400, message: "Invalid capture payload", allowOrigin: nil))
    }

    @Test func webOriginIsRejectedEvenWithValidToken() {
        // The crux: a malicious page's fetch must not cause the save side effect.
        let decision = CaptureRouter.decide(
            request(method: "POST", path: "/capture", headers: ["host": "127.0.0.1", "authorization": "Bearer \(token)", "origin": "https://evil.com"], body: captureBody()),
            token: token
        )
        #expect(decision == .reject(status: 403, message: "Forbidden origin", allowOrigin: nil))
    }

    @Test func extensionOriginIsEchoedForCors() {
        let origin = "chrome-extension://abcdefghijklmnop"
        let decision = CaptureRouter.decide(
            request(method: "OPTIONS", path: "/capture", headers: ["host": "127.0.0.1", "origin": origin]),
            token: token
        )
        #expect(decision == .preflight(allowOrigin: origin))
    }

    @Test func unknownPathIs404AndWrongMethodIs405() {
        #expect(CaptureRouter.decide(request(method: "GET", path: "/nope", headers: ["host": "127.0.0.1"]), token: token)
            == .reject(status: 404, message: "Not found", allowOrigin: nil))
        #expect(CaptureRouter.decide(request(method: "GET", path: "/capture", headers: ["host": "127.0.0.1"]), token: token)
            == .reject(status: 405, message: "Method not allowed", allowOrigin: nil))
    }
}
