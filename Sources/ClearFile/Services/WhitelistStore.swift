import Foundation
import SwiftUI

/// 用户保护清单（白名单）。任何路径以白名单中的某个前缀开头都被永久保护。
@MainActor
final class WhitelistStore: ObservableObject {
    @Published var entries: [String] = []

    private let fileURL: URL

    init() {
        let supportDir = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = supportDir.appendingPathComponent("ClearFile", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("whitelist.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            entries = arr
            WhitelistGate.update(entries: arr)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
        WhitelistGate.update(entries: entries)
    }

    func add(_ path: String) {
        guard !entries.contains(path) else { return }
        entries.append(path)
        save()
    }

    func remove(_ path: String) {
        entries.removeAll { $0 == path }
        save()
    }

    func contains(_ url: URL) -> Bool {
        WhitelistGate.contains(url: url)
    }
}

/// 让非 MainActor 的扫描引擎也能查询白名单。线程安全的快照。
final class WhitelistGate: @unchecked Sendable {
    static let shared = WhitelistGate()
    private let lock = NSLock()
    private var snapshot: [String] = []

    static func update(entries: [String]) { shared.update(entries) }
    static func contains(url: URL) -> Bool { shared.contains(url: url) }

    private func update(_ entries: [String]) {
        lock.lock(); defer { lock.unlock() }
        snapshot = entries
    }

    private func contains(url: URL) -> Bool {
        let path = url.path
        lock.lock(); defer { lock.unlock() }
        for prefix in snapshot {
            if path == prefix || path.hasPrefix(prefix + "/") {
                return true
            }
        }
        return false
    }
}
