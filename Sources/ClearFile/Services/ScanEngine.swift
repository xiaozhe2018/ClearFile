import Foundation

/// 扫描引擎：负责磁盘统计、缓存目录扫描、大文件查找。
/// 用 actor 隔离防止并发竞态。
actor ScanEngine {
    static let shared = ScanEngine()

    private let fm = FileManager.default

    // MARK: - Disk Usage

    func diskUsage() throws -> DiskUsage {
        let homeURL = fm.homeDirectoryForCurrentUser
        let values = try homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return DiskUsage(totalBytes: total, freeBytes: free)
    }

    // MARK: - System Junk (User Caches)

    /// 扫描用户缓存目录 ~/Library/Caches，按一级子目录分组返回大小
    func scanUserCaches(progress: @Sendable (Double, String) -> Void) async throws -> [CacheGroup] {
        let cacheURL = try cacheRootURL()
        let entries = try fm.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var groups: [CacheGroup] = []
        let total = max(entries.count, 1)
        for (idx, entry) in entries.enumerated() {
            progress(Double(idx) / Double(total), entry.lastPathComponent)
            try Task.checkCancellation()

            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            if WhitelistGate.contains(url: entry) { continue }

            let size = Self.directorySize(at: entry)
            guard size > 1024 * 1024 else { continue } // 跳过 < 1MB 的小目录
            let suggestion = SuggestionRule.evaluate(cachePath: entry, sizeBytes: size)
            groups.append(
                CacheGroup(
                    name: entry.lastPathComponent,
                    path: entry,
                    sizeBytes: size,
                    suggestion: suggestion
                )
            )
        }
        progress(1.0, "")
        return groups.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func cacheRootURL() throws -> URL {
        let url = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        guard fm.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "ClearFile",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "缓存目录不存在: \(url.path)"]
            )
        }
        return url
    }

    /// 递归汇总目录大小（字节）— 同步实现，可在任意线程调用
    nonisolated static func directorySize(at url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        while let next = enumerator.nextObject() as? URL {
            guard let values = try? next.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    // MARK: - File Scan (大文件 / 久未使用 / 综合)

    static let defaultMaxResults = 1000

    struct FileScanOutcome {
        let files: [LargeFile]
        let truncatedFrom: Int?  // 实际命中数量（如果被截断）
    }

    /// 扫描文件，支持按大小、按久未使用、或两者综合
    func scanFiles(
        roots: [URL],
        filter: FileScanFilter,
        maxResults: Int = ScanEngine.defaultMaxResults,
        progress: @Sendable (Double, String) -> Void
    ) async throws -> FileScanOutcome {
        var results: [LargeFile] = []
        let totalRoots = max(roots.count, 1)

        for (idx, root) in roots.enumerated() {
            progress(Double(idx) / Double(totalRoots), root.lastPathComponent)
            try Task.checkCancellation()
            let found = Self.collectFiles(in: root, filter: filter)
            results.append(contentsOf: found)
        }
        progress(1.0, "")
        // 大小排序（默认）；久未使用模式时按访问时间排
        let sorted: [LargeFile]
        if filter.mode == .unused {
            sorted = results.sorted { $0.modifiedAt < $1.modifiedAt }
        } else {
            sorted = results.sorted { $0.sizeBytes > $1.sizeBytes }
        }
        if sorted.count > maxResults {
            return FileScanOutcome(files: Array(sorted.prefix(maxResults)), truncatedFrom: sorted.count)
        }
        return FileScanOutcome(files: sorted, truncatedFrom: nil)
    }

    /// 兼容旧调用：仅按大小扫描
    func scanLargeFiles(
        roots: [URL],
        minSizeBytes: Int64 = 50 * 1024 * 1024,
        progress: @Sendable (Double, String) -> Void
    ) async throws -> [LargeFile] {
        let filter = FileScanFilter(
            mode: .size,
            minSizeMB: Int(minSizeBytes / (1024 * 1024)),
            unusedDays: 0
        )
        return try await scanFiles(roots: roots, filter: filter, progress: progress).files
    }

    // MARK: - Recent Files

    /// 扫描最近 N 天创建/修改的文件，按分类过滤扩展名
    func scanRecentFiles(
        filter: RecentFileFilter,
        maxResults: Int = ScanEngine.defaultMaxResults,
        progress: @Sendable (Double, String) -> Void
    ) async throws -> FileScanOutcome {
        let roots = filter.category.roots()
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !roots.isEmpty else { return FileScanOutcome(files: [], truncatedFrom: nil) }

        let cutoff = Calendar.current.date(byAdding: .day, value: -filter.withinDays, to: Date()) ?? Date()
        var results: [LargeFile] = []
        let totalRoots = max(roots.count, 1)

        for (idx, root) in roots.enumerated() {
            progress(Double(idx) / Double(totalRoots), root.lastPathComponent)
            try Task.checkCancellation()
            let found = Self.collectRecentFiles(
                in: root,
                category: filter.category,
                cutoff: cutoff
            )
            results.append(contentsOf: found)
        }
        progress(1.0, "")
        let sorted = results.sorted { $0.modifiedAt > $1.modifiedAt }
        if sorted.count > maxResults {
            return FileScanOutcome(files: Array(sorted.prefix(maxResults)), truncatedFrom: sorted.count)
        }
        return FileScanOutcome(files: sorted, truncatedFrom: nil)
    }

    nonisolated static func collectRecentFiles(
        in root: URL,
        category: RecentCategory,
        cutoff: Date
    ) -> [LargeFile] {
        let keys: [URLResourceKey] = [
            .fileSizeKey, .contentModificationDateKey,
            .contentAccessDateKey, .creationDateKey, .isRegularFileKey
        ]
        var found: [LargeFile] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        while let next = enumerator.nextObject() as? URL {
            if WhitelistGate.contains(url: next) { continue }
            guard let v = try? next.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true,
                  let size = v.fileSize else { continue }

            // 时间判断：取 created/modified/accessed 最大值
            let created = v.creationDate ?? Date.distantPast
            let modified = v.contentModificationDate ?? Date.distantPast
            let accessed = v.contentAccessDate ?? Date.distantPast
            let mostRecent = max(created, modified, accessed)
            guard mostRecent >= cutoff else { continue }

            // 类型匹配
            guard category.matches(next) else { continue }

            let suggestion = SuggestionRule.evaluate(
                recentFile: next,
                sizeBytes: Int64(size),
                modifiedAt: modified
            )
            found.append(LargeFile(
                url: next,
                sizeBytes: Int64(size),
                modifiedAt: mostRecent,
                suggestion: suggestion
            ))
        }
        return found
    }

    /// 同步收集单个根目录下的匹配文件
    nonisolated static func collectFiles(in root: URL, filter: FileScanFilter) -> [LargeFile] {
        let keys: [URLResourceKey] = [
            .fileSizeKey, .contentModificationDateKey,
            .contentAccessDateKey, .isRegularFileKey
        ]
        var found: [LargeFile] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let now = Date()
        let unusedCutoff = filter.unusedDays > 0
            ? Calendar.current.date(byAdding: .day, value: -filter.unusedDays, to: now)
            : nil

        while let next = enumerator.nextObject() as? URL {
            if WhitelistGate.contains(url: next) { continue }
            guard let values = try? next.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }

            let bytes = Int64(size)
            let modified = values.contentModificationDate ?? Date()
            let access = values.contentAccessDate ?? modified

            let sizeOK = bytes >= filter.minSizeBytes
            let unusedOK = unusedCutoff.map { access < $0 } ?? false

            let pass: Bool
            switch filter.mode {
            case .size:     pass = sizeOK
            case .unused:   pass = unusedOK
            case .combined: pass = sizeOK && unusedOK
            }
            guard pass else { continue }

            let suggestion = SuggestionRule.evaluate(
                largeFile: next,
                sizeBytes: bytes,
                modifiedAt: modified
            )
            found.append(LargeFile(
                url: next,
                sizeBytes: bytes,
                modifiedAt: modified,
                suggestion: suggestion
            ))
        }
        return found
    }
}
