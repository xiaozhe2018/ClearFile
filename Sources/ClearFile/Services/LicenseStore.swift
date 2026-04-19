import Foundation
import SwiftUI

/// Pro 功能枚举
enum ProFeature: String, CaseIterable {
    case unlimitedClean     // 无限次清理（免费版每天 1 次）
    case scheduledClean     // 定时清理
    case privacyClean       // 无痕清理
    case duplicateDetection // 重复文件
    case appUninstaller     // 应用卸载
    case smartPresets       // 智能预设
    case menuBarMini        // 菜单栏
    case fullScanResults    // 完整扫描结果（免费版限前 20 条）

    var displayName: String {
        switch self {
        case .unlimitedClean:     return "无限清理"
        case .scheduledClean:     return "定时清理"
        case .privacyClean:       return "无痕清理"
        case .duplicateDetection: return "重复文件"
        case .appUninstaller:     return "应用卸载"
        case .smartPresets:       return "智能预设"
        case .menuBarMini:        return "菜单栏"
        case .fullScanResults:    return "完整扫描结果"
        }
    }
}

/// 许可证状态
enum LicenseStatus: Equatable {
    case free
    case pro(expiresAt: Date?)  // nil = 永久
    case trial(daysLeft: Int)
}

/// 许可证管理（持久化到 UserDefaults + Keychain 验证）
@MainActor
final class LicenseStore: ObservableObject {
    @Published var status: LicenseStatus = .free
    @Published var licenseKey: String = ""
    @Published var activationError: String? = nil
    @Published var isActivating: Bool = false

    /// 今天免费清理次数
    @Published var freeCleanCountToday: Int = 0

    private let defaults = UserDefaults.standard
    private let keyLicenseKey    = "ClearFile.licenseKey"
    private let keyActivatedAt   = "ClearFile.activatedAt"
    private let keyFreeCleanDate = "ClearFile.freeCleanDate"
    private let keyFreeCleanCount = "ClearFile.freeCleanCount"
    private let keyTrialStartedAt = "ClearFile.trialStartedAt"

    /// Gumroad product ID（上线后填入）
    var gumroadProductId: String = ""

    /// 免费版每天可清理次数
    let freeCleanLimit = 1
    /// 免费版扫描结果显示上限
    let freeResultLimit = 20
    /// 试用天数
    let trialDays = 7

    /// 自用版：改为 false 时启用付费限制
    private let selfUseMode = true

    init() {
        if selfUseMode {
            status = .pro(expiresAt: nil)
        } else {
            loadSaved()
            startTrialIfFirstLaunch()
            resetDailyCountIfNeeded()
        }
    }

    // MARK: - Query

    var isPro: Bool {
        switch status {
        case .pro:   return true
        case .trial(let d): return d > 0
        case .free:  return false
        }
    }

    var trialDaysLeft: Int? {
        if case .trial(let d) = status { return d }
        return nil
    }

    var isTrialExpired: Bool {
        if let start = defaults.object(forKey: keyTrialStartedAt) as? Date {
            return Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0 >= trialDays
        }
        return false
    }

    func isUnlocked(_ feature: ProFeature) -> Bool {
        isPro
    }

    /// 免费版是否还有今天的清理次数
    var canFreeClean: Bool {
        freeCleanCountToday < freeCleanLimit
    }

    /// 调用一次免费清理配额
    func consumeFreeClean() {
        freeCleanCountToday += 1
        defaults.set(freeCleanCountToday, forKey: keyFreeCleanCount)
        defaults.set(todayString(), forKey: keyFreeCleanDate)
    }

    // MARK: - Activation

    /// 用 license key 激活 Pro
    func activate(key: String) async {
        isActivating = true
        activationError = nil
        licenseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !licenseKey.isEmpty else {
            activationError = "请输入许可证密钥"
            isActivating = false
            return
        }

        // 1. HMAC 离线验证（主要方式，不需要联网）
        if LicenseKeyValidator.validate(licenseKey) {
            savePro(key: licenseKey)
            isActivating = false
            return
        }

        // 2. Gumroad API 在线验证（备用，上线后启用）
        if !gumroadProductId.isEmpty {
            do {
                let success = try await verifyGumroad(key: licenseKey)
                if success {
                    savePro(key: licenseKey)
                    isActivating = false
                    return
                }
            } catch {
                // 联网失败 fall through 到错误提示
            }
        }

        activationError = "许可证密钥无效"
        isActivating = false
    }

    func deactivate() {
        status = .free
        licenseKey = ""
        defaults.removeObject(forKey: keyLicenseKey)
        defaults.removeObject(forKey: keyActivatedAt)
    }

    // MARK: - Gumroad

    private func verifyGumroad(key: String) async throws -> Bool {
        let url = URL(string: "https://api.gumroad.com/v2/licenses/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = "product_id=\(gumroadProductId)&license_key=\(key)"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool else { return false }
        return success
    }

    // MARK: - Trial

    private func startTrialIfFirstLaunch() {
        // 已经是 Pro → 不需要试用
        if case .pro = status { return }
        // 已经开始过试用
        if let startDate = defaults.object(forKey: keyTrialStartedAt) as? Date {
            let daysPassed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            let remaining = max(trialDays - daysPassed, 0)
            if remaining > 0 {
                status = .trial(daysLeft: remaining)
            } else {
                status = .free
            }
            return
        }
        // 首次启动 → 自动开始 7 天试用
        defaults.set(Date(), forKey: keyTrialStartedAt)
        status = .trial(daysLeft: trialDays)
    }

    // MARK: - Persistence

    private func savePro(key: String) {
        licenseKey = key
        status = .pro(expiresAt: nil)
        defaults.set(key, forKey: keyLicenseKey)
        defaults.set(Date().timeIntervalSince1970, forKey: keyActivatedAt)
    }

    private func loadSaved() {
        if let key = defaults.string(forKey: keyLicenseKey), !key.isEmpty {
            licenseKey = key
            status = .pro(expiresAt: nil)
        }
    }

    private func resetDailyCountIfNeeded() {
        let saved = defaults.string(forKey: keyFreeCleanDate) ?? ""
        if saved != todayString() {
            freeCleanCountToday = 0
            defaults.set(0, forKey: keyFreeCleanCount)
            defaults.set(todayString(), forKey: keyFreeCleanDate)
        } else {
            freeCleanCountToday = defaults.integer(forKey: keyFreeCleanCount)
        }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
