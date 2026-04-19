import Foundation
import CryptoKit

/// 重复文件检测：先按 size 分组，size 相同的再 SHA256 对比
actor DuplicateDetector {
    static let shared = DuplicateDetector()

    func scan(
        roots: [URL],
        minSizeBytes: Int64 = 1 * 1024 * 1024,  // 至少 1MB 才考虑
        maxResults: Int = 500,
        progress: @Sendable (String) -> Void
    ) async throws -> [DuplicateGroup] {
        // 第一遍：按 size 分组
        progress("收集文件...")
        let bySize = await Task.detached(priority: .utility) { () -> [Int64: [URL]] in
            var bucket: [Int64: [URL]] = [:]
            for root in roots {
                guard FileManager.default.fileExists(atPath: root.path) else { continue }
                guard let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                ) else { continue }
                while let next = enumerator.nextObject() as? URL {
                    if WhitelistGate.contains(url: next) { continue }
                    guard let v = try? next.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                          v.isRegularFile == true,
                          let s = v.fileSize,
                          Int64(s) >= minSizeBytes else { continue }
                    bucket[Int64(s), default: []].append(next)
                }
            }
            return bucket.filter { $0.value.count > 1 }  // 只看大小重复的
        }.value

        try Task.checkCancellation()

        // 第二遍：先 partial hash (前 4KB) 快速筛，再全文 hash 确认
        progress("快速指纹...")
        var groups: [DuplicateGroup] = []
        let totalSizeGroups = max(bySize.count, 1)
        var processedGroups = 0

        for (size, urls) in bySize.sorted(by: { $0.key > $1.key }) {
            try Task.checkCancellation()
            processedGroups += 1
            progress("指纹 \(processedGroups)/\(totalSizeGroups) (\(ByteFormatter.format(size)))")

            let bucket = await Task.detached(priority: .utility) { () -> [String: [URL]] in
                // Step A: partial hash (前 4KB) 快速分组
                var partialBucket: [String: [URL]] = [:]
                for u in urls {
                    if let ph = Self.partialHash(at: u) {
                        partialBucket[ph, default: []].append(u)
                    }
                }
                // Step B: partial hash 相同的才做全文 SHA256
                var fullBucket: [String: [URL]] = [:]
                for (_, candidates) in partialBucket where candidates.count > 1 {
                    for u in candidates {
                        if let fh = Self.hashFile(at: u) {
                            fullBucket[fh, default: []].append(u)
                        }
                    }
                }
                return fullBucket
            }.value

            for (hash, dupURLs) in bucket where dupURLs.count > 1 {
                var files: [DuplicateFile] = dupURLs.compactMap { url in
                    let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate ?? Date()
                    return DuplicateFile(url: url, sizeBytes: size, modifiedAt: mod, keep: false)
                }
                // 按"该保留的优先级"排序，分相同时旧的优先（更像原始）
                files.sort { a, b in
                    let pa = Self.keepPriority(for: a.url)
                    let pb = Self.keepPriority(for: b.url)
                    if pa != pb { return pa > pb }
                    return a.modifiedAt < b.modifiedAt
                }
                if !files.isEmpty { files[0].keep = true }

                groups.append(DuplicateGroup(
                    sha256Prefix: String(hash.prefix(16)),
                    sizeBytes: size,
                    files: files
                ))
                if groups.count >= maxResults { break }
            }
            if groups.count >= maxResults { break }
        }

        progress("")
        return groups.sorted { $0.wastedBytes > $1.wastedBytes }
    }

    /// 决定重复组里"应该保留哪个"的优先级（数字越大越该保留）
    /// 规则：Documents/Pictures/Movies/Music/Applications 优先；
    ///       Downloads/Trash/Caches 永远是删除候选
    nonisolated static func keepPriority(for url: URL) -> Int {
        let path = url.path
        let home = NSHomeDirectory()

        // 强烈倾向删除
        if path.contains("/.Trash") { return -100 }
        if path.contains("/Library/Caches/") { return -100 }
        if path.contains("/tmp/") { return -100 }
        if path.contains("/.cache/") { return -100 }

        // 倾向删除
        if path.hasPrefix("\(home)/Downloads") { return -50 }

        // 强烈倾向保留
        if path.hasPrefix("\(home)/Documents") { return 100 }
        if path.hasPrefix("/Applications")     { return 100 }
        if path.hasPrefix("\(home)/Pictures")  { return 90 }
        if path.hasPrefix("\(home)/Movies")    { return 80 }
        if path.hasPrefix("\(home)/Music")     { return 80 }

        // 中性
        if path.hasPrefix("\(home)/Desktop")   { return 30 }

        return 0
    }

    /// 前 4KB partial hash（快速预筛，99% 不同文件在这步就排除了）
    nonisolated static func partialHash(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let headData = handle.readData(ofLength: 4096)
        guard !headData.isEmpty else { return nil }
        return SHA256.hash(data: headData).compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 流式 SHA256（不完整读入内存）
    nonisolated static func hashFile(at url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        let bufferSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read < 0 { return nil }
            if read == 0 { break }
            hasher.update(data: Data(buffer[0..<read]))
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}
