import SwiftUI
import AppKit

struct WhitelistSheet: View {
    @EnvironmentObject var whitelist: WhitelistStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("保护清单").font(.title3.bold())
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            Divider()

            if whitelist.entries.isEmpty {
                ContentUnavailableView(
                    "暂无保护项",
                    systemImage: "shield",
                    description: Text("在扫描结果列表右键 → \"加入保护清单\" 以永久跳过这些路径")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(whitelist.entries, id: \.self) { p in
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundStyle(.green)
                            Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button {
                                whitelist.remove(p)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Divider()
            HStack {
                Button {
                    pickAndAdd()
                } label: {
                    Label("添加目录…", systemImage: "plus")
                }
                Spacer()
                if !whitelist.entries.isEmpty {
                    Text("\(whitelist.entries.count) 项受保护")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .frame(width: 540, height: 480)
    }

    private func pickAndAdd() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK {
            for url in panel.urls {
                whitelist.add(url.path)
            }
        }
    }
}
