import Foundation

/// 文件扫描模式
enum FileScanMode: String, CaseIterable, Identifiable {
    case size      // 仅按大小
    case unused    // 仅按久未使用
    case combined  // 同时满足（大且久未使用）

    var id: String { rawValue }

    var label: String {
        switch self {
        case .size:     return "按大小"
        case .unused:   return "久未使用"
        case .combined: return "大 + 久未使用"
        }
    }

    var summary: String {
        switch self {
        case .size:     return "按文件大小阈值找出占用空间多的文件"
        case .unused:   return "找出长期没访问过的文件，不限大小"
        case .combined: return "同时满足两个条件，最保守"
        }
    }
}

/// 用户在 UI 上配置的过滤参数
struct FileScanFilter: Equatable {
    var mode: FileScanMode = .size
    var minSizeMB: Int = 50
    var unusedDays: Int = 180

    var minSizeBytes: Int64 {
        Int64(minSizeMB) * 1024 * 1024
    }
}
