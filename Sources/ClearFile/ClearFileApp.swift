import SwiftUI
import AppKit

@main
struct ClearFileApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var scanStore = ScanStore()
    @StateObject private var scheduleStore = ScheduleStore()
    @StateObject private var historyStore = CleanHistoryStore()
    @StateObject private var undoStore = UndoStore()
    @StateObject private var whitelistStore = WhitelistStore()
    @StateObject private var errorCenter = ErrorCenter()
    @StateObject private var licenseStore = LicenseStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(scanStore)
                .environmentObject(scheduleStore)
                .environmentObject(historyStore)
                .environmentObject(undoStore)
                .environmentObject(whitelistStore)
                .environmentObject(errorCenter)
                .environmentObject(licenseStore)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear {
                    scanStore.historyStore = historyStore
                    scanStore.undoStore = undoStore
                    scanStore.errorCenter = errorCenter
                    scheduleStore.historyStore = historyStore
                    scheduleStore.startTicking()
                    Task { await NotificationHelper.requestAuthorizationIfNeeded() }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra("ClearFile", systemImage: "internaldrive.fill") {
            MenuBarView()
                .environmentObject(scanStore)
                .environmentObject(undoStore)
        }
        .menuBarExtraStyle(.window)
    }
}

/// SPM-built executables run as background tools by default.
/// Force regular app activation so the window comes to the front.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
