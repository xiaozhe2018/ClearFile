import Foundation
import SwiftUI

enum CleanSource: String, Codable, CaseIterable, Identifiable {
    case oneClick    = "一键清理"
    case systemJunk  = "系统垃圾"
    case largeFiles  = "文件清理"
    case schedule    = "定时清理"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .oneClick:   return "wand.and.sparkles"
        case .systemJunk: return "trash.fill"
        case .largeFiles: return "doc.zipper"
        case .schedule:   return "clock.arrow.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .oneClick:   return .accentColor
        case .systemJunk: return .orange
        case .largeFiles: return .blue
        case .schedule:   return .purple
        }
    }
}

struct CleanHistoryRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let timestamp: Date
    let source: CleanSource
    /// 二级来源描述，如定时任务名 / "缓存 + 大文件"
    let detail: String
    let fileCount: Int
    let bytesFreed: Int64
    let failedCount: Int
}
