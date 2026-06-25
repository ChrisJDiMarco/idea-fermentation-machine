import Foundation
import IdeaFermentationCore
import Network

public extension Notification.Name {
    /// Posted on the main actor after a successful web capture so the UI can reload.
    static let ifmCaptureDidArrive = Notification.Name("ifmCaptureDidArrive")
}

/// A loopback-only HTTP server that lets the Chrome extension POST captured pages
/// to the running app. Everything runs on the main actor (listener and
/// connections use `DispatchQueue.main`) so all `IdeaStore` access — which is not
/// thread-safe — stays on the single actor the rest of the app already uses. For
/// the small, capped capture payloads this is effectively free.
@MainActor
public final class CaptureServer: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var activePort = 0
    @Published public private(set) var lastError: String?
    @Published public private(set) var token: String

    private let store: IdeaStore
    private var listener: NWListener?
    private var listenerGeneration = 0
    private var connections: Set<CaptureConnection> = []

    private let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"

    public init(store: IdeaStore) {
        self.store = store
        self.token = CaptureServer.loadOrCreateToken()
    }

    public var currentToken: String { token }

    public func pairingInfo() -> String {
        "host=127.0.0.1\nport=\(activePort == 0 ? CaptureServerConfig.defaultPort : activePort)\ntoken=\(token)"
    }

    // MARK: Lifecycle

    public func startIfEnabled() {
        let config = (try? store.loadCaptureServerConfig()) ?? CaptureServerConfig()
        guard config.isEnabled else { return }
        startListener(on: UInt16(clamping: config.port), allowFallback: true)
    }

    public func setEnabled(_ enabled: Bool) {
        var config = (try? store.loadCaptureServerConfig()) ?? CaptureServerConfig()
        config.isEnabled = enabled
        try? store.saveCaptureServerConfig(config)
        if enabled {
            if listener == nil { startListener(on: UInt16(clamping: config.port), allowFallback: true) }
        } else {
            stop()
        }
    }

    public func regenerateToken() {
        let fresh = CaptureAuth.generateToken()
        try? KeychainStore.save(fresh, for: .captureServerToken)
        token = fresh
    }

    public func stop() {
        listenerGeneration += 1 // invalidate any in-flight callbacks from the listener we're tearing down
        for connection in connections { connection.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: Listener

    private func startListener(on port: UInt16, allowFallback: Bool) {
        do {
            // Generation guard: when the fallback path replaces a listener, the old
            // one's late .cancelled/.ready callbacks must be ignored so they can't
            // clobber the new listener's status (they both deliver on .main with no
            // ordering guarantee).
            listenerGeneration += 1
            let generation = listenerGeneration

            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback // loopback only — refuses non-local interfaces
            parameters.allowLocalEndpointReuse = false   // want bind to FAIL if taken, so fallback triggers
            let endpointPort: NWEndpoint.Port = port == 0 ? .any : (NWEndpoint.Port(rawValue: port) ?? .any)
            let listener = try NWListener(using: parameters, on: endpointPort)
            listener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated {
                    guard let self, self.listenerGeneration == generation else { return }
                    self.handleListenerState(state, allowFallback: allowFallback)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated {
                    guard let self, self.listenerGeneration == generation else { return }
                    self.accept(connection)
                }
            }
            self.listener = listener
            listener.start(queue: .main)
        } catch {
            lastError = "Could not start browser connector: \(error.localizedDescription)"
        }
    }

    private func handleListenerState(_ state: NWListener.State, allowFallback: Bool) {
        switch state {
        case .ready:
            if let port = listener?.port { activePort = Int(port.rawValue); persistPort(Int(port.rawValue)) }
            isRunning = true
            lastError = nil
        case .failed(let error):
            isRunning = false
            listener?.cancel()
            listener = nil
            if allowFallback, isAddressInUse(error) {
                startListener(on: 0, allowFallback: false) // OS picks a free port
            } else {
                lastError = "Browser connector failed: \(error.localizedDescription)"
            }
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        let handler = CaptureConnection(
            connection: connection,
            respond: { [weak self] request in self?.handle(request) ?? HTTPResponse.text(status: 503, message: "Server stopping", allowOrigin: nil) },
            onClose: { [weak self] handler in self?.connections.remove(handler) }
        )
        connections.insert(handler)
        handler.start()
    }

    // MARK: Routing (pure decision in Core, side effects here on the main actor)

    private func handle(_ request: HTTPRequest) -> HTTPResponse {
        switch CaptureRouter.decide(request, token: token) {
        case .health:
            return HTTPResponse.json(status: 200, value: HealthResponse(ok: true, name: "IdeaFermentationMachine", version: appVersion), allowOrigin: nil)
        case .preflight(let origin):
            return HTTPResponse.preflight(allowOrigin: origin)
        case .reject(let status, let message, let origin):
            return HTTPResponse.text(status: status, message: message, allowOrigin: origin)
        case .capture(let payload, let origin):
            do {
                let taste = TasteSignals(profile: (try? store.loadAutonomyProfile()) ?? AutonomyProfile())
                let result = try CaptureIntake.ingest(payload, into: store, taste: taste)
                NotificationCenter.default.post(name: .ifmCaptureDidArrive, object: nil)
                return HTTPResponse.json(status: 201, value: result, allowOrigin: origin)
            } catch {
                return HTTPResponse.text(status: 500, message: "Capture failed: \(error.localizedDescription)", allowOrigin: origin)
            }
        }
    }

    // MARK: Helpers

    private func persistPort(_ port: Int) {
        var config = (try? store.loadCaptureServerConfig()) ?? CaptureServerConfig()
        guard config.port != port else { return }
        config.port = port
        try? store.saveCaptureServerConfig(config)
    }

    private func isAddressInUse(_ error: NWError) -> Bool {
        if case let .posix(code) = error { return code == .EADDRINUSE }
        return false
    }

    private static func loadOrCreateToken() -> String {
        if let existing = KeychainStore.load(.captureServerToken) { return existing }
        let token = CaptureAuth.generateToken()
        try? KeychainStore.save(token, for: .captureServerToken)
        return token
    }
}

private struct HealthResponse: Encodable {
    var ok: Bool
    var name: String
    var version: String
}

/// One in-flight connection: accumulates bytes, parses incrementally, responds once, closes.
@MainActor
final class CaptureConnection: Hashable {
    private nonisolated let id = UUID()
    private let connection: NWConnection
    private let respond: (HTTPRequest) -> HTTPResponse
    private let onClose: (CaptureConnection) -> Void
    private var buffer = Data()
    private var responded = false
    private let maxTotalBytes = HTTPRequestParser.maxHeaderBytes + HTTPRequestParser.maxBodyBytes + 1024

    init(connection: NWConnection, respond: @escaping (HTTPRequest) -> HTTPResponse, onClose: @escaping (CaptureConnection) -> Void) {
        self.connection = connection
        self.respond = respond
        self.onClose = onClose
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                if case .failed = state { self.finish() }
                if case .cancelled = state { self.onClose(self) }
            }
        }
        connection.start(queue: .main)
        receive()
        // Idle guard: never let a half-open socket pin a connection forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, !self.responded else { return }
            self.finish()
        }
    }

    func cancel() { connection.cancel() }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let data, !data.isEmpty { self.buffer.append(data) }
                self.process(isComplete: isComplete, error: error)
            }
        }
    }

    private func process(isComplete: Bool, error: NWError?) {
        if error != nil { finish(); return }
        if buffer.count > maxTotalBytes {
            send(HTTPResponse.text(status: 413, message: "Payload too large", allowOrigin: nil))
            return
        }
        switch HTTPRequestParser.parse(buffer) {
        case .needMore:
            if isComplete { finish() } else { receive() }
        case .failure(let status, let message):
            send(HTTPResponse.text(status: status, message: message, allowOrigin: nil))
        case .complete(let request):
            send(respond(request))
        }
    }

    private func send(_ response: HTTPResponse) {
        guard !responded else { return }
        responded = true
        connection.send(content: response.serialized(), completion: .contentProcessed { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        })
    }

    private func finish() {
        connection.cancel()
        onClose(self)
    }

    nonisolated static func == (lhs: CaptureConnection, rhs: CaptureConnection) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A minimal HTTP response builder.
struct HTTPResponse {
    var status: Int
    var reason: String
    var headers: [String: String]
    var body: Data

    func serialized() -> Data {
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        var allHeaders = headers
        allHeaders["Content-Length"] = "\(body.count)"
        allHeaders["Connection"] = "close"
        for (key, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            head += "\(key): \(value)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }

    private static func corsHeaders(_ allowOrigin: String?) -> [String: String] {
        guard let allowOrigin else { return [:] }
        return [
            "Access-Control-Allow-Origin": allowOrigin,
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Authorization, Content-Type",
            "Access-Control-Max-Age": "600",
            "Vary": "Origin"
        ]
    }

    static func json<T: Encodable>(status: Int, value: T, allowOrigin: String?) -> HTTPResponse {
        let body = (try? JSONEncoder().encode(value)) ?? Data("{}".utf8)
        var headers = corsHeaders(allowOrigin)
        headers["Content-Type"] = "application/json; charset=utf-8"
        return HTTPResponse(status: status, reason: reason(for: status), headers: headers, body: body)
    }

    static func text(status: Int, message: String, allowOrigin: String?) -> HTTPResponse {
        var headers = corsHeaders(allowOrigin)
        headers["Content-Type"] = "text/plain; charset=utf-8"
        return HTTPResponse(status: status, reason: reason(for: status), headers: headers, body: Data(message.utf8))
    }

    static func preflight(allowOrigin: String?) -> HTTPResponse {
        HTTPResponse(status: 204, reason: reason(for: 204), headers: corsHeaders(allowOrigin), body: Data())
    }

    private static func reason(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 411: "Length Required"
        case 413: "Payload Too Large"
        case 431: "Request Header Fields Too Large"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        default: "OK"
        }
    }
}
