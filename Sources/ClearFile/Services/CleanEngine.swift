import Foundation
import AppKit

/// 单条清理结果（用于撤销）
struct TrashedItem: Equatable {
    let originalURL: URL
    let trashedURL: URL
    let bytes: Int64
}

/// 清理引擎：将文件移动到废纸篓（可恢复，永不直接 unlink）
struct CleanResult {
    let movedCount: Int
    let bytesFreed: Int64
    let failed: [(URL, Error)]
    let trashed: [TrashedItem]
}

enum CleanEngine {
    /// 把一组 URL 移动到废纸篓。返回成功数 / 释放字节数 / 失败列表 / 可撤销项。
    @MainActor
    static func moveToTrash(_ urls: [URL]) async -> CleanResult {
        var moved = 0
        var bytes: Int64 = 0
        var failed: [(URL, Error)] = []
        var trashedItems: [TrashedItem] = []

        for url in urls {
            let size = (try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?
                .totalFileAllocatedSize.map(Int64.init) ?? itemSize(at: url)

            do {
                var resulting: NSURL? = nil
                try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                moved += 1
                bytes += size
                if let trashedURL = resulting as URL? {
                    trashedItems.append(TrashedItem(
                        originalURL: url,
                        trashedURL: trashedURL,
                        bytes: size
                    ))
                }
            } catch {
                failed.append((url, error))
            }
        }
        return CleanResult(
            movedCount: moved,
            bytesFreed: bytes,
            failed: failed,
            trashed: trashedItems
        )
    }

    /// 把废纸篓里的文件搬回原位
    @MainActor
    static func restore(_ items: [TrashedItem]) async -> (restored: Int, failed: [(URL, Error)]) {
        var restored = 0
        var failed: [(URL, Error)] = []
        for item in items {
            do {
                let parentDir = item.originalURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: item.trashedURL, to: item.originalURL)
                restored += 1
            } catch {
                failed.append((item.trashedURL, error))
            }
        }
        return (restored, failed)
    }

    private static func itemSize(at url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        if let values = try? url.resourceValues(forKeys: Set(keys)),
           values.isRegularFile == true,
           let s = values.fileSize {
            return Int64(s)
        }
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) {
            for case let f as URL in enumerator {
                if let v = try? f.resourceValues(forKeys: Set(keys)),
                   v.isRegularFile == true, let s = v.fileSize {
                    total += Int64(s)
                }
            }
        }
        return total
    }
}
