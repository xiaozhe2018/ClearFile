import SwiftUI
import AppKit

struct ErrorCenterSheet: View {
    @EnvironmentObject var errorCenter: ErrorCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("失败记录").font(.title3.bold())
                if errorCenter.unresolvedCount > 0 {
                    Text("\(errorCenter.unresolvedCount)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button("清空", role: .destructive) {
                    errorCenter.clear()
                }
                .disabled(errorCenter.failures.isEmpty)
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            Divider()

            if errorCenter.failures.isEmpty {
                ContentUnavailableView(
                    "没有失败记录",
                    systemImage: "checkmark.shield",
                    description: Text("所有清理操作都成功执行")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(errorCenter.failures) { f in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(.red)
                            Text(f.url.lastPathComponent).font(.body.weight(.semibold))
                            Spacer()
                            Text(f.occurredAt, style: .relative)
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        Text(f.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Text(f.reason).font(.caption).foregroundStyle(.red)
                        HStack {
                            Button("在 Finder 中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([f.url])
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 600, height: 480)
    }
}
