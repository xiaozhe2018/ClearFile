import Foundation
import SwiftUI

/// 智能预设：把"扫描配置 + 选择策略"封装为一键场景
struct SmartPreset: Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

enum SmartPresets {
    static var all: [SmartPreset] {[
        SmartPreset(
            key: "developer",
            title: L10n.devClean,
            subtitle: L10n.devCleanSub,
            icon: "terminal.fill",
            color: .indigo
        ),
        SmartPreset(
            key: "predeparture",
            title: L10n.preDeparture,
            subtitle: L10n.preDepartureSub,
            icon: "airplane",
            color: .teal
        ),
        SmartPreset(
            key: "free5gb",
            title: L10n.free5gb,
            subtitle: L10n.free5gbSub,
            icon: "speedometer",
            color: .orange
        )
    ]}

    /// 开发者预设：扫描已知开发缓存目录
    static func developerScan() async -> OneClickClean.Plan {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let devPaths: [URL] = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            home.appendingPathComponent(".npm"),
            home.appendingPathComponent(".yarn/cache"),
            home.appendingPathComponent("Library/Caches/Yarn"),
            home.appendingPathComponent("Library/Caches/Homebrew"),
            home.appendingPathComponent("Library/Caches/CocoaPods"),
            home.appendingPathComponent("Library/Caches/pip")
        ]

        var caches: [CacheGroup] = []
        for url in devPaths {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            if WhitelistGate.contains(url: url) { continue }
            let size = ScanEngine.directorySize(at: url)
            guard size > 1024 * 1024 else { continue }
            caches.append(CacheGroup(
                name: url.lastPathComponent,
                path: url,
                sizeBytes: size,
                suggestion: Suggestion(level: .safe, reason: "开发工具缓存，可重建")
            ))
        }
        return OneClickClean.Plan(cacheTargets: caches, largeFileTargets: [])
    }

    /// 出差前清理：Downloads 中 30 天前文件 + 桌面截图 + 废纸篓
    static func preDepartureScan() async -> OneClickClean.Plan {
        var largeFiles: [LargeFile] = []
        // Downloads 30 天前
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: downloads.path) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            largeFiles.append(contentsOf: ScanEngine.collectRecentFiles(in: downloads, category: .all, cutoff: Date.distantPast).filter { $0.modifiedAt < cutoff })
        }
        // 截图（Desktop）
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        if FileManager.default.fileExists(atPath: desktop.path) {
            largeFiles.append(contentsOf: ScanEngine.collectRecentFiles(in: desktop, category: .screenshot, cutoff: Date.distantPast))
        }
        // 废纸篓
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        if FileManager.default.fileExists(atPath: trash.path) {
            largeFiles.append(contentsOf: ScanEngine.collectRecentFiles(in: trash, category: .trash, cutoff: Date.distantPast))
        }
        // 只保留 safe / recommended
        let filtered = largeFiles.filter { $0.suggestion.level <= .recommended }
        return OneClickClean.Plan(cacheTargets: [], largeFileTargets: filtered)
    }

    /// 释放 5GB：扫常规一键 + 按 size 累加直到 5GB
    static func freeBytes(_ targetBytes: Int64) async throws -> OneClickClean.Plan {
        let plan = try await OneClickClean.buildPlan { _ in }
        var collected: Int64 = 0
        var caches: [CacheGroup] = []
        for c in (plan.cacheTargets + plan.cacheTargets.filter { _ in false })
            .sorted(by: { $0.sizeBytes > $1.sizeBytes }) {
            if collected >= targetBytes { break }
            caches.append(c)
            collected += c.sizeBytes
        }
        var largeFiles: [LargeFile] = []
        for f in plan.largeFileTargets.sorted(by: { $0.sizeBytes > $1.sizeBytes }) {
            if collected >= targetBytes { break }
            largeFiles.append(f)
            collected += f.sizeBytes
        }
        return OneClickClean.Plan(cacheTargets: caches, largeFileTargets: largeFiles)
    }
}
