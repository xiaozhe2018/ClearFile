import SwiftUI
import AppKit

/// 文件缩略图视图。使用全局缓存避免重复加载。
struct FileThumbnail: View {
    let url: URL
    var size: CGFloat = 36

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .task(id: url) {
            // 命中缓存立即同步显示，否则后台加载
            if let cached = ThumbnailCache.shared.cached(for: url, size: size) {
                self.image = cached
                return
            }
            let loaded = await ThumbnailCache.shared.thumbnail(for: url, size: size)
            if !Task.isCancelled, let loaded {
                self.image = loaded
            }
        }
    }
}
