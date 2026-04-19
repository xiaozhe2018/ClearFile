import Foundation

/// 轻量国际化。SPM 不需要 .xcstrings，直接代码切换。
enum L10n {
    private static var isEn: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("en") ?? false
    }

    // MARK: - Sidebar / Routes
    static var overview: String     { isEn ? "Overview"        : "概览" }
    static var systemJunk: String   { isEn ? "System Junk"     : "系统垃圾" }
    static var fileClean: String    { isEn ? "File Cleanup"    : "文件清理" }
    static var cleanRecent: String  { isEn ? "Recent Files"    : "清理最近" }
    static var duplicates: String   { isEn ? "Duplicates"      : "重复文件" }
    static var appUninstaller: String { isEn ? "App Uninstaller" : "应用卸载" }
    static var privacy: String      { isEn ? "Privacy Clean"   : "无痕清理" }
    static var schedules: String    { isEn ? "Scheduled Clean" : "定时清理" }
    static var fileSearch: String   { isEn ? "Search & Delete" : "搜索删除" }

    // MARK: - Common
    static var scan: String         { isEn ? "Scan"            : "开始扫描" }
    static var rescan: String       { isEn ? "Rescan"          : "重新扫描" }
    static var cancelScan: String   { isEn ? "Cancel"          : "取消扫描" }
    static var clean: String        { isEn ? "Clean"           : "清理" }
    static var moveToTrash: String  { isEn ? "Move to Trash"   : "移入废纸篓" }
    static var confirm: String      { isEn ? "Confirm"         : "确认" }
    static var cancel: String       { isEn ? "Cancel"          : "取消" }
    static var selectAll: String    { isEn ? "Select All"      : "全选" }
    static var deselectAll: String  { isEn ? "Deselect All"    : "全不选" }
    static var smartSelect: String  { isEn ? "Smart Select"    : "智能选择" }
    static var safeOnly: String     { isEn ? "Safe Only"       : "仅安全清理" }
    static var safeRecommended: String { isEn ? "Safe + Recommended" : "安全 + 建议" }
    static var showInFinder: String { isEn ? "Show in Finder"  : "在 Finder 中显示" }
    static var preview: String      { isEn ? "Preview"         : "预览" }
    static var refresh: String      { isEn ? "Refresh"         : "刷新" }
    static var scanAll: String      { isEn ? "Scan All"        : "扫描全部" }
    static var refreshDisk: String  { isEn ? "Refresh Disk"    : "刷新磁盘" }

    // MARK: - Overview
    static var yourMac: String      { isEn ? "Your Mac"        : "Your Mac" }
    static var diskUsed: String     { isEn ? "Used"            : "已用" }
    static var diskFree: String     { isEn ? "Available"       : "可用" }
    static var fileBreakdown: String { isEn ? "Storage Breakdown" : "文件占比" }
    static var smartPresets: String { isEn ? "Smart Presets"   : "智能预设" }
    static var modules: String      { isEn ? "Modules"         : "功能模块" }
    static var cleanTrend: String   { isEn ? "Clean Trend (30d)" : "清理趋势（30 天）" }
    static var lastCleanDone: String { isEn ? "Last clean completed" : "上次清理已完成" }

    // MARK: - License
    static var upgradePro: String   { isEn ? "Upgrade Pro"     : "升级 Pro" }
    static var proTrial: String     { isEn ? "Pro Trial"       : "Pro 试用中" }
    static func trialDaysLeft(_ n: Int) -> String {
        isEn ? "\(n) days left" : "剩余 \(n) 天"
    }
    static var activatePro: String  { isEn ? "Activate ClearFile Pro" : "激活 ClearFile Pro" }
    static var enterLicenseKey: String { isEn ? "Enter license key" : "输入许可证密钥" }
    static var activate: String     { isEn ? "Activate"        : "激活" }
    static var buyPro: String       { isEn ? "Buy Pro"         : "购买 Pro" }
    static var laterMaybe: String   { isEn ? "Maybe later"     : "稍后再说" }
    static var proFeature: String   { isEn ? "is a Pro feature" : "是 Pro 功能" }
    static var unlockAll: String    { isEn ? "Upgrade ClearFile Pro to unlock all features\nBuy once, use forever" : "升级 ClearFile Pro 解锁全部功能\n一次购买，永久使用" }

    // MARK: - Suggestion
    static var safe: String         { isEn ? "Safe"            : "安全清理" }
    static var recommended: String  { isEn ? "Recommended"     : "建议清理" }
    static var cleanable: String    { isEn ? "Cleanable"       : "可清理" }
    static var caution: String      { isEn ? "Caution"         : "慎重" }
    static var protected: String    { isEn ? "Protected"       : "保护" }

    // MARK: - Privacy
    static var lowRisk: String      { isEn ? "Low Risk"        : "低风险" }
    static var medRisk: String      { isEn ? "Medium Risk"     : "中风险" }
    static var highRisk: String     { isEn ? "High Risk"       : "高风险" }
    static var closeBrowserWarning: String {
        isEn ? "Close browsers before cleaning. Cookies cleanup will require re-login."
             : "建议清理前关闭浏览器，否则数据库可能被锁定导致失败。Cookies 清理后需重新登录网站。"
    }

    // MARK: - Onboarding
    static var welcome: String      { isEn ? "Welcome to ClearFile" : "欢迎使用 ClearFile" }
    static var welcomeSub: String   { isEn ? "A safe & reversible Mac disk cleaner" : "一款保守、可恢复的 Mac 磁盘清理工具" }
    static var welcomeNote: String  {
        isEn ? "All deletions go to Trash · 30-second undo · Sensitive dirs never touched"
             : "所有清理都走废纸篓 · 30 天内可恢复 · 敏感目录永远不动"
    }
    static var featureGlance: String { isEn ? "Feature Overview" : "功能速览" }
    static var skip: String          { isEn ? "Skip"             : "跳过" }
    static var next: String          { isEn ? "Next"             : "下一步" }
    static var getStarted: String    { isEn ? "Get Started"      : "开始使用" }

    // MARK: - Presets
    static var devClean: String      { isEn ? "Developer Clean"  : "开发者清理" }
    static var devCleanSub: String   { isEn ? "Xcode DerivedData / npm / Docker / Homebrew" : "Xcode DerivedData / npm / Docker / Homebrew" }
    static var preDeparture: String  { isEn ? "Pre-Travel Clean" : "出差前清理" }
    static var preDepartureSub: String { isEn ? "Downloads + Screenshots + Trash" : "Downloads + 截图 + 废纸篓" }
    static var free5gb: String       { isEn ? "Free 5 GB"        : "释放 5GB" }
    static var free5gbSub: String    { isEn ? "Auto-select safe items until 5GB freed" : "按建议优先清理直到释放 5GB" }
}
