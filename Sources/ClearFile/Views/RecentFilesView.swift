import SwiftUI
import QuickLook

struct RecentFilesView: View {
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var whitelist: WhitelistStore
    @State private var filter = RecentFileFilter()
    @State private var showConfirm = false
    @State private var previewURL: URL?
    @State private var tableSelection = Set<UUID>()

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            if let total = store.recentsTruncatedBanner {
                truncatedBanner(total: total)
            }
            Divider()
            content
            Divider()
            footer
        }
        .navigationTitle("清理最近")
        .quickLookPreview($previewURL)
        .alert("确认删除", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await store.deleteSelectedRecentFiles() }
            }
        } message: {
            ConfirmMessage(selectedCount: selectedCount, selectedSize: selectedSize, store: store)
        }
        .onChange(of: tableSelection) { _, new in
            store.selectedRecentFileIds = new
        }
        .onChange(of: store.selectedRecentFileIds) { _, new in
            if tableSelection != new { tableSelection = new }
        }
        .onAppear {
            tableSelection = store.selectedRecentFileIds
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("清理最近").font(.title2.bold())
            Text("清理近期产生的临时文件 · 截图 / 安装包 / 录屏 / 下载")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            switch store.recentFileState {
            case .scanning:
                Button("取消扫描") { store.cancelRecentFileScan() }
                    .buttonStyle(.bordered)
            default:
                Button(store.recentFiles.isEmpty ? "开始扫描" : "重新扫描") {
                    store.scanRecentFiles(filter: filter)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecentCategory.allCases) { cat in
                        categoryChip(cat)
                    }
                }
            }
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("时间范围").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Picker("", selection: $filter.withinDays) {
                        ForEach(RecentFileFilter.dayOptions, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 460)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func categoryChip(_ cat: RecentCategory) -> some View {
        let selected = filter.category == cat
        return Button {
            filter.category = cat
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon).font(.caption)
                Text(cat.label).font(.callout)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(selected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func truncatedBanner(total: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            Text("结果已截断：共扫到 \(total) 项，仅显示前 \(store.recentFiles.count) 项（按时间排序）")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }

    @ViewBuilder
    private var content: some View {
        switch store.recentFileState {
        case .idle where store.recentFiles.isEmpty:
            ContentUnavailableView(
                "尚未扫描",
                systemImage: filter.category.icon,
                description: Text("将扫描「\(filter.category.label)」中过去 \(displayDays) 创建/修改/访问过的文件")
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
        case .completed where store.recentFiles.isEmpty:
            ContentUnavailableView(
                "没有发现匹配文件",
                systemImage: "checkmark.circle",
                description: Text("「\(filter.category.label)」类别下，过去 \(displayDays)没有文件")
            )
            .frame(maxHeight: .infinity)
        default:
            Table(store.recentFiles, selection: $tableSelection) {
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
                .width(95)
                TableColumn("位置") { row in
                    Text(row.displayPath)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                TableColumn("大小") { row in
                    Text(ByteFormatter.format(row.sizeBytes)).monospacedDigit()
                }
                .width(80)
                TableColumn("时间") { row in
                    Text(row.modifiedAt, style: .relative).font(.caption)
                }
                .width(100)
                TableColumn("操作") { row in
                    HStack(spacing: 4) {
                        Button { previewURL = row.url } label: { Image(systemName: "eye") }
                            .buttonStyle(.borderless).help("快速预览")
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([row.url])
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.borderless).help("在 Finder 中显示")
                    }
                }
                .width(70)
            }
            .onKeyPress(.space) {
                if let id = tableSelection.first,
                   let row = store.recentFiles.first(where: { $0.id == id }) {
                    previewURL = row.url
                    return .handled
                }
                return .ignored
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                let urls = store.recentFiles.filter { ids.contains($0.id) }.map { $0.url }
                if urls.count == 1, let only = urls.first {
                    Button("快速预览") { previewURL = only }
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([only])
                    }
                }
                Divider()
                Button("加入保护清单（\(urls.count) 项）") {
                    for u in urls { whitelist.add(u.path) }
                    store.recentFiles.removeAll { ids.contains($0.id) }
                    tableSelection.subtract(ids)
                }
            }
        }
    }

    private var displayDays: String {
        RecentFileFilter.dayOptions.first { $0.value == filter.withinDays }?.label
            ?? "近 \(filter.withinDays) 天"
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
            .disabled(store.recentFiles.isEmpty)
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
        store.recentFiles.filter { tableSelection.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }
    private func setAll(_ on: Bool) {
        if on { tableSelection = Set(store.recentFiles.map { $0.id }) }
        else { tableSelection = [] }
    }
    private func selectByLevel(_ maxLevel: SuggestionLevel) {
        tableSelection = Set(
            store.recentFiles.filter { $0.suggestion.level <= maxLevel }.map { $0.id }
        )
    }
}
