import Foundation
import SwiftUI
import AppKit

@MainActor
final class ScanStore: ObservableObject {
    @Published var diskUsage: DiskUsage?
    @Published var caches: [CacheGroup] = []
    @Published var largeFiles: [LargeFile] = []
    @Published var recentFiles: [LargeFile] = []

    @Published var diskState: ScanState = .idle
    @Published var cacheState: ScanState = .idle
    @Published var largeFileState: ScanState = .idle
    @Published var recentFileState: ScanState = .idle

    @Published var breakdown: StorageBreakdown?
    @Published var breakdownState: ScanState = .idle

    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var duplicateState: ScanState = .idle
    @Published var duplicateProgress: String = ""

    @Published var apps: [InstalledApp] = []
    @Published var appsState: ScanState = .idle
    @Published var selectedAppResiduals: [URL: [AppResidual]] = [:]

    @Published var privacyTraces: [PrivacyTrace] = []
    @Published var privacyState: ScanState = .idle
    @Published var selectedPrivacyIds: Set<String> = []

    /// 扫描截断时记录原始结果总数（用于 UI banner 提示）
    @Published var largeFilesTruncated: Int? = nil
    @Published var recentFilesTruncated: Int? = nil

    /// 选中态用 Set 而不是嵌入 model，避免每个 toggle 触发整张表重渲染
    @Published var selectedCacheIds: Set<UUID> = []
    @Published var selectedLargeFileIds: Set<UUID> = []
    @Published var selectedRecentFileIds: Set<UUID> = []

    @Published var lastCleanResult: CleanResult?

    // 一键清理状态
    @Published var oneClickPlan: OneClickClean.Plan?
    @Published var oneClickStatus: String = ""
    @Published var isOneClickRunning: Bool = false

    @Published var searchResults: [LargeFile] = []
    @Published var searchState: ScanState = .idle
    @Published var selectedSearchIds: Set<UUID> = []

    private var cacheTask: Task<Void, Never>?
    private var largeFileTask: Task<Void, Never>?
    private var recentFileTask: Task<Void, Never>?
    private var oneClickTask: Task<Void, Never>?
    private var breakdownTask: Task<Void, Never>?
    private var duplicateTask: Task<Void, Never>?
    private var appsTask: Task<Void, Never>?
    private var metaQuery: NSMetadataQuery?
    private var metaQueryObserver: NSObjectProtocol?

    weak var historyStore: CleanHistoryStore?
    weak var undoStore: UndoStore?
    weak var errorCenter: ErrorCenter?

    // MARK: - Privacy

    func scanPrivacy() {
        privacyState = .scanning(progress: 0, current: "")
        privacyTraces = []
        selectedPrivacyIds = []
        Task {
            let result = await PrivacyScanner.scan()
            self.privacyTraces = result
            // 默认选中低风险
            self.selectedPrivacyIds = Set(result.filter { $0.risk == .low }.map { $0.id })
            self.privacyState = .completed
        }
    }

    func cleanSelectedPrivacy() async {
        let chosen = privacyTraces.filter { selectedPrivacyIds.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let result = await PrivacyScanner.clean(chosen)
        self.lastCleanResult = result
        // 移除已清理项
        let cleanedIds = Set(chosen.map { $0.id })
        self.privacyTraces.removeAll { cleanedIds.contains($0.id) }
        self.selectedPrivacyIds.subtract(cleanedIds)
        historyStore?.record(
            source: .systemJunk,
            detail: "无痕清理 \(result.movedCount) 项",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "无痕清理", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }

    // MARK: - App Uninstaller

    func loadApps() {
        appsTask?.cancel()
        appsState = .scanning(progress: 0, current: "")
        apps = []
        appsTask = Task {
            let result = await AppUninstaller.shared.listInstalledApps()
            self.apps = result
            self.appsState = .completed
        }
    }

    func loadResiduals(for app: InstalledApp) async {
        let residuals = await AppUninstaller.shared.findResiduals(for: app)
        self.selectedAppResiduals[app.bundleURL] = residuals
    }

    func uninstallApp(_ app: InstalledApp, includeResiduals: [AppResidual]) async {
        let plan = AppUninstallPlan(app: app, residuals: includeResiduals)
        let result = await AppUninstaller.shared.uninstall(plan: plan)
        self.lastCleanResult = result
        self.apps.removeAll { $0.id == app.id }
        self.selectedAppResiduals.removeValue(forKey: app.bundleURL)
        historyStore?.record(
            source: .largeFiles,
            detail: "卸载 \(app.name)（含 \(includeResiduals.count) 项残留）",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "应用卸载", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }

    // MARK: - Duplicates

    func scanDuplicates(roots: [URL], minSizeMB: Int = 1) {
        duplicateTask?.cancel()
        duplicateState = .scanning(progress: 0, current: "")
        duplicateProgress = ""
        duplicateGroups = []
        duplicateTask = Task {
            do {
                let result = try await DuplicateDetector.shared.scan(
                    roots: roots,
                    minSizeBytes: Int64(minSizeMB) * 1024 * 1024
                ) { stage in
                    Task { @MainActor [weak self] in
                        self?.duplicateProgress = stage
                    }
                }
                self.duplicateGroups = result
                self.duplicateState = .completed
            } catch is CancellationError {
                self.duplicateState = .idle
            } catch {
                self.duplicateState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelDuplicateScan() { duplicateTask?.cancel() }

    func deleteSelectedDuplicates() async {
        var urls: [URL] = []
        for group in duplicateGroups {
            for f in group.files where !f.keep {
                urls.append(f.url)
            }
        }
        guard !urls.isEmpty else { return }
        let result = await CleanEngine.moveToTrash(urls)
        self.lastCleanResult = result
        let failedSet = Set(result.failed.map { $0.0 })
        // 从组中移除已删除
        for i in duplicateGroups.indices {
            duplicateGroups[i].files.removeAll { f in urls.contains(f.url) && !failedSet.contains(f.url) }
        }
        // 移除只剩 1 个文件的组
        duplicateGroups.removeAll { $0.files.count <= 1 }
        historyStore?.record(
            source: .largeFiles,
            detail: "重复文件 \(result.movedCount) 项",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "重复文件", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }

    func toggleCategoryExpand(_ key: String) {
        if expandedCategoryKey == key {
            expandedCategoryKey = nil
            subCategories = []
            subCategoriesProgress = ""
            return
        }
        expandedCategoryKey = key
        subCategories = []
        subCategoriesLoading = true
        subCategoriesProgress = "准备中…"
        subCategoriesScanned = 0
        subCategoriesTotal = 0
        Task {
            let result = await BreakdownEngine.shared.topSubdirectories(for: key, limit: 15) { scanned, total, current in
                Task { @MainActor [weak self] in
                    self?.subCategoriesScanned = scanned
                    self?.subCategoriesTotal = total
                    self?.subCategoriesProgress = "\(scanned)/\(total) · \(current)"
                }
            }
            self.subCategories = result
            self.subCategoriesLoading = false
            self.subCategoriesProgress = ""
        }
    }

    // MARK: - Scan All

    @Published var scanAllRunning = false

    func scanAll() {
        guard !scanAllRunning else { return }
        scanAllRunning = true
        // 并行触发所有模块
        scanCaches()
        scanLargeFiles()
        scanRecentFiles(filter: RecentFileFilter())
        scanPrivacy()
        computeBreakdown()
        loadApps()
        // 简单方案：3 秒后标记完成（实际各模块各自有 state）
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.scanAllRunning = false
        }
    }

    // MARK: - Breakdown

    @Published var breakdownProgress: String = ""
    @Published var expandedCategoryKey: String? = nil
    @Published var subCategories: [StorageCategory] = []
    @Published var subCategoriesLoading = false
    @Published var subCategoriesProgress: String = ""
    @Published var subCategoriesScanned: Int = 0
    @Published var subCategoriesTotal: Int = 0

    func computeBreakdown() {
        breakdownTask?.cancel()
        breakdownState = .scanning(progress: 0, current: "")
        breakdownProgress = ""
        breakdownTask = Task {
            var completed = 0
            let total = BreakdownEngine.sources.count
            let result = await BreakdownEngine.shared.compute { cat in
                Task { @MainActor [weak self] in
                    completed += 1
                    self?.breakdownProgress = "\(completed)/\(total) · \(cat.name) \(ByteFormatter.format(cat.bytes))"
                    self?.breakdownState = .scanning(
                        progress: Double(completed) / Double(total),
                        current: cat.name
                    )
                }
            }
            self.breakdown = result
            self.breakdownProgress = ""
            self.breakdownState = .completed
        }
    }

    // MARK: - Disk

    func refreshDisk() {
        Task {
            do {
                let usage = try await ScanEngine.shared.diskUsage()
                self.diskUsage = usage
                self.diskState = .completed
            } catch {
                self.diskState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Cache scan

    func scanCaches() {
        cacheTask?.cancel()
        cacheState = .scanning(progress: 0, current: "")
        caches = []
        selectedCacheIds = []
        cacheTask = Task {
            do {
                let result = try await ScanEngine.shared.scanUserCaches { progress, current in
                    Task { @MainActor [weak self] in
                        self?.cacheState = .scanning(progress: progress, current: current)
                    }
                }
                self.caches = result
                // 默认勾选 safe + recommended
                self.selectedCacheIds = Set(result.filter { $0.suggestion.level <= .recommended }.map { $0.id })
                self.cacheState = .completed
            } catch is CancellationError {
                self.cacheState = .idle
            } catch {
                self.cacheState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelCacheScan() {
        cacheTask?.cancel()
    }

    func cleanSelectedCaches() async {
        let chosen = caches.filter { selectedCacheIds.contains($0.id) }
        let urls = chosen.map { $0.path }
        guard !urls.isEmpty else { return }
        let result = await CleanEngine.moveToTrash(urls)
        self.lastCleanResult = result
        let failedSet = Set(result.failed.map { $0.0 })
        self.caches.removeAll { c in urls.contains(c.path) && !failedSet.contains(c.path) }
        // 从选中集合中清掉已删除的
        for c in chosen where !failedSet.contains(c.path) {
            selectedCacheIds.remove(c.id)
        }
        historyStore?.record(
            source: .systemJunk,
            detail: "缓存目录 \(result.movedCount) 项",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "系统垃圾", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }

    // MARK: - Large files

    func scanLargeFiles(roots: [URL]? = nil, filter: FileScanFilter = FileScanFilter()) {
        largeFileTask?.cancel()
        largeFileState = .scanning(progress: 0, current: "")
        largeFiles = []
        largeFilesTruncated = nil
        selectedLargeFileIds = []
        let defaultRoots = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Movies"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }

        let scanRoots = roots ?? defaultRoots
        largeFileTask = Task {
            do {
                let outcome = try await ScanEngine.shared.scanFiles(
                    roots: scanRoots,
                    filter: filter
                ) { progress, current in
                    Task { @MainActor [weak self] in
                        self?.largeFileState = .scanning(progress: progress, current: current)
                    }
                }
                self.largeFiles = outcome.files
                self.largeFilesTruncated = outcome.truncatedFrom
                self.largeFileState = .completed
            } catch is CancellationError {
                self.largeFileState = .idle
            } catch {
                self.largeFileState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelLargeFileScan() {
        largeFileTask?.cancel()
    }

    // MARK: - One-Click Safe Clean

    func runOneClickPlan() {
        oneClickTask?.cancel()
        oneClickPlan = nil
        oneClickStatus = "准备中…"
        isOneClickRunning = true
        oneClickTask = Task {
            do {
                let plan = try await OneClickClean.buildPlan { stage in
                    Task { @MainActor [weak self] in
                        self?.oneClickStatus = stage
                    }
                }
                self.oneClickPlan = plan
                self.oneClickStatus = plan.totalCount == 0
                    ? "没有发现可清理的安全项目"
                    : "找到 \(plan.totalCount) 项 · \(ByteFormatter.format(plan.totalBytes))"
            } catch is CancellationError {
                self.oneClickStatus = "已取消"
            } catch {
                self.oneClickStatus = "扫描失败：\(error.localizedDescription)"
            }
            self.isOneClickRunning = false
        }
    }

    func executeOneClickPlan() async {
        guard let plan = oneClickPlan else { return }
        let detail = "缓存 \(plan.cacheTargets.count) · 大文件 \(plan.largeFileTargets.count)"
        isOneClickRunning = true
        oneClickStatus = "正在移入废纸篓…"
        let result = await OneClickClean.execute(plan)
        self.lastCleanResult = result
        self.oneClickStatus = "✅ 已清理 \(result.movedCount) 项 · 释放 \(ByteFormatter.format(result.bytesFreed))"
        historyStore?.record(
            source: .oneClick,
            detail: detail,
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "一键清理", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        self.oneClickPlan = nil
        self.isOneClickRunning = false
        refreshDisk()
    }

    func cancelOneClick() {
        oneClickTask?.cancel()
        isOneClickRunning = false
    }

    func runPreset(_ preset: SmartPreset) {
        oneClickTask?.cancel()
        oneClickPlan = nil
        oneClickStatus = "运行预设：\(preset.title)…"
        isOneClickRunning = true
        oneClickTask = Task {
            let plan: OneClickClean.Plan
            switch preset.key {
            case "developer":     plan = await SmartPresets.developerScan()
            case "predeparture":  plan = await SmartPresets.preDepartureScan()
            case "free5gb":
                if let p = try? await SmartPresets.freeBytes(5 * 1024 * 1024 * 1024) {
                    plan = p
                } else {
                    plan = OneClickClean.Plan(cacheTargets: [], largeFileTargets: [])
                }
            default: plan = OneClickClean.Plan(cacheTargets: [], largeFileTargets: [])
            }
            self.oneClickPlan = plan
            self.oneClickStatus = plan.totalCount == 0
                ? "「\(preset.title)」未发现可清理项"
                : "\(preset.title)：找到 \(plan.totalCount) 项 · \(ByteFormatter.format(plan.totalBytes))"
            self.isOneClickRunning = false
        }
    }

    // MARK: - Recent files

    func scanRecentFiles(filter: RecentFileFilter) {
        recentFileTask?.cancel()
        recentFileState = .scanning(progress: 0, current: "")
        recentFiles = []
        recentFilesTruncated = nil
        selectedRecentFileIds = []
        recentFileTask = Task {
            do {
                let outcome = try await ScanEngine.shared.scanRecentFiles(filter: filter) { progress, current in
                    Task { @MainActor [weak self] in
                        self?.recentFileState = .scanning(progress: progress, current: current)
                    }
                }
                self.recentFiles = outcome.files
                self.recentFilesTruncated = outcome.truncatedFrom
                self.recentFileState = .completed
            } catch is CancellationError {
                self.recentFileState = .idle
            } catch {
                self.recentFileState = .failed(error.localizedDescription)
            }
        }
    }

    func cancelRecentFileScan() {
        recentFileTask?.cancel()
    }

    func deleteSelectedRecentFiles() async {
        let chosen = recentFiles.filter { selectedRecentFileIds.contains($0.id) }
        let urls = chosen.map { $0.url }
        guard !urls.isEmpty else { return }
        let result = await CleanEngine.moveToTrash(urls)
        self.lastCleanResult = result
        let failedSet = Set(result.failed.map { $0.0 })
        self.recentFiles.removeAll { f in urls.contains(f.url) && !failedSet.contains(f.url) }
        for f in chosen where !failedSet.contains(f.url) {
            selectedRecentFileIds.remove(f.id)
        }
        historyStore?.record(
            source: .largeFiles,
            detail: "最近文件 \(result.movedCount) 项",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "清理最近", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }

    // MARK: - File Search

    func searchFiles(query: String, scopes: [Any]) {
        if let obs = metaQueryObserver {
            NotificationCenter.default.removeObserver(obs)
            metaQueryObserver = nil
        }
        metaQuery?.stop()
        metaQuery = nil

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchState = .idle
            searchResults = []
            selectedSearchIds = []
            return
        }

        searchState = .scanning(progress: 0, current: "")
        searchResults = []
        selectedSearchIds = []

        let mq = NSMetadataQuery()
        metaQuery = mq
        mq.predicate = NSPredicate(format: "kMDItemDisplayName LIKE[cd] %@", "*\(trimmed)*")
        mq.searchScopes = scopes
        mq.sortDescriptors = [NSSortDescriptor(key: kMDItemFSSize as String, ascending: false)]

        metaQueryObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: mq,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleSearchFinished() }
        }

        mq.start()
    }

    private func handleSearchFinished() {
        guard let mq = metaQuery else { return }
        mq.disableUpdates()

        var results: [LargeFile] = []
        let count = min(mq.resultCount, 1000)
        for i in 0..<count {
            guard let item = mq.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: kMDItemPath as String) as? String
            else { continue }
            let url = URL(fileURLWithPath: path)
            if WhitelistGate.contains(url: url) { continue }
            let size = (item.value(forAttribute: kMDItemFSSize as String) as? Int).map(Int64.init) ?? 0
            let date = (item.value(forAttribute: kMDItemContentModificationDate as String) as? Date) ?? Date()
            let suggestion = SuggestionRule.evaluate(largeFile: url, sizeBytes: size, modifiedAt: date)
            results.append(LargeFile(url: url, sizeBytes: size, modifiedAt: date, suggestion: suggestion))
        }

        mq.enableUpdates()
        mq.stop()
        searchResults = results
        searchState = .completed
    }

    func cancelFileSearch() {
        if let obs = metaQueryObserver {
            NotificationCenter.default.removeObserver(obs)
            metaQueryObserver = nil
        }
        metaQuery?.stop()
        metaQuery = nil
        searchState = .idle
    }

    func deleteSelectedSearchFiles() async {
        let chosen = searchResults.filter { selectedSearchIds.contains($0.id) }
        let urls = chosen.map { $0.url }
        guard !urls.isEmpty else { return }
        let result = await CleanEngine.moveToTrash(urls)
        self.lastCleanResult = result
        let failedSet = Set(result.failed.map { $0.0 })
        self.searchResults.removeAll { f in urls.contains(f.url) && !failedSet.contains(f.url) }
        for f in chosen where !failedSet.contains(f.url) {
            selectedSearchIds.remove(f.id)
        }
        historyStore?.record(
            source: .largeFiles,
            detail: "搜索删除 \(result.movedCount) 项",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "搜索删除", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }

    func deleteSelectedLargeFiles() async {
        let chosen = largeFiles.filter { selectedLargeFileIds.contains($0.id) }
        let urls = chosen.map { $0.url }
        guard !urls.isEmpty else { return }
        let result = await CleanEngine.moveToTrash(urls)
        self.lastCleanResult = result
        let failedSet = Set(result.failed.map { $0.0 })
        self.largeFiles.removeAll { f in urls.contains(f.url) && !failedSet.contains(f.url) }
        for f in chosen where !failedSet.contains(f.url) {
            selectedLargeFileIds.remove(f.id)
        }
        historyStore?.record(
            source: .largeFiles,
            detail: "手动选择 \(result.movedCount) 项",
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
        undoStore?.register(source: "文件清理", result: result)
        if !result.failed.isEmpty { errorCenter?.record(result.failed) }
        refreshDisk()
    }
}
