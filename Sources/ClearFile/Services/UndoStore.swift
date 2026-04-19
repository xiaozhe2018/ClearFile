import Foundation
import SwiftUI

/// 跟踪最近一次清理，提供撤销窗口（默认 30 秒）
@MainActor
final class UndoStore: ObservableObject {
    @Published var pending: PendingUndo? = nil
    @Published var statusMessage: String? = nil

    private var clearTask: Task<Void, Never>?

    struct PendingUndo: Equatable {
        let id: UUID
        let source: String  // "系统垃圾"/"文件清理"/"清理最近"/"一键清理"
        let items: [TrashedItem]
        let bytes: Int64
        let expiresAt: Date

        var fileCount: Int { items.count }
    }

    /// 注册一次新清理。会覆盖之前未撤销的（更老的不能再撤销）
    func register(source: String, result: CleanResult, ttl: TimeInterval = 30) {
        clearTask?.cancel()
        guard !result.trashed.isEmpty else { return }
        let undo = PendingUndo(
            id: UUID(),
            source: source,
            items: result.trashed,
            bytes: result.bytesFreed,
            expiresAt: Date().addingTimeInterval(ttl)
        )
        self.pending = undo
        self.statusMessage = nil

        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(ttl * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.pending?.id == undo.id {
                    self?.pending = nil
                }
            }
        }
    }

    /// 执行撤销
    func performUndo() async {
        guard let undo = pending else { return }
        clearTask?.cancel()
        let outcome = await CleanEngine.restore(undo.items)
        if outcome.failed.isEmpty {
            self.statusMessage = "✅ 已恢复 \(outcome.restored) 项 · \(ByteFormatter.format(undo.bytes))"
        } else {
            self.statusMessage = "⚠️ 恢复 \(outcome.restored) 项，失败 \(outcome.failed.count) 项"
        }
        self.pending = nil

        // 5 秒后清掉提示
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                if self?.statusMessage != nil {
                    self?.statusMessage = nil
                }
            }
        }
    }

    func dismiss() {
        clearTask?.cancel()
        pending = nil
    }
}
