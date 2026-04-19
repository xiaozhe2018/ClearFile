import Foundation

/// 一键安全清理：扫描所有支持模块 → 自动选择 safe 等级 → 删除到废纸篓
enum OneClickClean {
    struct Plan {
        let cacheTargets: [CacheGroup]
        let largeFileTargets: [LargeFile]

        var totalCount: Int { cacheTargets.count + largeFileTargets.count }
        var totalBytes: Int64 {
            cacheTargets.reduce(0) { $0 + $1.sizeBytes }
                + largeFileTargets.reduce(0) { $0 + $1.sizeBytes }
        }
    }

    /// 扫描并构造一个"安全"清理计划。不执行删除。
    static func buildPlan(
        progress: @Sendable (String) -> Void = { _ in }
    ) async throws -> Plan {
        progress("正在扫描系统缓存…")
        let caches = try await ScanEngine.shared.scanUserCaches { _, _ in }
        let safeCaches = caches.filter { $0.suggestion.level == .safe }

        progress("正在扫描大文件…")
        let defaultRoots = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }

        let largeFiles = try await ScanEngine.shared.scanLargeFiles(
            roots: defaultRoots,
            minSizeBytes: 50 * 1024 * 1024
        ) { _, _ in }
        let safeLarge = largeFiles.filter { $0.suggestion.level == .safe }

        return Plan(cacheTargets: safeCaches, largeFileTargets: safeLarge)
    }

    /// 执行计划
    @MainActor
    static func execute(_ plan: Plan) async -> CleanResult {
        let urls = plan.cacheTargets.map { $0.path } + plan.largeFileTargets.map { $0.url }
        return await CleanEngine.moveToTrash(urls)
    }
}
