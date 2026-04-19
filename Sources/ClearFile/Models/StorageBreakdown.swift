import Foundation
import SwiftUI

struct StorageCategory: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let name: String
    let icon: String
    let color: Color
    let bytes: Int64
}

struct StorageBreakdown: Equatable {
    let categories: [StorageCategory]
    let totalScannedBytes: Int64
    /// 系统报告的实际磁盘已用字节
    let actualUsedBytes: Int64
    let scannedAt: Date

    var sortedDescending: [StorageCategory] {
        categories.sorted { $0.bytes > $1.bytes }
    }

    /// 其他/系统 = 实际已用 - 已分类总和。负值表示分类间有重复计算。
    var otherBytes: Int64 {
        actualUsedBytes - totalScannedBytes
    }
}
