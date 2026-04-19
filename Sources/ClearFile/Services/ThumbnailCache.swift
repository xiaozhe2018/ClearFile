import Foundation
import AppKit
import QuickLookThumbnailing

/// 全局缩略图缓存。NSCache 自动管理内存压力。
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private var inflight: [String: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 500   // 最多缓存 500 张
        cache.totalCostLimit = 64 * 1024 * 1024 // 大约 64MB 上限
    }

    func cached(for url: URL, size: CGFloat) -> NSImage? {
        cache.object(forKey: key(url, size: size) as NSString)
    }

    /// 异步取缩略图。同一个 URL 同一个 size 同时只触发一次后台请求。
    func thumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        let k = key(url, size: size)
        if let img = cache.object(forKey: k as NSString) {
            return img
        }
        if let task = inflight[k] {
            return await task.value
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let task = Task<NSImage?, Never> { [weak self] in
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: size, height: size),
                scale: scale,
                representationTypes: .thumbnail
            )
            do {
                let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                let img = rep.nsImage
                if let cost = img.tiffRepresentation?.count {
                    await MainActor.run {
                        self?.cache.setObject(img, forKey: k as NSString, cost: cost)
                    }
                } else {
                    await MainActor.run {
                        self?.cache.setObject(img, forKey: k as NSString)
                    }
                }
                return img
            } catch {
                return nil
            }
        }
        inflight[k] = task
        let img = await task.value
        inflight[k] = nil
        return img
    }

    private func key(_ url: URL, size: CGFloat) -> String {
        "\(url.absoluteString)#\(Int(size))"
    }
}
