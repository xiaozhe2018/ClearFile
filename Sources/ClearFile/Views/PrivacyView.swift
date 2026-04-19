import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject var store: ScanStore
    @State private var showConfirm = false

    private var grouped: [(PrivacyCategory, [PrivacyTrace])] {
        let dict = Dictionary(grouping: store.privacyTraces) { $0.category }
        return PrivacyCategory.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            warningBar
            content
            Divider()
            footer
        }
        .navigationTitle("无痕清理")
        .alert("确认清理隐私痕迹", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("清理", role: .destructive) {
                Task { await store.cleanSelectedPrivacy() }
            }
        } message: {
            let highRisk = store.privacyTraces
                .filter { store.selectedPrivacyIds.contains($0.id) && $0.risk == .high }
            if !highRisk.isEmpty {
                Text("⚠️ 你选中了 \(highRisk.count) 项高风险项目（如 Cookies / 表单填充），清理后可能需要重新登录网站。\n\n文件移入废纸篓，30 天内可恢复。")
            } else {
                Text("已选 \(selectedCount) 项，文件移入废纸篓，可恢复。")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("无痕清理").font(.title2.bold())
            Image(systemName: "eye.slash.fill").foregroundStyle(.purple)
            Spacer()
            switch store.privacyState {
            case .scanning:
                ProgressView().scaleEffect(0.6)
                Text("扫描中…").font(.caption).foregroundStyle(.secondary)
            default:
                Button(store.privacyTraces.isEmpty ? "开始扫描" : "重新扫描") {
                    store.scanPrivacy()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(20)
    }

    private var warningBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            Text("建议清理前关闭浏览器，否则数据库可能被锁定导致失败。Cookies 清理后需重新登录网站。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.orange.opacity(0.06))
    }

    @ViewBuilder
    private var content: some View {
        switch store.privacyState {
        case .idle where store.privacyTraces.isEmpty:
            ContentUnavailableView(
                "尚未扫描",
                systemImage: "eye.slash",
                description: Text("扫描浏览器历史、Cookies、最近文档、终端命令记录等隐私痕迹")
            )
            .frame(maxHeight: .infinity)
        case .scanning:
            VStack(spacing: 14) {
                ProgressView().scaleEffect(1.2)
                Text("扫描浏览器和系统隐私数据…")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxHeight: .infinity)
        case .completed where store.privacyTraces.isEmpty:
            ContentUnavailableView(
                "没有发现隐私痕迹",
                systemImage: "checkmark.shield",
                description: Text("你的 Mac 很干净")
            )
            .frame(maxHeight: .infinity)
        default:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(grouped, id: \.0) { (category, traces) in
                        categorySection(category: category, traces: traces)
                    }
                }
                .padding(20)
            }
        }
    }

    private func categorySection(category: PrivacyCategory, traces: [PrivacyTrace]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(category.color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                }
                Text(category.rawValue).font(.headline)
                Text("·").foregroundStyle(.tertiary)
                Text(ByteFormatter.format(traces.reduce(0) { $0 + $1.sizeBytes }))
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button {
                    let ids = Set(traces.map { $0.id })
                    if ids.isSubset(of: store.selectedPrivacyIds) {
                        store.selectedPrivacyIds.subtract(ids)
                    } else {
                        store.selectedPrivacyIds.formUnion(ids)
                    }
                } label: {
                    let allSelected = traces.allSatisfy { store.selectedPrivacyIds.contains($0.id) }
                    Text(allSelected ? "取消全选" : "全选").font(.caption)
                }
                .buttonStyle(.borderless)
            }

            ForEach(traces) { trace in
                traceRow(trace)
            }
        }
    }

    private func traceRow(_ trace: PrivacyTrace) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { store.selectedPrivacyIds.contains(trace.id) },
                set: { on in
                    if on { store.selectedPrivacyIds.insert(trace.id) }
                    else { store.selectedPrivacyIds.remove(trace.id) }
                }
            )).labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(trace.name).font(.body.weight(.medium))
                    riskBadge(trace.risk)
                }
                Text(trace.description)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(trace.sizeBytes > 0 ? ByteFormatter.format(trace.sizeBytes) : "—")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func riskBadge(_ risk: PrivacyRisk) -> some View {
        Text(risk.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(risk.color.opacity(0.15)))
            .foregroundStyle(risk.color)
    }

    private var footer: some View {
        HStack {
            Text("已选 \(selectedCount) 项 · \(ByteFormatter.format(selectedSize))")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("仅低风险") { selectByRisk(.low) }
                Button("低 + 中风险") { selectByRisk(.medium) }
                Button("全部（含高风险）") { selectAll() }
                Button("全不选") { store.selectedPrivacyIds = [] }
            } label: {
                Label("智能选择", systemImage: "wand.and.stars")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.privacyTraces.isEmpty)
            Button {
                showConfirm = true
            } label: {
                Label("清理选中", systemImage: "eye.slash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedCount == 0)
            .keyboardShortcut(.delete, modifiers: [])
        }
        .padding(16)
    }

    private var selectedCount: Int { store.selectedPrivacyIds.count }
    private var selectedSize: Int64 {
        store.privacyTraces
            .filter { store.selectedPrivacyIds.contains($0.id) }
            .reduce(0) { $0 + $1.sizeBytes }
    }
    private func selectByRisk(_ maxRisk: PrivacyRisk) {
        let allowed: Set<String> = {
            switch maxRisk {
            case .low:    return Set(store.privacyTraces.filter { $0.risk == .low }.map { $0.id })
            case .medium: return Set(store.privacyTraces.filter { $0.risk != .high }.map { $0.id })
            case .high:   return Set(store.privacyTraces.map { $0.id })
            }
        }()
        store.selectedPrivacyIds = allowed
    }
    private func selectAll() {
        store.selectedPrivacyIds = Set(store.privacyTraces.map { $0.id })
    }
}
