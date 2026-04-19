import SwiftUI

/// 全局撤销 toast。30 秒倒计时 + 一键撤销按钮 + 关闭按钮
struct UndoBanner: View {
    @EnvironmentObject var undoStore: UndoStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if let pending = undoStore.pending {
                pendingBanner(pending)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let msg = undoStore.statusMessage {
                statusBanner(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: undoStore.pending)
        .animation(.spring(duration: 0.25), value: undoStore.statusMessage)
        .onReceive(timer) { now = $0 }
    }

    private func pendingBanner(_ pending: UndoStore.PendingUndo) -> some View {
        let remaining = max(0, Int(pending.expiresAt.timeIntervalSince(now)))
        return HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("已清理 \(pending.fileCount) 项 · \(ByteFormatter.format(pending.bytes))")
                    .font(.subheadline.weight(.medium))
                Text("\(pending.source) · \(remaining) 秒后失效")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await undoStore.performUndo() }
            } label: {
                Label("撤销", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button {
                undoStore.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private func statusBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Text(msg).font(.callout.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24).padding(.top, 12)
    }
}
