import Foundation
import UserNotifications

enum NotificationHelper {
    /// 没 bundle identifier（SPM 直接跑起来的情况）就不能用通知，否则会抛 NSException
    private static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func requestAuthorizationIfNeeded() async {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    static func notifyScheduleComplete(name: String, fileCount: Int, bytesFreed: Int64, failedCount: Int) async {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "ClearFile · 定时清理完成"
        content.subtitle = name
        if failedCount > 0 {
            content.body = "释放 \(ByteFormatter.format(bytesFreed)) · \(fileCount) 项 · \(failedCount) 失败"
        } else {
            content.body = "释放 \(ByteFormatter.format(bytesFreed)) · \(fileCount) 项"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
