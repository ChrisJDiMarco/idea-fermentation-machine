import Foundation

/// The security + routing decision for one parsed request, kept pure (no
/// networking, no store) so the access-control rules are unit-testable. The
/// bearer token is the real defense; the Host/Origin checks are defense-in-depth.
public enum CaptureRouteDecision: Equatable, Sendable {
    case health
    case preflight(allowOrigin: String?)
    case capture(CapturePayload, allowOrigin: String?)
    case reject(status: Int, message: String, allowOrigin: String?)
}

public enum CaptureRouter {
    public static let allowedHosts: Set<String> = ["127.0.0.1", "localhost"]

    public static func decide(_ request: HTTPRequest, token: String) -> CaptureRouteDecision {
        let echoOrigin = allowedOrigin(request.origin)

        // A real web page must never reach our endpoints, even with CORS blocked
        // client-side — reject web origins outright (the request still has a side
        // effect server-side otherwise).
        if let origin = request.origin, isWebOrigin(origin) {
            return .reject(status: 403, message: "Forbidden origin", allowOrigin: nil)
        }

        // CORS preflight is unauthenticated and side-effect-free.
        if request.method == "OPTIONS" {
            return .preflight(allowOrigin: echoOrigin)
        }

        let host = (request.host ?? "").split(separator: ":").first.map(String.init)?.lowercased() ?? ""
        let hostAllowed = allowedHosts.contains(host)

        switch (request.method, request.path) {
        case ("GET", "/health"):
            guard hostAllowed else { return .reject(status: 403, message: "Forbidden host", allowOrigin: echoOrigin) }
            return .health
        case ("POST", "/capture"):
            guard hostAllowed else { return .reject(status: 403, message: "Forbidden host", allowOrigin: echoOrigin) }
            guard let provided = request.bearerToken, !token.isEmpty, CaptureAuth.constantTimeEquals(provided, token) else {
                return .reject(status: 401, message: "Unauthorized", allowOrigin: echoOrigin)
            }
            guard let payload = try? JSONDecoder().decode(CapturePayload.self, from: request.body),
                  !payload.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .reject(status: 400, message: "Invalid capture payload", allowOrigin: echoOrigin)
            }
            return .capture(payload, allowOrigin: echoOrigin)
        case (_, "/health"), (_, "/capture"):
            return .reject(status: 405, message: "Method not allowed", allowOrigin: echoOrigin)
        default:
            return .reject(status: 404, message: "Not found", allowOrigin: echoOrigin)
        }
    }

    /// The Origin to echo in CORS headers — only the extension's own origin, never a web origin.
    public static func allowedOrigin(_ origin: String?) -> String? {
        guard let origin else { return nil }
        return origin.hasPrefix("chrome-extension://") ? origin : nil
    }

    public static func isWebOrigin(_ origin: String) -> Bool {
        let lowered = origin.lowercased()
        return lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
    }
}
