import SwiftUI
import QuickLook

private enum SearchScope: String, CaseIterable, Identifiable {
    case home      = "主目录"
    case downloads = "下载"
    case documents = "文稿"
    case desktop   = "桌面"

    var id: String { rawValue }

    var scopes: [Any] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .home:      return [NSMetadataQueryUserHomeScope as NSString]
        case .downloads: return [home.appendingPathComponent("Downloads")]
        case .documents: return [home.appendingPathComponent("Documents")]
        case .desktop:   return [home.appendingPathComponent("Desktop")]
        }
    }
}

struct FileSearchView: View {
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var whitelist: WhitelistStore

    @State private var query = ""
    @State private var scope: SearchScope = .home
    @State private var tableSelection = Set<UUID>()
    @State private var previewURL: URL?
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .navigationTitle("搜索删除")
        .quickLookPreview($previewURL)
        .alert("确认删除", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await store.deleteSelectedSearchFiles() }
            }
        } message: {
            Text("将 \(tableSelection.count) 个文件移入废纸篓，可从废纸篓恢复。")
        }
        .onChange(of: tableSelection) { _, new in
            store.selectedSearchIds = new
        }
        .onChange(of: store.selectedSearchIds) { _, new in
            if tableSelection != new { tableSelection = new }
        }
        .onDisappear {
            store.cancelFileSearch()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("搜索删除").font(.title2.bold())
                Spacer()
                if case .scanning = store.searchState {
                    Button("取消") { store.cancelFileSearch() }
                        .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("输入文件名关键字，回车搜索", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { triggerSearch() }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            store.cancelFileSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))

                Picker("范围", selection: $scope) {
                    ForEach(SearchScope.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)

                Button("搜索") { triggerSearch() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch store.searchState {
        case .idle:
            ContentUnavailableView(
                "搜索文件",
                systemImage: "magnifyingglass.circle",
                description: Text("输入文件名关键字，支持通配符。\n搜索范围可选主目录、下载、文稿或桌面。")
            )
            .frame(maxHeight: .infinity)

        case .scanning:
            VStack(spacing: 16) {
                ProgressView()
                Text("正在搜索 Spotlight 索引…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxHeight: .infinity)

        case .completed where store.searchResults.isEmpty:
            ContentUnavailableView(
                "未找到结果",
                systemImage: "doc.text.magnifyingglass",
                description: Text("没有匹配 \"\(query)\" 的文件，请尝试其他关键字或扩大搜索范围。")
            )
            .frame(maxHeight: .infinity)

        default:
            resultsTable
        }
    }

    private var resultsTable: some View {
        Table(store.searchResults, selection: $tableSelection) {
            TableColumn("") { row in
                Toggle("", isOn: Binding(
                    get: { tableSelection.contains(row.id) },
                    set: { on in
                        if on { tableSelection.insert(row.id) }
                        else  { tableSelection.remove(row.id) }
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
                    .help("快速预览 (空格)")

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([row.url])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("在 Finder 中显示")

                    Button {
                        NSWorkspace.shared.open(row.url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help("打开文件")
                }
            }
            .width(90)
        }
        .onKeyPress(.space) {
            if let id = tableSelection.first,
               let row = store.searchResults.first(where: { $0.id == id }) {
                previewURL = row.url
                return .handled
            }
            return .ignored
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            let urls = store.searchResults.filter { ids.contains($0.id) }.map { $0.url }
            if urls.count == 1, let only = urls.first {
                Button("快速预览") { previewURL = only }
                Button("打开文件") { NSWorkspace.shared.open(only) }
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([only])
                }
                Divider()
            }
            Button("加入保护清单（\(urls.count) 项）") {
                for u in urls { whitelist.add(u.path) }
                store.searchResults.removeAll { ids.contains($0.id) }
                tableSelection.subtract(ids)
            }
            Divider()
            Button("移入废纸篓（\(ids.count) 项）", role: .destructive) {
                store.selectedSearchIds = ids
                tableSelection = ids
                showConfirm = true
            }
        }
    }

    private var footer: some View {
        HStack {
            Group {
                if case .completed = store.searchState {
                    Text("共 \(store.searchResults.count) 项")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("已选 \(tableSelection.count) 项 · \(ByteFormatter.format(selectedSize))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                if tableSelection.count == store.searchResults.count {
                    tableSelection = []
                } else {
                    tableSelection = Set(store.searchResults.map { $0.id })
                }
            } label: {
                Text(tableSelection.count == store.searchResults.count ? "全不选" : "全选")
            }
            .buttonStyle(.borderless)
            .disabled(store.searchResults.isEmpty)

            Button {
                showConfirm = true
            } label: {
                Label("移入废纸篓", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(tableSelection.isEmpty)
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding(16)
    }

    private var selectedSize: Int64 {
        store.searchResults
            .filter { tableSelection.contains($0.id) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    private func triggerSearch() {
        store.searchFiles(query: query, scopes: scope.scopes)
    }
}
