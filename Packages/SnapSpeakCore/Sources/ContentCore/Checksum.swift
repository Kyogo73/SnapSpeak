import Crypto
import Foundation

public enum Checksum {
    public static func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func verify(data: Data, expectedHex: String) -> Bool {
        sha256Hex(of: data).lowercased() == expectedHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
