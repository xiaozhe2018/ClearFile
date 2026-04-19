import SwiftUI
import AppKit
import QuickLook

struct DuplicatesView: View {
    @EnvironmentObject var store: ScanStore
    @State private var roots: [URL] = []
    @State private var minSizeMB: Int = 5
    @State private var showConfirm = false
    @State private var previewURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            Divider()
            content
            Divider()
            footer
        }
        .navigationTitle("重复文件")
        .quickLookPreview($previewURL)
        .alert("确认删除", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("移入废纸篓", role: .destructive) {
                Task { await store.deleteSelectedDuplicates() }
            }
        } message: {
            Text("将删除 \(toDeleteCount) 个重复副本 · 释放 \(ByteFormatter.format(toDeleteSize))。每组将至少保留一个文件。")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("重复文件").font(.title2.bold())
            if !store.duplicateGroups.isEmpty {
                Text("可释放 \(ByteFormatter.format(totalWasted))")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
            Spacer()
            switch store.duplicateState {
            case .scanning:
                Button("取消扫描") { store.cancelDuplicateScan() }
                    .buttonStyle(.bordered)
            default:
                Button(store.duplicateGroups.isEmpty ? "开始扫描" : "重新扫描") {
                    let scanRoots = roots.isEmpty ? defaultRoots : roots
                    store.scanDuplicates(roots: scanRoots, minSizeMB: minSizeMB)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(roots.isEmpty && defaultRoots.isEmpty)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("扫描目录:").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ForEach(displayRoots, id: \.self) { url in
                    HStack(spacing: 4) {
                        Image(systemName: "folder").font(.caption2)
                        Text(url.lastPathComponent).font(.caption)
                        if !roots.isEmpty {
                            Button {
                                roots.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.caption2)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
                Button {
                    pickDirectory()
                } label: {
                    Label("添加目录", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            HStack {
                Text("最小文件:").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $minSizeMB) {
                    Text("1 MB").tag(1)
                    Text("5 MB").tag(5)
                    Text("10 MB").tag(10)
                    Text("50 MB").tag(50)
                    Text("100 MB").tag(100)
                }
                .pickerStyle(.menu).labelsHidden().frame(width: 100)

                if case .scanning = store.duplicateState {
                    ProgressView().scaleEffect(0.6)
                    Text(store.duplicateProgress).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var displayRoots: [URL] {
        roots.isEmpty ? defaultRoots : roots
    }

    private var defaultRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Pictures")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK {
            for url in panel.urls where !roots.contains(url) {
                roots.append(url)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.duplicateState {
        case .idle where store.duplicateGroups.isEmpty:
            ContentUnavailableView(
                "尚未扫描",
                systemImage: "doc.on.doc",
                description: Text("通过 SHA256 找出完全相同的文件\n点击右上角「开始扫描」")
            )
            .frame(maxHeight: .infinity)
        case .scanning:
            VStack(spacing: 14) {
                ProgressView().scaleEffect(1.2)
                Text(store.duplicateProgress.isEmpty ? "扫描中…" : store.duplicateProgress)
                    .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxHeight: .infinity)
        case .failed(let msg):
            ContentUnavailableView("扫描失败", systemImage: "exclamationmark.triangle", description: Text(msg))
                .frame(maxHeight: .infinity)
        case .completed where store.duplicateGroups.isEmpty:
            ContentUnavailableView(
                "未发现重复文件",
                systemImage: "checkmark.seal",
                description: Text("所选目录中没有大小 ≥ \(minSizeMB)MB 的重复文件")
            )
            .frame(maxHeight: .infinity)
        default:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(store.duplicateGroups) { group in
                        groupCard(group)
                    }
                }
                .padding(20)
            }
        }
    }

    private func groupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(group.files.count) 个相同文件")
                    .font(.subheadline.weight(.semibold))
                Text("·").foregroundStyle(.tertiary)
                Text("每个 \(ByteFormatter.format(group.sizeBytes))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("浪费 \(ByteFormatter.format(group.wastedBytes))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            ForEach(group.files) { file in
                fileRow(group: group, file: file)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func fileRow(group: DuplicateGroup, file: DuplicateFile) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { file.keep },
                set: { newKeep in
                    if let gIdx = store.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
                        for i in store.duplicateGroups[gIdx].files.indices {
                            store.duplicateGroups[gIdx].files[i].keep = false
                        }
                        if let fIdx = store.duplicateGroups[gIdx].files.firstIndex(where: { $0.id == file.id }) {
                            store.duplicateGroups[gIdx].files[fIdx].keep = newKeep
                        }
                    }
                }
            ))
            .toggleStyle(RadioToggleStyle())
            .labelsHidden()

            FileThumbnail(url: file.url, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .font(.callout)
                Text(file.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(file.modifiedAt, style: .date).font(.caption2).foregroundStyle(.secondary)
            if file.keep {
                Text("保留").font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.18)))
                    .foregroundStyle(.green)
            } else {
                Text("将删除").font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
                    .foregroundStyle(.red)
            }
            Button {
                previewURL = file.url
            } label: {
                Image(systemName: "eye")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            Text("将删除 \(toDeleteCount) 项 · \(ByteFormatter.format(toDeleteSize))")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button {
                showConfirm = true
            } label: {
                Label("移入废纸篓", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(toDeleteCount == 0)
        }
        .padding(16)
    }

    private var totalWasted: Int64 {
        store.duplicateGroups.reduce(0) { $0 + $1.wastedBytes }
    }
    private var toDeleteCount: Int {
        store.duplicateGroups.reduce(0) { $0 + $1.files.filter { !$0.keep }.count }
    }
    private var toDeleteSize: Int64 {
        store.duplicateGroups.reduce(0) { sum, g in
            sum + g.files.filter { !$0.keep }.reduce(Int64(0)) { $0 + $1.sizeBytes }
        }
    }
}

/// 单选样式（一组里只能选一个保留）
struct RadioToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(configuration.isOn ? Color.green : .secondary)
                .font(.body)
        }
        .buttonStyle(.borderless)
    }
}
