import Foundation
import SwiftUI

/// 计算磁盘各类别占用。拆分 ~/Library 子目录避免一整坨"系统库"。
actor BreakdownEngine {
    static let shared = BreakdownEngine()

    struct Source {
        let key: String
        let name: String
        let icon: String
        let color: Color
        let paths: [String]        // 扫描的路径列表（并行扫描后合计）
        let excludeSubs: [String]  // 排除子目录（避免与其他 Source 重复）
    }

    private static let home = NSHomeDirectory()
    private static let lib  = "\(home)/Library"

    /// 15 个互不重叠的分类（拆碎"其他/系统"）
    static let sources: [Source] = [
        Source(key: "apps", name: "应用",
               icon: "app.fill", color: .blue,
               paths: ["/Applications"],
               excludeSubs: []),
        Source(key: "media", name: "影音",
               icon: "play.rectangle.fill", color: .purple,
               paths: ["\(home)/Movies", "\(home)/Music"],
               excludeSubs: []),
        Source(key: "photos", name: "图片",
               icon: "photo.fill", color: .orange,
               paths: ["\(home)/Pictures"],
               excludeSubs: []),
        Source(key: "docs", name: "文档",
               icon: "doc.text.fill", color: .indigo,
               paths: ["\(home)/Documents", "\(home)/Desktop"],
               excludeSubs: []),
        Source(key: "downloads", name: "下载",
               icon: "arrow.down.circle.fill", color: .teal,
               paths: ["\(home)/Downloads"],
               excludeSubs: []),
        Source(key: "dev_tools", name: "开发工具",
               icon: "hammer.fill", color: .mint,
               paths: ["\(lib)/Developer", "/opt/homebrew", "/usr/local/Cellar"],
               excludeSubs: []),
        Source(key: "app_cache", name: "应用缓存",
               icon: "archivebox.fill", color: .yellow,
               paths: ["\(lib)/Caches"],
               excludeSubs: []),
        Source(key: "app_data", name: "应用数据",
               icon: "externaldrive.fill", color: .cyan,
               paths: ["\(lib)/Application Support", "\(lib)/Containers", "\(lib)/Group Containers"],
               excludeSubs: ["\(lib)/Application Support/MobileSync"]),  // iOS 备份单独算
        Source(key: "ios_backup", name: "iOS 备份",
               icon: "iphone.gen3", color: .pink,
               paths: ["\(lib)/Application Support/MobileSync"],
               excludeSubs: []),
        Source(key: "icloud", name: "iCloud",
               icon: "icloud.fill", color: .blue.opacity(0.7),
               paths: ["\(lib)/Mobile Documents"],
               excludeSubs: []),
        Source(key: "mail", name: "邮件",
               icon: "envelope.fill", color: .red,
               paths: ["\(lib)/Mail"],
               excludeSubs: []),
        Source(key: "lib_other", name: "Library 其他",
               icon: "folder.fill", color: .brown,
               paths: [lib],
               excludeSubs: [
                   "\(lib)/Caches",
                   "\(lib)/Application Support",
                   "\(lib)/Developer",
                   "\(lib)/Containers",
                   "\(lib)/Group Containers",
                   "\(lib)/Mobile Documents",
                   "\(lib)/Mail"
               ]),
        // ── 系统级（拆碎"其他/系统"）──
        Source(key: "sys_global_lib", name: "系统全局库",
               icon: "building.columns.fill", color: Color(nsColor: .systemTeal),
               paths: ["/Library"],
               excludeSubs: []),
        Source(key: "sys_macos", name: "macOS 系统",
               icon: "desktopcomputer", color: Color(nsColor: .systemGray),
               paths: ["/System"],
               excludeSubs: []),
        Source(key: "dotfiles", name: "用户配置/工具链",
               icon: "gearshape.2.fill", color: Color(nsColor: .systemIndigo),
               paths: [],  // 动态扫描，见 compute()
               excludeSubs: [])
    ]

    /// 动态收集 ~/ 下所有 . 开头的目录（dotfiles）— 不含 ~/Library
    static func collectDotfilePaths() -> [String] {
        let homeURL = URL(fileURLWithPath: home)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: homeURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return [] }
        return entries.compactMap { url -> String? in
            let name = url.lastPathComponent
            guard name.hasPrefix("."),
                  name != ".Trash",  // 已在 recentFiles 覆盖
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { return nil }
            return url.path
        }
    }

    /// 逐个分类扫描，每完成一个通过 onProgress 通知（用于实时更新 UI）
    func compute(onProgress: (@Sendable (StorageCategory) -> Void)? = nil) async -> StorageBreakdown {
        // dotfiles 需要动态收集路径
        let dotPaths = Self.collectDotfilePaths()

        let categories = await withTaskGroup(of: StorageCategory?.self) { group -> [StorageCategory] in
            for src in Self.sources {
                group.addTask {
                    // dotfiles source 用动态路径
                    let paths = src.key == "dotfiles" ? dotPaths : src.paths
                    var totalBytes: Int64 = 0
                    for path in paths {
                        guard FileManager.default.fileExists(atPath: path) else { continue }
                        let url = URL(fileURLWithPath: path)
                        let bytes = await Self.directorySize(
                            at: url,
                            excludePrefixes: src.excludeSubs
                        )
                        totalBytes += bytes
                    }
                    guard totalBytes > 0 else { return nil }
                    return StorageCategory(
                        key: src.key, name: src.name, icon: src.icon,
                        color: src.color, bytes: totalBytes
                    )
                }
            }
            var result: [StorageCategory] = []
            for await cat in group {
                if let cat {
                    result.append(cat)
                    onProgress?(cat)
                }
            }
            return result
        }

        let totalScanned = categories.reduce(0) { $0 + $1.bytes }
        let actualUsed = Self.actualDiskUsed()
        return StorageBreakdown(
            categories: categories,
            totalScannedBytes: totalScanned,
            actualUsedBytes: actualUsed,
            scannedAt: Date()
        )
    }

    /// 扫描某个分类下的 top N 子目录（用于点击展开明细）
    /// onProgress: (已扫数, 总数, 当前子目录名)
    func topSubdirectories(
        for sourceKey: String,
        limit: Int = 15,
        onProgress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async -> [StorageCategory] {
        guard let src = Self.sources.first(where: { $0.key == sourceKey }) else { return [] }
        let paths = src.key == "dotfiles" ? Self.collectDotfilePaths() : src.paths

        // 先收集所有要扫的子目录
        var allChildren: [(url: URL, basePath: String)] = []
        for basePath in paths {
            let baseURL = URL(fileURLWithPath: basePath)
            guard FileManager.default.fileExists(atPath: basePath),
                  let children = try? FileManager.default.contentsOfDirectory(
                      at: baseURL,
                      includingPropertiesForKeys: [.isDirectoryKey],
                      options: [.skipsHiddenFiles]
                  ) else { continue }
            for child in children {
                let childPath = child.path
                if src.excludeSubs.contains(where: {
                    childPath == $0 || childPath.hasPrefix($0 + "/")
                }) { continue }
                allChildren.append((child, basePath))
            }
        }

        let total = allChildren.count
        var entries: [StorageCategory] = []
        var scanned = 0

        for (child, _) in allChildren {
            scanned += 1
            onProgress?(scanned, total, child.lastPathComponent)

            let size = await Self.directorySize(at: child, excludePrefixes: [])
            guard size > 1024 * 1024 else { continue }

            entries.append(StorageCategory(
                key: "\(sourceKey)_\(child.lastPathComponent)",
                name: child.lastPathComponent,
                icon: "folder",
                color: .secondary,
                bytes: size
            ))
        }
        return Array(entries.sorted { $0.bytes > $1.bytes }.prefix(limit))
    }

    static func actualDiskUsed() -> Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let v = try? home.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) else { return 0 }
        let total = Int64(v.volumeTotalCapacity ?? 0)
        let free = v.volumeAvailableCapacityForImportantUsage
            ?? Int64(v.volumeAvailableCapacity ?? 0)
        return max(total - free, 0)
    }

    /// 递归计算目录大小。
    /// - excludePrefixes: 跳过的子路径前缀（避免与其他 Source 重复）
    static func directorySize(at url: URL, excludePrefixes: [String] = []) async -> Int64 {
        await Task.detached(priority: .utility) {
            let keys: [URLResourceKey] = [
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileResourceIdentifierKey
            ]
            var total: Int64 = 0
            var seenInodes = Set<AnyHashable>()
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { return 0 }

            while let next = enumerator.nextObject() as? URL {
                // 排除重叠子路径
                let path = next.path
                if excludePrefixes.contains(where: {
                    path == $0 || path.hasPrefix($0 + "/")
                }) {
                    enumerator.skipDescendants()
                    continue
                }

                guard let v = try? next.resourceValues(forKeys: Set(keys)),
                      v.isRegularFile == true,
                      v.isSymbolicLink != true else { continue }

                if let inode = v.fileResourceIdentifier as? (any Hashable) {
                    let key = AnyHashable(inode)
                    if seenInodes.contains(key) { continue }
                    seenInodes.insert(key)
                }

                if let s = v.totalFileAllocatedSize {
                    total += Int64(s)
                } else if let s = v.fileAllocatedSize {
                    total += Int64(s)
                }
            }
            return total
        }.value
    }
}
