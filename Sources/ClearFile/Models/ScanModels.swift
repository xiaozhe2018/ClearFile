import Foundation

struct DiskUsage: Equatable {
    let totalBytes: Int64
    let freeBytes: Int64
    var usedBytes: Int64 { totalBytes - freeBytes }
    var usedRatio: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
    }
}

struct CacheGroup: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: URL
    let sizeBytes: Int64
    let suggestion: Suggestion
}

struct LargeFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    let modifiedAt: Date
    let suggestion: Suggestion

    var displayName: String { url.lastPathComponent }
    var displayPath: String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

enum ScanState: Equatable {
    case idle
    case scanning(progress: Double, current: String)
    case completed
    case failed(String)
}
