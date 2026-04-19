import Foundation
import AppKit

enum PermissionsHelper {
    /// 简单检测是否能访问 ~/Library/Mail（FDA 才能访问）
    /// 不能 100% 准确判断 FDA，但作为启发式判断够用
    static func hasFullDiskAccess() -> Bool {
        let mailDir = ("~/Library/Mail" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: mailDir) {
            // 试着列出（没有 FDA 会返回空）
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: mailDir) {
                return !contents.isEmpty || !FileManager.default.isReadableFile(atPath: mailDir + "/V10")
            }
        }
        // ~/Library/Application Support/com.apple.TCC 是另一个常用判断点
        let tcc = ("~/Library/Application Support/com.apple.TCC" as NSString).expandingTildeInPath
        return FileManager.default.isReadableFile(atPath: tcc)
    }

    /// 打开"系统设置 → 隐私与安全 → 完整磁盘访问"
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
