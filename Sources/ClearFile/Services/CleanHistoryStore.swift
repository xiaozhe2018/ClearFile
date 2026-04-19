import Foundation
import SwiftUI

@MainActor
final class CleanHistoryStore: ObservableObject {
    @Published var records: [CleanHistoryRecord] = []

    private let fileURL: URL
    private let maxRecords = 500

    init() {
        let supportDir = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let appDir = supportDir.appendingPathComponent("ClearFile", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("clean_history.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let arr = try? JSONDecoder().decode([CleanHistoryRecord].self, from: data) else {
            return
        }
        self.records = arr
    }

    private func save() {
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func record(
        source: CleanSource,
        detail: String = "",
        fileCount: Int,
        bytesFreed: Int64,
        failedCount: Int
    ) {
        let rec = CleanHistoryRecord(
            timestamp: Date(),
            source: source,
            detail: detail,
            fileCount: fileCount,
            bytesFreed: bytesFreed,
            failedCount: failedCount
        )
        records.insert(rec, at: 0)
        save()
    }

    func clearAll() {
        records = []
        save()
    }

    // MARK: - Aggregations

    var totalBytes: Int64 {
        records.reduce(0) { $0 + $1.bytesFreed }
    }

    var totalCount: Int {
        records.reduce(0) { $0 + $1.fileCount }
    }

    func bytesFreed(in days: Int) -> Int64 {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.timestamp >= cutoff }.reduce(0) { $0 + $1.bytesFreed }
    }

    func count(in days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return records.filter { $0.timestamp >= cutoff }.count
    }

    /// 过去 N 天每天释放字节数（用于柱状图），返回按日期升序
    func dailyTrend(days: Int = 30) -> [(date: Date, bytes: Int64)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var bucket: [Date: Int64] = [:]
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                bucket[d] = 0
            }
        }
        for rec in records {
            let day = cal.startOfDay(for: rec.timestamp)
            if bucket[day] != nil {
                bucket[day]! += rec.bytesFreed
            }
        }
        return bucket
            .sorted(by: { $0.key < $1.key })
            .map { ($0.key, $0.value) }
    }
}
