import Foundation
import AppKit

actor AppUninstaller {
    static let shared = AppUninstaller()

    /// 列出 /Applications + ~/Applications 中的 .app
    func listInstalledApps() async -> [InstalledApp] {
        let dirs = ["/Applications", ("~/Applications" as NSString).expandingTildeInPath]
        var apps: [InstalledApp] = []
        for dir in dirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for entry in contents where entry.hasSuffix(".app") {
                let url = URL(fileURLWithPath: dir).appendingPathComponent(entry)
                if let app = await Self.loadApp(at: url) {
                    apps.append(app)
                }
            }
        }
        return apps.sorted { $0.appBytes > $1.appBytes }
    }

    nonisolated static func loadApp(at url: URL) async -> InstalledApp? {
        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let size = await Task.detached(priority: .utility) {
            ScanEngine.directorySize(at: url)
        }.value
        return InstalledApp(
            bundleURL: url,
            bundleId: bundleId,
            name: name,
            version: version,
            appBytes: size
        )
    }

    /// 找到指定 App 的所有残留文件/目录
    func findResiduals(for app: InstalledApp) async -> [AppResidual] {
        guard let bundleId = app.bundleId, !bundleId.isEmpty else { return [] }
        return await Task.detached(priority: .utility) { [bundleId, name = app.name] in
            let home = NSHomeDirectory()
            let lib = "\(home)/Library"
            let candidates: [(category: String, base: String)] = [
                ("Application Support", "\(lib)/Application Support"),
                ("Caches",               "\(lib)/Caches"),
                ("Preferences",          "\(lib)/Preferences"),
                ("Logs",                 "\(lib)/Logs"),
                ("Containers",           "\(lib)/Containers"),
                ("Group Containers",     "\(lib)/Group Containers"),
                ("Saved Application State", "\(lib)/Saved Application State"),
                ("HTTPStorages",         "\(lib)/HTTPStorages"),
                ("WebKit",               "\(lib)/WebKit")
            ]

            var residuals: [AppResidual] = []
            for (category, base) in candidates {
                guard let entries = try? FileManager.default.contentsOfDirectory(atPath: base) else { continue }
                for entry in entries {
                    // 命中规则: bundleId 前缀匹配 OR 应用名忽略大小写匹配
                    let lower = entry.lowercased()
                    let hits = entry.contains(bundleId)
                        || entry.hasPrefix(bundleId)
                        || lower.contains(name.lowercased())
                    guard hits else { continue }
                    let url = URL(fileURLWithPath: base).appendingPathComponent(entry)
                    if WhitelistGate.contains(url: url) { continue }
                    let size = ScanEngine.directorySize(at: url)
                    residuals.append(AppResidual(url: url, category: category, bytes: size))
                }
            }
            return residuals.sorted { $0.bytes > $1.bytes }
        }.value
    }

    /// 卸载：把 .app + 所有 residual URL 移入废纸篓
    @MainActor
    func uninstall(plan: AppUninstallPlan) async -> CleanResult {
        var urls = [plan.app.bundleURL]
        urls.append(contentsOf: plan.residuals.map { $0.url })
        return await CleanEngine.moveToTrash(urls)
    }
}
