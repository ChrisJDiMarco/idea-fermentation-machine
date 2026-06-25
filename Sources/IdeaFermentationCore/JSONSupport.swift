import Foundation

enum JSONSupport {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, from string: String?) throws -> T {
        guard let string, let data = string.data(using: .utf8) else {
            throw IdeaStoreError.invalidStoredJSON
        }
        return try decoder.decode(type, from: data)
    }
}

public enum IdeaStoreError: Error, LocalizedError, Equatable {
    case sqlite(String)
    case invalidStoredJSON
    case notFound
    case duplicate
    case unsupportedFile(URL)

    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): message
        case .invalidStoredJSON: "Stored JSON could not be decoded."
        case .notFound: "Record not found."
        case .duplicate: "A matching record already exists."
        case .unsupportedFile(let url): "Unsupported source file: \(url.lastPathComponent)"
        }
    }
}
