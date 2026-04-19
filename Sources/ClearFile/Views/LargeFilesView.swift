import SwiftUI
import QuickLook

struct LargeFilesView: View {
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var whitelist: WhitelistStore
    @State private var filter = FileScanFilter()
    @State private var showConfirm = false
    @State private var previewURL: URL?
    @State private var tableSelection = Set<UUID>()
    @State private var customRoots: [URL] = []
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            if !customRoots.isEmpty {
                customRootsBar
            }
            if let total = store.largesTruncatedBanner {
                truncatedBanner(total: total)
            }
            Divider()
            content
            Divider()
            footer
        }
        .overlay {
            if isDragOver {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    VStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.tint)
                        Text("松开以扫描此目录")
                            .font(.title3.weight(.semibold))
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .navigationTitle("文件清理")
        .quickLookPreview($previewURL)
        .alert("确认删除", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await store.deleteSelectedLargeFiles() }
            }
        } message: {
            ConfirmMessage(selectedCount: selectedCount, selectedSize: selectedSize, store: store)
        }
        // Table 原生选中 → 同步到 store.selectedLargeFileIds（双向）
        .onChange(of: tableSelection) { _, new in
            store.selectedLargeFileIds = new
        }
        .onChange(of: store.selectedLargeFileIds) { _, new in
            if tableSelection != new { tableSelection = new }
        }
        .onAppear {
            tableSelection = store.selectedLargeFileIds
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("文件清理").font(.title2.bold())
            Text(customRoots.isEmpty ? "Downloads · Documents · Movies · Desktop" : "自定义目录")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            switch store.largeFileState {
            case .scanning:
                Button("取消扫描") { store.cancelLargeFileScan() }
                    .buttonStyle(.bordered)
            default:
                Button(store.largeFiles.isEmpty ? "开始扫描" : "重新扫描") {
                    store.scanLargeFiles(roots: customRoots.isEmpty ? nil : customRoots, filter: filter)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var customRootsBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.plus").foregroundStyle(.tint)
            Text("自定义目录:").font(.caption.weight(.medium))
            ForEach(customRoots, id: \.self) { url in
                HStack(spacing: 4) {
                    Text(url.lastPathComponent).font(.caption)
                    Button {
                        customRoots.removeAll { $0 == url }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            Spacer()
            Button("清空") { customRoots = [] }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.05))
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    if !customRoots.contains(url) {
                        customRoots.append(url)
                    }
                }
            }
        }
        return true
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("扫描模式").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Picker("", selection: $filter.mode) {
                        ForEach(FileScanMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 280)
                }

                if filter.mode == .size || filter.mode == .combined {
                    HStack(spacing: 6) {
                        Text("大小 ≥").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $filter.minSizeMB) {
                            Text("10 MB").tag(10)
                            Text("50 MB").tag(50)
                            Text("100 MB").tag(100)
                            Text("500 MB").tag(500)
                            Text("1 GB").tag(1024)
                        }
                        .pickerStyle(.menu).labelsHidden().frame(width: 100)
                    }
                }

                if filter.mode == .unused || filter.mode == .combined {
                    HStack(spacing: 6) {
                        Text("未访问 ≥").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $filter.unusedDays) {
                            Text("30 天").tag(30)
                            Text("90 天").tag(90)
                            Text("180 天").tag(180)
                            Text("365 天").tag(365)
                            Text("2 年").tag(730)
                        }
                        .pickerStyle(.menu).labelsHidden().frame(width: 100)
                    }
                }

                Spacer()
            }

            Text(filter.mode.summary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func truncatedBanner(total: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            Text("结果已截断：共扫到 \(total) 项，仅显示前 \(store.largeFiles.count) 项（按相关度排序）")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }

    @ViewBuilder
    private var content: some View {
        switch store.largeFileState {
        case .idle where store.largeFiles.isEmpty:
            ContentUnavailableView(
                "尚未扫描",
                systemImage: filter.mode == .unused ? "calendar" : "doc.zipper",
                description: Text(filter.mode.summary + "\n点击右上角「开始扫描」")
            )
            .frame(maxHeight: .infinity)
        case .scanning(let progress, let current):
            VStack(spacing: 16) {
                ProgressView(value: progress).frame(width: 320)
                Text(current.isEmpty ? "准备中..." : "扫描: \(current)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxHeight: .infinity)
        case .failed(let msg):
            ContentUnavailableView("扫描失败", systemImage: "exclamationmark.triangle", description: Text(msg))
                .frame(maxHeight: .infinity)
        default:
            Table(store.largeFiles, selection: $tableSelection) {
                TableColumn("") { row in
                    Toggle("", isOn: Binding(
                        get: { tableSelection.contains(row.id) },
                        set: { on in
                            if on { tableSelection.insert(row.id) }
                            else { tableSelection.remove(row.id) }
                        }
                    )).labelsHidden()
                }
                .width(30)
                TableColumn("预览") { row in
                    Button { previewURL = row.url } label: {
                        FileThumbnail(url: row.url, size: 36)
                    }
                    .buttonStyle(.plain)
                    .help("点击预览")
                }
                .width(50)
                TableColumn("文件名") { row in
                    Button { previewURL = row.url } label: {
                        Text(row.displayName)
                            .lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("点击预览")
                }
                TableColumn("建议") { row in
                    SuggestionBadge(suggestion: row.suggestion, compact: true)
                }
                .width(90)
                TableColumn("路径") { row in
                    Text(row.displayPath)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                TableColumn("大小") { row in
                    Text(ByteFormatter.format(row.sizeBytes)).monospacedDigit()
                }
                .width(80)
                TableColumn("修改时间") { row in
                    Text(row.modifiedAt, style: .date).font(.caption)
                }
                .width(110)
                TableColumn("操作") { row in
                    HStack(spacing: 4) {
                        Button { previewURL = row.url } label: {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.borderless)
                        .help("快速预览")
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([row.url])
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("在 Finder 中显示")
                    }
                }
                .width(70)
            }
            .onKeyPress(.space) {
                if let id = tableSelection.first,
                   let row = store.largeFiles.first(where: { $0.id == id }) {
                    previewURL = row.url
                    return .handled
                }
                return .ignored
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                let urls = store.largeFiles.filter { ids.contains($0.id) }.map { $0.url }
                if urls.count == 1, let only = urls.first {
                    Button("快速预览") { previewURL = only }
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([only])
                    }
                }
                Divider()
                Button("加入保护清单（\(urls.count) 项）") {
                    for u in urls { whitelist.add(u.path) }
                    store.largeFiles.removeAll { ids.contains($0.id) }
                    tableSelection.subtract(ids)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("已选 \(selectedCount) 项 · \(ByteFormatter.format(selectedSize))")
                .font(.subheadline).foregroundStyle(.secondary)
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
            .disabled(store.largeFiles.isEmpty)
            Button {
                showConfirm = true
            } label: {
                Label("移入废纸篓", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedCount == 0)
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding(16)
    }

    private var selectedCount: Int { tableSelection.count }
    private var selectedSize: Int64 {
        store.largeFiles.filter { tableSelection.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }
    private func setAll(_ on: Bool) {
        if on {
            tableSelection = Set(store.largeFiles.map { $0.id })
        } else {
            tableSelection = []
        }
    }
    private func selectByLevel(_ maxLevel: SuggestionLevel) {
        tableSelection = Set(
            store.largeFiles.filter { $0.suggestion.level <= maxLevel }.map { $0.id }
        )
    }
}

extension ScanStore {
    /// 截断 banner 用 — 兼容文件清理页和最近页通用
    var largesTruncatedBanner: Int? { largeFilesTruncated }
    var recentsTruncatedBanner: Int? { recentFilesTruncated }
}
