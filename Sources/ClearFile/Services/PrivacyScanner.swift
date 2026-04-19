import Foundation
import AppKit

/// 扫描浏览器 + 系统 + 终端的隐私痕迹
enum PrivacyScanner {
    private static let home = NSHomeDirectory()
    private static let lib = "\(home)/Library"

    static func scan() async -> [PrivacyTrace] {
        var traces: [PrivacyTrace] = []
        traces.append(contentsOf: scanSafari())
        traces.append(contentsOf: scanChrome())
        traces.append(contentsOf: scanFirefox())
        traces.append(contentsOf: scanEdge())
        traces.append(contentsOf: scanArc())
        traces.append(contentsOf: scanBrave())
        traces.append(contentsOf: scanOpera())
        traces.append(contentsOf: scanSystem())
        traces.append(contentsOf: scanTerminal())
        return traces.filter { $0.sizeBytes > 0 || isNonFileAction($0) }
    }

    private static func isNonFileAction(_ t: PrivacyTrace) -> Bool {
        if case .clearClipboard = t.action { return true }
        return false
    }

    // MARK: - Safari

    private static func scanSafari() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let base = "\(lib)/Safari"

        addIfExists(&items, category: .safari, name: "浏览历史",
                    desc: "Safari 所有浏览记录",
                    risk: .medium,
                    paths: [
                        "\(base)/History.db",
                        "\(base)/History.db-shm",
                        "\(base)/History.db-wal",
                        "\(base)/RecentlyClosedTabs.plist"
                    ])

        addIfExists(&items, category: .safari, name: "Cookies",
                    desc: "网站登录态、跟踪 Cookie",
                    risk: .high,
                    paths: ["\(lib)/Cookies/Cookies.binarycookies"])

        addDirIfExists(&items, category: .safari, name: "缓存",
                       desc: "Safari 网页缓存（图片/CSS/JS）",
                       risk: .low,
                       path: "\(lib)/Caches/com.apple.Safari")

        addDirIfExists(&items, category: .safari, name: "网站数据",
                       desc: "LocalStorage / IndexedDB / WebSQL",
                       risk: .medium,
                       path: "\(lib)/WebKit/com.apple.Safari")

        addIfExists(&items, category: .safari, name: "下载记录",
                    desc: "Safari 下载历史列表（不删文件本身）",
                    risk: .low,
                    paths: ["\(base)/Downloads.plist"])

        return items
    }

    // MARK: - Chrome

    private static func scanChrome() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let base = "\(lib)/Application Support/Google/Chrome/Default"
        guard FileManager.default.fileExists(atPath: base) else { return [] }

        addIfExists(&items, category: .chrome, name: "浏览历史",
                    desc: "Chrome 所有浏览记录",
                    risk: .medium,
                    paths: ["\(base)/History", "\(base)/History-journal"])

        addIfExists(&items, category: .chrome, name: "Cookies",
                    desc: "网站登录态、跟踪 Cookie",
                    risk: .high,
                    paths: ["\(base)/Cookies", "\(base)/Cookies-journal"])

        addDirIfExists(&items, category: .chrome, name: "缓存",
                       desc: "Chrome 网页缓存",
                       risk: .low,
                       path: "\(lib)/Caches/Google/Chrome/Default")

        addIfExists(&items, category: .chrome, name: "表单自动填充",
                    desc: "表单输入历史（姓名/地址/邮箱）",
                    risk: .high,
                    paths: ["\(base)/Web Data", "\(base)/Web Data-journal"])

        addIfExists(&items, category: .chrome, name: "搜索/地址栏记录",
                    desc: "Omnibox 输入历史",
                    risk: .medium,
                    paths: [
                        "\(base)/Shortcuts", "\(base)/Shortcuts-journal",
                        "\(base)/Network Action Predictor"
                    ])

        return items
    }

    // MARK: - Firefox

    private static func scanFirefox() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let profilesDir = "\(lib)/Application Support/Firefox/Profiles"
        guard let profiles = try? FileManager.default.contentsOfDirectory(atPath: profilesDir) else { return [] }
        guard let firstProfile = profiles.first(where: { $0.hasSuffix(".default-release") || $0.hasSuffix(".default") }) else { return [] }
        let base = "\(profilesDir)/\(firstProfile)"

        addIfExists(&items, category: .firefox, name: "浏览历史",
                    desc: "Firefox 浏览历史 + 书签数据库",
                    risk: .medium,
                    paths: ["\(base)/places.sqlite", "\(base)/places.sqlite-wal"])

        addIfExists(&items, category: .firefox, name: "Cookies",
                    desc: "Firefox Cookie 数据库",
                    risk: .high,
                    paths: ["\(base)/cookies.sqlite", "\(base)/cookies.sqlite-wal"])

        addIfExists(&items, category: .firefox, name: "表单历史",
                    desc: "Firefox 表单自动填充",
                    risk: .high,
                    paths: ["\(base)/formhistory.sqlite"])

        addDirIfExists(&items, category: .firefox, name: "缓存",
                       desc: "Firefox 网页缓存",
                       risk: .low,
                       path: "\(base)/cache2")

        return items
    }

    // MARK: - Edge

    private static func scanEdge() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let base = "\(lib)/Application Support/Microsoft Edge/Default"
        guard FileManager.default.fileExists(atPath: base) else { return [] }

        addIfExists(&items, category: .edge, name: "浏览历史",
                    desc: "Edge 浏览记录",
                    risk: .medium,
                    paths: ["\(base)/History", "\(base)/History-journal"])

        addIfExists(&items, category: .edge, name: "Cookies",
                    desc: "Edge Cookie",
                    risk: .high,
                    paths: ["\(base)/Cookies", "\(base)/Cookies-journal"])

        addDirIfExists(&items, category: .edge, name: "缓存",
                       desc: "Edge 网页缓存",
                       risk: .low,
                       path: "\(lib)/Caches/Microsoft Edge/Default")

        return items
    }

    // MARK: - Arc

    private static func scanArc() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let base = "\(lib)/Application Support/Arc/User Data/Default"
        guard FileManager.default.fileExists(atPath: base) else { return [] }

        addIfExists(&items, category: .arc, name: "浏览历史",
                    desc: "Arc 浏览记录", risk: .medium,
                    paths: ["\(base)/History", "\(base)/History-journal"])
        addIfExists(&items, category: .arc, name: "Cookies",
                    desc: "Arc Cookie", risk: .high,
                    paths: ["\(base)/Cookies", "\(base)/Cookies-journal"])
        addDirIfExists(&items, category: .arc, name: "缓存",
                       desc: "Arc 缓存", risk: .low,
                       path: "\(lib)/Caches/company.thebrowser.Browser")
        return items
    }

    // MARK: - Brave

    private static func scanBrave() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let base = "\(lib)/Application Support/BraveSoftware/Brave-Browser/Default"
        guard FileManager.default.fileExists(atPath: base) else { return [] }

        addIfExists(&items, category: .brave, name: "浏览历史",
                    desc: "Brave 浏览记录", risk: .medium,
                    paths: ["\(base)/History", "\(base)/History-journal"])
        addIfExists(&items, category: .brave, name: "Cookies",
                    desc: "Brave Cookie", risk: .high,
                    paths: ["\(base)/Cookies", "\(base)/Cookies-journal"])
        addDirIfExists(&items, category: .brave, name: "缓存",
                       desc: "Brave 缓存", risk: .low,
                       path: "\(lib)/Caches/BraveSoftware/Brave-Browser/Default")
        return items
    }

    // MARK: - Opera

    private static func scanOpera() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let base = "\(lib)/Application Support/com.operasoftware.Opera"
        guard FileManager.default.fileExists(atPath: base) else { return [] }

        addIfExists(&items, category: .opera, name: "浏览历史",
                    desc: "Opera 浏览记录", risk: .medium,
                    paths: ["\(base)/History", "\(base)/History-journal"])
        addIfExists(&items, category: .opera, name: "Cookies",
                    desc: "Opera Cookie", risk: .high,
                    paths: ["\(base)/Cookies", "\(base)/Cookies-journal"])
        addDirIfExists(&items, category: .opera, name: "缓存",
                       desc: "Opera 缓存", risk: .low,
                       path: "\(lib)/Caches/com.operasoftware.Opera")
        return items
    }

    // MARK: - System

    private static func scanSystem() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []
        let sfl = "\(lib)/Application Support/com.apple.sharedfilelist"

        addIfExists(&items, category: .system, name: "最近打开的文档",
                    desc: "Finder → 最近使用的文件列表",
                    risk: .low,
                    paths: [
                        "\(sfl)/com.apple.LSSharedFileList.RecentDocuments.sfl3",
                        "\(sfl)/com.apple.LSSharedFileList.RecentApplications.sfl3",
                        "\(sfl)/com.apple.LSSharedFileList.RecentHosts.sfl3",
                        "\(sfl)/com.apple.LSSharedFileList.RecentServers.sfl3"
                    ])

        addDirIfExists(&items, category: .system, name: "最近项目数据",
                       desc: "各应用的最近项目数据",
                       risk: .low,
                       path: sfl)

        // 剪贴板（特殊 action，不是文件）
        items.append(PrivacyTrace(
            category: .system,
            name: "剪贴板内容",
            description: "当前剪贴板中的文本/图片",
            risk: .low,
            action: .clearClipboard,
            sizeBytes: Int64(NSPasteboard.general.data(forType: .string)?.count ?? 0)
        ))

        return items
    }

    // MARK: - Terminal

    private static func scanTerminal() -> [PrivacyTrace] {
        var items: [PrivacyTrace] = []

        addIfExists(&items, category: .terminal, name: "Zsh 历史",
                    desc: "~/.zsh_history 命令记录",
                    risk: .medium,
                    paths: ["\(home)/.zsh_history"])

        addIfExists(&items, category: .terminal, name: "Bash 历史",
                    desc: "~/.bash_history 命令记录",
                    risk: .medium,
                    paths: ["\(home)/.bash_history"])

        addIfExists(&items, category: .terminal, name: "Python 历史",
                    desc: "~/.python_history REPL 记录",
                    risk: .low,
                    paths: ["\(home)/.python_history"])

        addIfExists(&items, category: .terminal, name: "Node.js REPL 历史",
                    desc: "~/.node_repl_history",
                    risk: .low,
                    paths: ["\(home)/.node_repl_history"])

        return items
    }

    // MARK: - Helpers

    private static func addIfExists(
        _ items: inout [PrivacyTrace],
        category: PrivacyCategory,
        name: String,
        desc: String,
        risk: PrivacyRisk,
        paths: [String]
    ) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return }
        let size = existing.reduce(Int64(0)) { sum, url in
            sum + (Int64((try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0))
        }
        items.append(PrivacyTrace(
            category: category, name: name, description: desc,
            risk: risk, action: .deletePaths(existing), sizeBytes: size
        ))
    }

    private static func addDirIfExists(
        _ items: inout [PrivacyTrace],
        category: PrivacyCategory,
        name: String,
        desc: String,
        risk: PrivacyRisk,
        path: String
    ) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        let size = ScanEngine.directorySize(at: url)
        guard size > 0 else { return }
        items.append(PrivacyTrace(
            category: category, name: name, description: desc,
            risk: risk, action: .deletePaths([url]), sizeBytes: size
        ))
    }

    // MARK: - Execute

    @MainActor
    static func clean(_ traces: [PrivacyTrace]) async -> CleanResult {
        var allURLs: [URL] = []
        var clearedClipboard = false

        for trace in traces {
            switch trace.action {
            case .deletePaths(let urls):
                allURLs.append(contentsOf: urls)
            case .deleteFile(let url):
                allURLs.append(url)
            case .clearClipboard:
                NSPasteboard.general.clearContents()
                clearedClipboard = true
            }
        }

        if allURLs.isEmpty && clearedClipboard {
            return CleanResult(movedCount: 1, bytesFreed: 0, failed: [], trashed: [])
        }
        return await CleanEngine.moveToTrash(allURLs)
    }
}
