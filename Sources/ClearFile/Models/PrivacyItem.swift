import Foundation
import SwiftUI

enum PrivacyCategory: String, Identifiable, CaseIterable {
    case safari      = "Safari"
    case chrome      = "Chrome"
    case firefox     = "Firefox"
    case edge        = "Edge"
    case arc         = "Arc"
    case brave       = "Brave"
    case opera       = "Opera"
    case system      = "系统痕迹"
    case terminal    = "终端历史"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .safari:   return "safari"
        case .chrome:   return "globe"
        case .firefox:  return "flame"
        case .edge:     return "globe.americas"
        case .arc:      return "globe.asia.australia"
        case .brave:    return "shield.lefthalf.filled"
        case .opera:    return "globe.europe.africa"
        case .system:   return "clock.arrow.circlepath"
        case .terminal: return "terminal"
        }
    }

    var color: Color {
        switch self {
        case .safari:   return .blue
        case .chrome:   return .green
        case .firefox:  return .orange
        case .edge:     return .cyan
        case .arc:      return .purple
        case .brave:    return .orange
        case .opera:    return .red
        case .system:   return .purple
        case .terminal: return .gray
        }
    }
}

enum PrivacyRisk: String {
    case low    = "低风险"
    case medium = "中风险"
    case high   = "高风险"

    var color: Color {
        switch self {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

struct PrivacyTrace: Identifiable, Equatable {
    var id: String { "\(category.rawValue)_\(name)" }
    let category: PrivacyCategory
    let name: String
    let description: String
    let risk: PrivacyRisk
    /// 清理动作类型
    let action: PrivacyAction
    let sizeBytes: Int64

    static func == (lhs: PrivacyTrace, rhs: PrivacyTrace) -> Bool {
        lhs.id == rhs.id
    }
}

enum PrivacyAction {
    case deletePaths([URL])
    case clearClipboard
    case deleteFile(URL)
}
