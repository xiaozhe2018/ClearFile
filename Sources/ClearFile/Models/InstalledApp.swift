import Foundation
import AppKit

struct InstalledApp: Identifiable, Equatable {
    var id: String { bundleURL.path }
    let bundleURL: URL
    let bundleId: String?
    let name: String
    let version: String?
    let appBytes: Int64

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}

struct AppResidual: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let category: String  // Application Support / Caches / Preferences / Logs / Containers
    let bytes: Int64
}

struct AppUninstallPlan: Equatable {
    let app: InstalledApp
    let residuals: [AppResidual]

    var totalBytes: Int64 {
        app.appBytes + residuals.reduce(0) { $0 + $1.bytes }
    }
}
