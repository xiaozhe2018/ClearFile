import SwiftUI
import AppKit

struct AppUninstallerView: View {
    @EnvironmentObject var store: ScanStore
    @State private var selectedAppId: String?
    @State private var includeResidualURLs: Set<URL> = []
    @State private var loadingResiduals = false
    @State private var showConfirm = false
    @State private var search: String = ""

    var filteredApps: [InstalledApp] {
        guard !search.isEmpty else { return store.apps }
        return store.apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var selectedApp: InstalledApp? {
        store.apps.first { $0.id == selectedAppId }
    }

    var body: some View {
        HStack(spacing: 0) {
            appList
                .frame(width: 320)
            Divider()
            detailPane
                .frame(maxWidth: .infinity)
        }
        .navigationTitle("应用卸载")
        .alert("确认卸载", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("卸载并清除残留", role: .destructive) {
                if let app = selectedApp {
                    let chosen = (store.selectedAppResiduals[app.bundleURL] ?? [])
                        .filter { includeResidualURLs.contains($0.url) }
                    Task {
                        await store.uninstallApp(app, includeResiduals: chosen)
                        selectedAppId = nil
                    }
                }
            }
        } message: {
            if let app = selectedApp {
                Text("将卸载 \(app.name) (\(ByteFormatter.format(app.appBytes))) + \(includeResidualURLs.count) 项残留")
            }
        }
        .onAppear {
            if store.apps.isEmpty { store.loadApps() }
        }
    }

    // MARK: - Left: App list

    private var appList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("已安装应用").font(.headline)
                Spacer()
                if case .scanning = store.appsState {
                    ProgressView().scaleEffect(0.6)
                }
                Button {
                    store.loadApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重新扫描")
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索应用…", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            HStack {
                Text("\(filteredApps.count) 个应用 · 共 \(ByteFormatter.format(filteredApps.reduce(0) { $0 + $1.appBytes }))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.bottom, 6)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedAppId == app.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectApp(app)
                            }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 4) {
                    if let v = app.version {
                        Text("v\(v)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Text("·").foregroundStyle(.tertiary)
                    Text(ByteFormatter.format(app.appBytes))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
    }

    private func selectApp(_ app: InstalledApp) {
        selectedAppId = app.id
        includeResidualURLs = []
        loadingResiduals = true
        Task {
            await store.loadResiduals(for: app)
            let residuals = store.selectedAppResiduals[app.bundleURL] ?? []
            includeResidualURLs = Set(residuals.map { $0.url })
            loadingResiduals = false
        }
    }

    // MARK: - Right: Detail

    @ViewBuilder
    private var detailPane: some View {
        if let app = selectedApp {
            VStack(alignment: .leading, spacing: 0) {
                appHeader(app)
                Divider()
                residualsSection(app)
                Divider()
                actionFooter(app)
            }
        } else {
            VStack(spacing: 14) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("选择一个应用").font(.title2.weight(.semibold))
                Text("点击左侧列表中的应用 → 自动扫描 ~/Library 中的关联残留 → 一键卸载")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func appHeader(_ app: InstalledApp) -> some View {
        HStack(spacing: 18) {
            Image(nsImage: app.icon)
                .resizable().frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(app.name).font(.title.weight(.bold))
                    if let v = app.version {
                        Text("v\(v)").font(.title3).foregroundStyle(.secondary)
                    }
                }
                if let bid = app.bundleId {
                    Text(bid).font(.callout.monospaced()).foregroundStyle(.secondary)
                }
                HStack(spacing: 14) {
                    Label(ByteFormatter.format(app.appBytes), systemImage: "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
                    } label: {
                        Label("在 Finder 中显示", systemImage: "magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28).padding(.vertical, 20)
    }

    private func residualsSection(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.purple)
                Text("残留文件扫描").font(.headline)
                Spacer()
                if loadingResiduals {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("扫描 ~/Library …").font(.caption).foregroundStyle(.secondary)
                    }
                } else if let res = store.selectedAppResiduals[app.bundleURL] {
                    let totalBytes = res.reduce(Int64(0)) { $0 + $1.bytes }
                    Text("\(res.count) 项 · \(ByteFormatter.format(totalBytes))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if !res.isEmpty {
                        Button {
                            includeResidualURLs = Set(res.map { $0.url })
                        } label: {
                            Text("全选").font(.caption)
                        }
                        .buttonStyle(.borderless)
                        Button {
                            includeResidualURLs = []
                        } label: {
                            Text("全不选").font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.horizontal, 28).padding(.top, 16).padding(.bottom, 10)

            if loadingResiduals {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                let residuals = store.selectedAppResiduals[app.bundleURL] ?? []
                if residuals.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle").foregroundStyle(.green)
                        Text("✨ 没找到残留文件").font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(residuals) { r in
                                residualRow(r)
                            }
                        }
                        .padding(.horizontal, 28).padding(.bottom, 12)
                    }
                }
            }
        }
    }

    private func residualRow(_ r: AppResidual) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { includeResidualURLs.contains(r.url) },
                set: { on in
                    if on { includeResidualURLs.insert(r.url) }
                    else { includeResidualURLs.remove(r.url) }
                }
            )).labelsHidden()

            Text(r.category)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(categoryColor(r.category).opacity(0.15)))
                .foregroundStyle(categoryColor(r.category))
                .frame(width: 110, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(r.url.lastPathComponent).font(.callout)
                    .lineLimit(1).truncationMode(.middle)
                Text(r.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormatter.format(r.bytes))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([r.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Application Support": return .blue
        case "Caches":               return .orange
        case "Preferences":          return .purple
        case "Logs":                 return .gray
        case "Containers":           return .pink
        case "Group Containers":     return .indigo
        default:                     return .secondary
        }
    }

    private func actionFooter(_ app: InstalledApp) -> some View {
        let chosenBytes = (store.selectedAppResiduals[app.bundleURL] ?? [])
            .filter { includeResidualURLs.contains($0.url) }
            .reduce(Int64(0)) { $0 + $1.bytes }
        let totalBytes = app.appBytes + chosenBytes
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("总计释放 \(ByteFormatter.format(totalBytes))")
                    .font(.headline)
                Text("应用 \(ByteFormatter.format(app.appBytes)) + 残留 \(ByteFormatter.format(chosenBytes))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showConfirm = true
            } label: {
                Label("卸载 \(app.name)", systemImage: "trash.fill")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
        }
        .padding(.horizontal, 28).padding(.vertical, 14)
    }
}
