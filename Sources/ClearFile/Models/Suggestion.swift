import Foundation
import SwiftUI

/// 智能删除建议等级。颜色越绿越安全，越红越敏感。
enum SuggestionLevel: Int, Comparable, Codable {
    case safe        // 强烈建议清理（>90 天未访问的缓存、Trash、~/Downloads 旧文件）
    case recommended // 建议清理（>30 天未访问、典型可重建缓存）
    case neutral     // 中性（最近访问过，但仍可能可清理）
    case caution     // 慎重（最近修改、Documents 中的大文件）
    case protected   // 不应该删（敏感目录、iCloud 同步、密钥/凭证）

    static func < (lhs: SuggestionLevel, rhs: SuggestionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .safe:        return "安全清理"
        case .recommended: return "建议清理"
        case .neutral:     return "可清理"
        case .caution:     return "慎重"
        case .protected:   return "保护"
        }
    }

    var color: Color {
        switch self {
        case .safe:        return .green
        case .recommended: return .blue
        case .neutral:     return .gray
        case .caution:     return .orange
        case .protected:   return .red
        }
    }
}

struct Suggestion: Equatable, Codable {
    let level: SuggestionLevel
    let reason: String
}

/// 内置规则集：基于路径模式 + 时间 + 元数据综合判断
enum SuggestionRule {
    /// 已知"删了也没事"的缓存白名单（按目录名前缀匹配）
    static let safeCacheNames: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.tencent.xinWeChat",
        "Spotify",
        "com.spotify.client",
        "Yarn", "yarn",
        "pip", "pypoetry",
        "Homebrew", "homebrew",
        "go-build",
        "Cypress",
        "Adobe",
        "JetBrains",
        "com.docker.docker",
        "com.apple.dt.Xcode"
    ]

    /// 敏感路径（绝对不应清理）— 命中关键词即标 protected
    static let protectedKeywords: [String] = [
        ".ssh", ".gnupg", "Keychains", "GnuPG",
        "iCloud", "CloudDocs", "Mobile Documents",
        ".git", ".aws", ".kube", ".npmrc",
        "Containers", "Group Containers",
        "Application Support/AddressBook",
        "Application Support/CallHistoryDB",
        "Application Support/MobileSync"
    ]

    /// 明显应该清理的目录名（高优先级 safe）
    static let definitelyJunkNames: Set<String> = [
        "Trash", ".Trash", "Crash Reports", "DiagnosticReports", "tmp", "TemporaryItems"
    ]

    // MARK: - Cache directory suggestion

    static func evaluate(cachePath: URL, sizeBytes: Int64) -> Suggestion {
        let pathStr = cachePath.path
        let name = cachePath.lastPathComponent

        if protectedKeywords.contains(where: { pathStr.contains($0) }) {
            return Suggestion(level: .protected, reason: "敏感目录 / 用户数据，不应清理")
        }
        if definitelyJunkNames.contains(name) {
            return Suggestion(level: .safe, reason: "已知可安全清理的临时文件")
        }
        if safeCacheNames.contains(where: { name.hasPrefix($0) }) {
            return Suggestion(level: .safe, reason: "已知应用缓存，可重建")
        }
        // 看最近访问时间
        let access = (try? cachePath.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date()
        let days = Calendar.current.dateComponents([.day], from: access, to: Date()).day ?? 0
        if days >= 90 {
            return Suggestion(level: .safe, reason: "已 \(days) 天未访问")
        }
        if days >= 30 {
            return Suggestion(level: .recommended, reason: "\(days) 天未访问")
        }
        if sizeBytes > 1 * 1024 * 1024 * 1024 {
            return Suggestion(level: .recommended, reason: "占用 > 1GB 的缓存")
        }
        return Suggestion(level: .neutral, reason: "近期访问过，按需清理")
    }

    // MARK: - Large file suggestion

    static func evaluate(largeFile url: URL, sizeBytes: Int64, modifiedAt: Date) -> Suggestion {
        let pathStr = url.path
        let pathLower = pathStr.lowercased()

        if protectedKeywords.contains(where: { pathStr.contains($0) }) {
            return Suggestion(level: .protected, reason: "敏感路径，不建议删除")
        }
        // iCloud 占位文件
        if let v = try? url.resourceValues(forKeys: [.isUbiquitousItemKey]),
           v.isUbiquitousItem == true {
            return Suggestion(level: .protected, reason: "iCloud 同步文件")
        }
        // 代码仓库
        if pathStr.contains("/.git/") || pathLower.hasSuffix(".key") || pathLower.hasSuffix(".pem") {
            return Suggestion(level: .protected, reason: "代码仓库 / 密钥文件")
        }

        let access = (try? url.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? modifiedAt
        let accessDays = Calendar.current.dateComponents([.day], from: access, to: Date()).day ?? 0
        let modifiedDays = Calendar.current.dateComponents([.day], from: modifiedAt, to: Date()).day ?? 0

        // 在 Downloads 里且 > 90 天没动 → 强烈建议
        if pathStr.contains("/Downloads/") && modifiedDays >= 90 {
            return Suggestion(level: .safe, reason: "下载文件夹中，\(modifiedDays) 天未修改")
        }
        // 类型判断：.dmg .iso 安装包通常装完即可删
        if [".dmg", ".iso", ".pkg", ".zip", ".xz", ".tar.gz"].contains(where: { pathLower.hasSuffix($0) }) && modifiedDays >= 30 {
            return Suggestion(level: .safe, reason: "安装包/压缩包，\(modifiedDays) 天未动")
        }
        if accessDays >= 180 {
            return Suggestion(level: .safe, reason: "已 \(accessDays) 天未访问")
        }
        if accessDays >= 90 {
            return Suggestion(level: .recommended, reason: "\(accessDays) 天未访问")
        }
        if accessDays >= 30 {
            return Suggestion(level: .neutral, reason: "\(accessDays) 天未访问")
        }
        if pathStr.contains("/Documents/") {
            return Suggestion(level: .caution, reason: "在 Documents，可能是重要文件")
        }
        return Suggestion(level: .caution, reason: "近期访问过")
    }

    /// 针对"最近文件"场景的额外判断（截图、安装包等用完即弃的）
    static func evaluate(recentFile url: URL, sizeBytes: Int64, modifiedAt: Date) -> Suggestion {
        let pathStr = url.path
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let modifiedDays = Calendar.current.dateComponents([.day], from: modifiedAt, to: Date()).day ?? 0

        // 保护规则优先
        if protectedKeywords.contains(where: { pathStr.contains($0) }) {
            return Suggestion(level: .protected, reason: "敏感路径，不建议删除")
        }
        if let v = try? url.resourceValues(forKeys: [.isUbiquitousItemKey]),
           v.isUbiquitousItem == true {
            return Suggestion(level: .protected, reason: "iCloud 同步文件")
        }

        // 截图：默认 safe（多数人不存档）
        if name.hasPrefix("screen shot") || name.hasPrefix("screenshot")
            || name.hasPrefix("截屏") || name.hasPrefix("截图") {
            return Suggestion(level: .safe, reason: "截图通常用完即可删")
        }

        // 安装包：> 1 天 = safe
        if ["dmg", "pkg", "iso", "mpkg"].contains(ext) {
            if modifiedDays >= 1 {
                return Suggestion(level: .safe, reason: "安装包，已 \(modifiedDays) 天，安装后可删")
            }
            return Suggestion(level: .recommended, reason: "安装包，安装后可删")
        }

        // 压缩包：> 7 天 = safe，否则 recommended
        if ["zip", "rar", "7z", "tar", "gz", "tgz"].contains(ext) {
            if modifiedDays >= 7 {
                return Suggestion(level: .safe, reason: "压缩包，\(modifiedDays) 天前，通常已解压")
            }
            return Suggestion(level: .recommended, reason: "压缩包，通常解压后可删")
        }

        // 废纸篓内容
        if pathStr.contains("/.Trash") {
            return Suggestion(level: .safe, reason: "已在废纸篓中")
        }

        // 录屏视频在 Movies / Desktop
        if ["mov", "mp4"].contains(ext)
            && (pathStr.contains("/Movies/") || pathStr.contains("/Desktop/")) {
            if modifiedDays >= 30 {
                return Suggestion(level: .recommended, reason: "录屏/视频，\(modifiedDays) 天前")
            }
            return Suggestion(level: .neutral, reason: "录屏/视频文件，按需保留")
        }

        // 其他：按通用规则
        return evaluate(largeFile: url, sizeBytes: sizeBytes, modifiedAt: modifiedAt)
    }
}
