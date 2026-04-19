import Foundation
import CryptoKit

/// HMAC-SHA256 离线 license key 验证。
/// 格式：CF-RRRR-RRRR-SSSS-SSSS
///   R = 8 位随机 hex（大写）
///   S = HMAC-SHA256(secret, R) 的前 8 位（大写）
enum LicenseKeyValidator {
    // ⚠️ 必须和 scripts/keygen.sh 中的 SECRET 保持一致
    private static let secret = "ClearFile2026!hmac@secret#key"

    /// 验证 key 格式 + HMAC 签名
    static func validate(_ key: String) -> Bool {
        // 标准化：去空格、大写
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")

        // 格式：CF-XXXX-XXXX-YYYY-YYYY（总长 22，含 4 个 -）
        let parts = cleaned.split(separator: "-")
        guard parts.count == 5,
              parts[0] == "CF",
              parts[1].count == 4,
              parts[2].count == 4,
              parts[3].count == 4,
              parts[4].count == 4 else {
            return false
        }

        // 提取随机部分和签名部分
        let randomPart = String(parts[1]) + String(parts[2])  // 8 字符
        let sigPart = String(parts[3]) + String(parts[4])      // 8 字符

        // 重新计算 HMAC
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(randomPart.utf8),
            using: key
        )
        let expectedSig = mac.map { String(format: "%02X", $0) }
            .joined()
            .prefix(8)
            .uppercased()

        return sigPart == expectedSig
    }
}
