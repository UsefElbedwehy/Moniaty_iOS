import Foundation
import CryptoKit

/// Nonce helpers for Sign in with Apple. A random nonce is generated per attempt; its SHA-256
/// hex digest is sent in the Apple request, and the RAW nonce is sent to Supabase alongside the
/// identity token so the backend can verify the token wasn't replayed.
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let byte = UInt8.random(in: 0...255)
            if Int(byte) < charset.count {
                result.append(charset[Int(byte)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
