import SwiftUI
import AppKit

/// 菜单栏弹出窗口：磁盘概览 + 一键操作 + 撤销
struct MenuBarView: View {
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var undoStore: UndoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            diskSection
            Divider()
            actionSection
            if let pending = undoStore.pending {
                Divider()
                undoSection(pending)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { store.refreshDisk() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive.fill")
                .foregroundStyle(.tint)
            Text("ClearFile")
                .font(.headline)
            Spacer()
        }
    }

    @ViewBuilder
    private var diskSection: some View {
        if let usage = store.diskUsage {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("磁盘空间").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(usage.usedRatio * 100))%")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(usage.usedRatio > 0.9 ? .red : .primary)
                }
                ProgressView(value: usage.usedRatio)
                    .tint(usage.usedRatio > 0.9 ? .red : .accentColor)
                HStack {
                    Text("可用 \(ByteFormatter.format(usage.freeBytes))")
                    Spacer()
                    Text("总 \(ByteFormatter.format(usage.totalBytes))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                ProgressView().scaleEffect(0.5)
                Text("读取磁盘…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.isOneClickRunning {
                HStack {
                    ProgressView().scaleEffect(0.6)
                    Text(store.oneClickStatus).font(.caption).lineLimit(1)
                }
            } else if let plan = store.oneClickPlan, plan.totalCount > 0 {
                Button {
                    Task { await store.executeOneClickPlan() }
                } label: {
                    Label("清理 \(ByteFormatter.format(plan.totalBytes))", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    store.runOneClickPlan()
                } label: {
                    Label("一键扫描安全清理", systemImage: "wand.and.sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if !store.oneClickStatus.isEmpty && !store.isOneClickRunning {
                Text(store.oneClickStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func undoSection(_ pending: UndoStore.PendingUndo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("已清理 \(pending.fileCount) 项 · \(ByteFormatter.format(pending.bytes))")
                    .font(.caption.weight(.medium))
                Text(pending.source).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("撤销") {
                Task { await undoStore.performUndo() }
            }
            .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack {
            Button("打开主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Clear") || $0.title == "" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderless)
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .font(.caption)
    }
}
