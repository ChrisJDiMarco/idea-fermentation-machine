import Foundation

/// Shared URLSession for every outbound call (LLM providers, web search, scout).
/// `URLSession.shared` has no request timeout override, so a provider that accepts
/// the connection but never replies would hang a fermentation job — and the queue —
/// indefinitely. These bounds turn that into a surfaced, retryable error.
public enum IFMNetworking {
    public static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45      // per-request stall ceiling
        config.timeoutIntervalForResource = 120     // whole-transfer ceiling
        config.waitsForConnectivity = false         // fail fast offline rather than block
        return URLSession(configuration: config)
    }()
}
