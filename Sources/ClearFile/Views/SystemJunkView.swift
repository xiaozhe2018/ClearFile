import SwiftUI

struct SystemJunkView: View {
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var whitelist: WhitelistStore
    @State private var showConfirm = false
    @State private var showWhitelist = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .navigationTitle("系统垃圾")
        .sheet(isPresented: $showWhitelist) { WhitelistSheet() }
        .alert("确认清理", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await store.cleanSelectedCaches() }
            }
        } message: {
            ConfirmMessage(selectedCount: selectedCount, selectedSize: selectedSize, store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("系统垃圾").font(.title2.bold())
            if !store.caches.isEmpty {
                Text("\(ByteFormatter.format(totalSize)) 可清理")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            Spacer()
            switch store.cacheState {
            case .scanning:
                Button("取消扫描") { store.cancelCacheScan() }
                    .buttonStyle(.bordered)
            default:
                Button(store.caches.isEmpty ? "开始扫描" : "重新扫描") {
                    store.scanCaches()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        switch store.cacheState {
        case .idle where store.caches.isEmpty:
            ContentUnavailableView(
                "尚未扫描",
                systemImage: "trash",
                description: Text("点击右上角「开始扫描」分析 ~/Library/Caches")
            )
            .frame(maxHeight: .infinity)
        case .scanning(let progress, let current):
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .frame(width: 320)
                Text(current.isEmpty ? "准备中..." : "扫描: \(current)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxHeight: .infinity)
        case .failed(let msg):
            ContentUnavailableView(
                "扫描失败",
                systemImage: "exclamationmark.triangle",
                description: Text(msg)
            )
            .frame(maxHeight: .infinity)
        default:
            List {
                ForEach(store.caches) { group in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { store.selectedCacheIds.contains(group.id) },
                            set: { on in
                                if on { store.selectedCacheIds.insert(group.id) }
                                else { store.selectedCacheIds.remove(group.id) }
                            }
                        )).labelsHidden()
                        Image(systemName: "internaldrive")
                            .foregroundStyle(group.suggestion.level.color)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name).font(.body)
                            HStack(spacing: 6) {
                                SuggestionBadge(suggestion: group.suggestion)
                            }
                            Text(group.path.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(ByteFormatter.format(group.sizeBytes))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    .contextMenu {
                        Button("在 Finder 中显示") {
                            NSWorkspace.shared.activateFileViewerSelecting([group.path])
                        }
                        Button("加入保护清单（永不扫描）") {
                            whitelist.add(group.path.path)
                            store.caches.removeAll { $0.id == group.id }
                            store.selectedCacheIds.remove(group.id)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("已选 \(selectedCount) 项 · \(ByteFormatter.format(selectedSize))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("仅安全清理") { selectByLevel(.safe) }
                Button("安全 + 建议") { selectByLevel(.recommended) }
                Button("全选") { setAll(true) }
                    .keyboardShortcut("a", modifiers: .command)
                Button("全不选") { setAll(false) }
            } label: {
                Label("智能选择", systemImage: "wand.and.stars")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.caches.isEmpty)
            Button {
                showConfirm = true
            } label: {
                Label("清理选中", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedCount == 0)
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding(16)
    }

    private var selectedCount: Int { store.selectedCacheIds.count }
    private var selectedSize: Int64 {
        store.caches.filter { store.selectedCacheIds.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }
    private var totalSize: Int64 {
        store.caches.reduce(0) { $0 + $1.sizeBytes }
    }
    private func setAll(_ on: Bool) {
        if on {
            store.selectedCacheIds = Set(store.caches.map { $0.id })
        } else {
            store.selectedCacheIds = []
        }
    }
    private func selectByLevel(_ maxLevel: SuggestionLevel) {
        store.selectedCacheIds = Set(
            store.caches.filter { $0.suggestion.level <= maxLevel }.map { $0.id }
        )
    }
}

/// 共享：删除前空间预测消息
struct ConfirmMessage: View {
    let selectedCount: Int
    let selectedSize: Int64
    let store: ScanStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("已选 \(selectedCount) 项 · 共 \(ByteFormatter.format(selectedSize))。")
            if let usage = store.diskUsage {
                let newFree = usage.freeBytes + selectedSize
                Text("可用空间 \(ByteFormatter.format(usage.freeBytes)) → \(ByteFormatter.format(newFree))")
            }
            Text("文件将移入废纸篓，可恢复。")
        }
    }
}
