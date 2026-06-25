import Foundation
import Security

/// Token generation and comparison for the loopback capture server. The token is
/// the real security boundary (loopback/Origin/Host checks are defense-in-depth),
/// so comparison is constant-time to avoid leaking it via timing.
public enum CaptureAuth {
    /// 32 cryptographically-random bytes, hex-encoded (64 chars).
    public static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // Fallback should never run in practice; still avoid a predictable token.
            for index in bytes.indices { bytes[index] = UInt8(truncatingIfNeeded: Int(arc4random_uniform(256))) }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Length-checked, fixed-iteration constant-time equality. Returns false fast
    /// only on the (non-secret) length mismatch.
    public static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count, !a.isEmpty else { return false }
        var diff: UInt8 = 0
        for index in a.indices {
            diff |= a[index] ^ b[index]
        }
        return diff == 0
    }
}
