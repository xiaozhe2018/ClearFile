import Foundation

enum ScheduleFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case manual  // 仅手动触发

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily:   return "每天"
        case .weekly:  return "每周"
        case .monthly: return "每月"
        case .manual:  return "仅手动"
        }
    }

    var intervalSeconds: TimeInterval? {
        switch self {
        case .daily:   return 86400
        case .weekly:  return 86400 * 7
        case .monthly: return 86400 * 30
        case .manual:  return nil
        }
    }
}

struct CleanSchedule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// 要清理的根目录列表（用 bookmark 持久化更稳，v0.2 先用 URL）
    var directoryPaths: [String]
    /// 清理 N 天未访问的文件（0 = 不限）
    var olderThanDays: Int
    /// 文件大小阈值（字节，0 = 不限）
    var minSizeBytes: Int64
    var frequency: ScheduleFrequency
    var enabled: Bool = true
    var lastRunAt: Date? = nil
    var lastRunBytesFreed: Int64 = 0
    var lastRunFileCount: Int = 0

    var directories: [URL] {
        directoryPaths.map { URL(fileURLWithPath: $0) }
    }

    var nextDueAt: Date? {
        guard enabled, let interval = frequency.intervalSeconds else { return nil }
        return (lastRunAt ?? Date.distantPast).addingTimeInterval(interval)
    }

    var isDue: Bool {
        guard let due = nextDueAt else { return false }
        return Date() >= due
    }
}

struct ScheduleRunRecord: Identifiable, Codable {
    var id: UUID = UUID()
    let scheduleId: UUID
    let scheduleName: String
    let runAt: Date
    let bytesFreed: Int64
    let fileCount: Int
    let failedCount: Int
}
