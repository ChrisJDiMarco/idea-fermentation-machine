import Foundation

/// A parsed HTTP/1.1 request. Header keys are lowercased for case-insensitive lookup.
public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var path: String
    public var rawTarget: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, rawTarget: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.rawTarget = rawTarget
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? { headers[name.lowercased()] }

    /// The `Authorization: Bearer <token>` value, if present and well-formed.
    public var bearerToken: String? {
        guard let auth = header("authorization") else { return nil }
        let parts = auth.split(separator: " ", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else { return nil }
        let token = parts[1].trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }

    public var origin: String? { header("origin") }
    public var host: String? { header("host") }
}

public enum HTTPParseResult: Equatable, Sendable {
    case needMore
    case complete(HTTPRequest)
    case failure(status: Int, message: String)
}

/// A minimal, dependency-free HTTP/1.1 request parser for the loopback capture
/// server. It is *incremental*: feed it the bytes accumulated so far and it
/// returns `.needMore` until a full request (headers + Content-Length body) has
/// arrived. All slicing is byte-based — multibyte bodies are never mis-cut by
/// indexing into a decoded String.
public enum HTTPRequestParser {
    public static let maxHeaderBytes = 32 * 1024
    public static let maxBodyBytes = 2 * 1024 * 1024

    private static let headerTerminator = Data([0x0d, 0x0a, 0x0d, 0x0a]) // \r\n\r\n

    public static func parse(_ buffer: Data) -> HTTPParseResult {
        guard let terminator = buffer.range(of: headerTerminator) else {
            return buffer.count > maxHeaderBytes
                ? .failure(status: 431, message: "Request header fields too large")
                : .needMore
        }

        let headerData = buffer.subdata(in: buffer.startIndex..<terminator.lowerBound)
        if headerData.count > maxHeaderBytes {
            return .failure(status: 431, message: "Request header fields too large")
        }
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return .failure(status: 400, message: "Malformed request headers")
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            return .failure(status: 400, message: "Empty request line")
        }
        let requestParts = requestLine.split(separator: " ").map(String.init)
        guard requestParts.count >= 2 else {
            return .failure(status: 400, message: "Malformed request line")
        }
        let method = requestParts[0].uppercased()
        let rawTarget = requestParts[1]
        let path = String(rawTarget.split(separator: "?", maxSplits: 1).first ?? "")

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            guard !name.isEmpty else { continue }
            headers[name] = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }

        if let encoding = headers["transfer-encoding"], encoding.lowercased().contains("chunked") {
            return .failure(status: 400, message: "Chunked transfer encoding is not supported")
        }

        let bodyStart = terminator.upperBound
        let methodsWithBody: Set<String> = ["POST", "PUT", "PATCH"]
        guard methodsWithBody.contains(method) else {
            // Bodyless method: the request is complete once headers arrive.
            return .complete(HTTPRequest(method: method, path: path, rawTarget: rawTarget, headers: headers, body: Data()))
        }

        guard let lengthValue = headers["content-length"], let contentLength = Int(lengthValue), contentLength >= 0 else {
            return .failure(status: 411, message: "Length required")
        }
        if contentLength > maxBodyBytes {
            return .failure(status: 413, message: "Payload too large")
        }
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        if available < contentLength {
            return .needMore
        }
        let bodyEnd = buffer.index(bodyStart, offsetBy: contentLength)
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        return .complete(HTTPRequest(method: method, path: path, rawTarget: rawTarget, headers: headers, body: body))
    }
}
