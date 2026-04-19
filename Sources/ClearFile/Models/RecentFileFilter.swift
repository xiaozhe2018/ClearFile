import Foundation

/// "清理最近"类型分类 — 决定扫描哪些目录、什么扩展名、用什么图标
enum RecentCategory: String, CaseIterable, Identifiable {
    case all          // 全部最近文件
    case screenshot   // 截图
    case download     // 下载文件（任意类型）
    case installer    // 安装包 dmg/pkg/iso
    case archive      // 压缩包 zip/rar/7z/tar.gz
    case video        // 视频/录屏
    case trash        // 废纸篓内容

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:        return "全部最近"
        case .screenshot: return "截图"
        case .download:   return "下载"
        case .installer:  return "安装包"
        case .archive:    return "压缩包"
        case .video:      return "视频/录屏"
        case .trash:      return "废纸篓"
        }
    }

    var icon: String {
        switch self {
        case .all:        return "clock"
        case .screenshot: return "camera.viewfinder"
        case .download:   return "arrow.down.circle"
        case .installer:  return "shippingbox"
        case .archive:    return "doc.zipper"
        case .video:      return "video"
        case .trash:      return "trash"
        }
    }

    /// 扫描的根目录
    func roots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .all:
            return [home.appendingPathComponent("Desktop"),
                    home.appendingPathComponent("Downloads"),
                    home.appendingPathComponent("Movies"),
                    home.appendingPathComponent(".Trash")]
        case .screenshot:
            return [home.appendingPathComponent("Desktop"),
                    home.appendingPathComponent("Downloads")]
        case .download:
            return [home.appendingPathComponent("Downloads")]
        case .installer:
            return [home.appendingPathComponent("Downloads"),
                    home.appendingPathComponent("Desktop")]
        case .archive:
            return [home.appendingPathComponent("Downloads"),
                    home.appendingPathComponent("Desktop")]
        case .video:
            return [home.appendingPathComponent("Movies"),
                    home.appendingPathComponent("Desktop")]
        case .trash:
            return [home.appendingPathComponent(".Trash")]
        }
    }

    /// 命中扩展名 / 文件名规则。返回 true = 这个文件归属本分类
    func matches(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        switch self {
        case .all, .download, .trash:
            return true
        case .screenshot:
            // macOS 默认截图：Screen Shot YYYY-MM-DD ... 或 截屏 / Screenshot
            return name.hasPrefix("screen shot")
                || name.hasPrefix("screenshot")
                || name.hasPrefix("截屏")
                || name.hasPrefix("截图")
                || (ext == "png" && url.path.contains("/Desktop/"))
        case .installer:
            return ["dmg", "pkg", "iso", "app", "mpkg"].contains(ext)
        case .archive:
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz"].contains(ext)
        case .video:
            return ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext)
        }
    }
}

struct RecentFileFilter: Equatable {
    var category: RecentCategory = .all
    var withinDays: Int = 30

    static let dayOptions: [(label: String, value: Int)] = [
        ("今天", 1),
        ("本周", 7),
        ("近 14 天", 14),
        ("近 30 天", 30),
        ("近 60 天", 60),
        ("近 90 天", 90)
    ]
}
