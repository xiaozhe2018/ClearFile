import Foundation
import SwiftUI

@MainActor
final class ScheduleStore: ObservableObject {
    @Published var schedules: [CleanSchedule] = []
    @Published var history: [ScheduleRunRecord] = []
    @Published var isRunning: Bool = false

    private let storeURL: URL
    private let historyURL: URL
    private var tickTimer: Timer?

    weak var historyStore: CleanHistoryStore?

    init() {
        let supportDir = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let appDir = supportDir.appendingPathComponent("ClearFile", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.storeURL = appDir.appendingPathComponent("schedules.json")
        self.historyURL = appDir.appendingPathComponent("schedule_history.json")
        load()
    }

    // MARK: - Persistence

    func load() {
        if let data = try? Data(contentsOf: storeURL),
           let arr = try? JSONDecoder().decode([CleanSchedule].self, from: data) {
            self.schedules = arr
        }
        if let data = try? Data(contentsOf: historyURL),
           let arr = try? JSONDecoder().decode([ScheduleRunRecord].self, from: data) {
            self.history = arr
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(schedules) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    private func saveHistory() {
        // 只保留最近 100 条
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    // MARK: - CRUD

    func upsert(_ schedule: CleanSchedule) {
        if let idx = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[idx] = schedule
        } else {
            schedules.append(schedule)
        }
        save()
    }

    func delete(_ schedule: CleanSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        save()
    }

    func toggleEnabled(_ id: UUID) {
        guard let idx = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[idx].enabled.toggle()
        save()
    }

    // MARK: - Background Tick

    /// 启动定时检查（每 60 秒一次）
    func startTicking() {
        stopTicking()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runDueSchedules()
            }
        }
        // 启动时先跑一次
        Task { await runDueSchedules() }
    }

    func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// 跑所有到期的定时任务
    func runDueSchedules() async {
        guard !isRunning else { return }
        let due = schedules.filter { $0.isDue }
        guard !due.isEmpty else { return }
        for schedule in due {
            await runSchedule(schedule.id)
        }
    }

    /// 手动触发某个定时任务
    func runSchedule(_ id: UUID) async {
        guard let idx = schedules.firstIndex(where: { $0.id == id }) else { return }
        let schedule = schedules[idx]
        isRunning = true
        defer { isRunning = false }

        let result = await ScheduleRunner.run(schedule: schedule)
        schedules[idx].lastRunAt = Date()
        schedules[idx].lastRunBytesFreed = result.bytesFreed
        schedules[idx].lastRunFileCount = result.fileCount
        save()

        history.insert(
            ScheduleRunRecord(
                scheduleId: schedule.id,
                scheduleName: schedule.name,
                runAt: Date(),
                bytesFreed: result.bytesFreed,
                fileCount: result.fileCount,
                failedCount: result.failedCount
            ),
            at: 0
        )
        saveHistory()

        historyStore?.record(
            source: .schedule,
            detail: schedule.name,
            fileCount: result.fileCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failedCount
        )

        // 弹系统通知
        await NotificationHelper.notifyScheduleComplete(
            name: schedule.name,
            fileCount: result.fileCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failedCount
        )
    }
}

/// 真正干活的：扫描 → 删除（移入废纸篓）
enum ScheduleRunner {
    struct Outcome {
        let fileCount: Int
        let bytesFreed: Int64
        let failedCount: Int
    }

    @MainActor
    static func run(schedule: CleanSchedule) async -> Outcome {
        let urls = await Task.detached(priority: .utility) { () -> [URL] in
            collectMatching(
                roots: schedule.directories,
                olderThanDays: schedule.olderThanDays,
                minSizeBytes: schedule.minSizeBytes
            )
        }.value
        guard !urls.isEmpty else { return Outcome(fileCount: 0, bytesFreed: 0, failedCount: 0) }

        let result = await CleanEngine.moveToTrash(urls)
        return Outcome(
            fileCount: result.movedCount,
            bytesFreed: result.bytesFreed,
            failedCount: result.failed.count
        )
    }

    static func collectMatching(
        roots: [URL],
        olderThanDays: Int,
        minSizeBytes: Int64
    ) -> [URL] {
        let keys: [URLResourceKey] = [
            .fileSizeKey, .contentAccessDateKey,
            .contentModificationDateKey, .isRegularFileKey
        ]
        let now = Date()
        let cutoff = olderThanDays > 0
            ? Calendar.current.date(byAdding: .day, value: -olderThanDays, to: now) ?? now
            : Date.distantFuture

        var results: [URL] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            while let next = enumerator.nextObject() as? URL {
                guard let v = try? next.resourceValues(forKeys: Set(keys)),
                      v.isRegularFile == true,
                      let size = v.fileSize else { continue }

                // 大小阈值
                if minSizeBytes > 0 && Int64(size) < minSizeBytes { continue }

                // 时间阈值（按访问时间，缺省退回修改时间）
                let access = v.contentAccessDate ?? v.contentModificationDate ?? Date()
                if olderThanDays > 0 && access > cutoff { continue }

                // 防呆：保护规则命中跳过（敏感目录、iCloud、密钥）
                let suggestion = SuggestionRule.evaluate(
                    largeFile: next,
                    sizeBytes: Int64(size),
                    modifiedAt: v.contentModificationDate ?? Date()
                )
                if suggestion.level == .protected { continue }

                results.append(next)
            }
        }
        return results
    }
}
