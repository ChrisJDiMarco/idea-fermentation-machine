import CryptoKit
import Foundation

public enum TextHashing {
    public static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func sha256(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(normalized(text).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
