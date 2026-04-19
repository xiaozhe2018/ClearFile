import Foundation

struct DuplicateFile: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let sizeBytes: Int64
    let modifiedAt: Date
    var keep: Bool  // 用户选"保留这个"
}

struct DuplicateGroup: Identifiable {
    var id: String { sha256Prefix + "_" + String(sizeBytes) }
    let sha256Prefix: String  // 前 16 字符即可，避免太长
    let sizeBytes: Int64
    var files: [DuplicateFile]

    /// 总浪费空间 = (n-1) * sizeBytes
    var wastedBytes: Int64 {
        Int64(max(0, files.count - 1)) * sizeBytes
    }
}
