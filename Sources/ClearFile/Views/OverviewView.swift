import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var history: CleanHistoryStore
    @EnvironmentObject var license: LicenseStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroSection
                breakdownChart
                modulesGrid
                if !history.records.isEmpty {
                    historyTrendCard
                }
                if let result = store.lastCleanResult {
                    lastCleanBanner(result)
                }
                Spacer(minLength: 24)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onAppear {
                if store.breakdown == nil {
                    store.computeBreakdown()
                }
            }
        }
        .background(LinearGradient(
            colors: [Color.accentColor.opacity(0.06), .clear],
            startPoint: .top, endPoint: .bottom
        ))
        .navigationTitle("概览")
    }

    // MARK: - Hero (donut + headline)

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 36) {
            donutChart
                .frame(width: 200, height: 200)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your Mac").font(.system(.largeTitle, design: .rounded, weight: .bold))
                if let usage = store.diskUsage {
                    Text("\(ByteFormatter.format(usage.usedBytes)) / \(ByteFormatter.format(usage.totalBytes))")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Divider().padding(.vertical, 4).frame(width: 240)
                    HStack(spacing: 24) {
                        statBlock(color: .accentColor, label: "已用", value: ByteFormatter.format(usage.usedBytes))
                        statBlock(color: .green, label: "可用", value: ByteFormatter.format(usage.freeBytes))
                    }
                    HStack(spacing: 10) {
                        Button {
                            store.scanAll()
                        } label: {
                            Label("扫描全部", systemImage: "sparkle.magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(store.scanAllRunning)

                        Button {
                            store.refreshDisk()
                        } label: {
                            Label("刷新磁盘", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 6)
                } else {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("正在读取磁盘…").foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var donutChart: some View {
        if let usage = store.diskUsage {
            ZStack {
                Chart {
                    SectorMark(
                        angle: .value("已用", usage.usedBytes),
                        innerRadius: .ratio(0.72),
                        angularInset: 2
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    SectorMark(
                        angle: .value("可用", usage.freeBytes),
                        innerRadius: .ratio(0.72),
                        angularInset: 2
                    )
                    .foregroundStyle(Color.green.opacity(0.5).gradient)
                }
                VStack(spacing: 2) {
                    Text("\(Int(usage.usedRatio * 100))%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("已用").font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 24)
        }
    }

    private func statBlock(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).monospacedDigit()
            }
        }
    }

    // MARK: - Breakdown Donut Chart

    @ViewBuilder
    private var breakdownChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("文件占比").font(.headline)
                if let bd = store.breakdown {
                    Text("已分类 \(ByteFormatter.format(bd.totalScannedBytes)) / 实际已用 \(ByteFormatter.format(bd.actualUsedBytes))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Image(systemName: "info.circle")
                    .font(.caption).foregroundStyle(.tertiary)
                    .help("扫描 12 个互不重叠的目录分类。符号链接、隐藏文件、APFS hard link 去重。")
                Spacer()
                if case .scanning = store.breakdownState {
                    ProgressView().scaleEffect(0.6)
                    Text("扫描中…").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button {
                        store.computeBreakdown()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("重新计算")
                }
            }

            if let breakdown = store.breakdown, !breakdown.categories.isEmpty {
                let cats = displayCategories(breakdown)
                let maxBytes = cats.map(\.bytes).max() ?? 1

                // 横向柱状图（点击可展开子目录）
                let total = cats.reduce(Int64(0)) { $0 + $1.bytes }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cats) { cat in
                        VStack(alignment: .leading, spacing: 0) {
                            barRow(cat: cat, maxBytes: maxBytes, total: total)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard cat.key != "_other" else { return }
                                    store.toggleCategoryExpand(cat.key)
                                }
                                .background(
                                    store.expandedCategoryKey == cat.key
                                        ? RoundedRectangle(cornerRadius: 4).fill(cat.color.opacity(0.08))
                                        : nil
                                )

                            // 展开的子目录明细
                            if store.expandedCategoryKey == cat.key {
                                subCategoryList(parent: cat)
                                    .padding(.leading, 26)
                                    .padding(.vertical, 6)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: store.expandedCategoryKey)

                if breakdown.otherBytes < 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("分类总和超过磁盘已用 \(ByteFormatter.format(-breakdown.otherBytes))（可能 hard link 跨目录）")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            } else if case .scanning(let progress, _) = store.breakdownState {
                VStack(spacing: 10) {
                    ProgressView(value: progress)
                        .frame(maxWidth: 400)
                    Text(store.breakdownProgress.isEmpty ? "正在计算各目录占用…" : store.breakdownProgress)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Text("点击右上角刷新计算各类别占用")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func displayCategories(_ breakdown: StorageBreakdown) -> [StorageCategory] {
        var arr = breakdown.sortedDescending
        if breakdown.otherBytes > 0 {
            arr.append(StorageCategory(
                key: "_other", name: "其他/系统",
                icon: "questionmark.folder", color: .gray,
                bytes: breakdown.otherBytes
            ))
        }
        return arr
    }

    @ViewBuilder
    private func subCategoryList(parent: StorageCategory) -> some View {
        if store.subCategoriesLoading {
            VStack(alignment: .leading, spacing: 6) {
                if store.subCategoriesTotal > 0 {
                    ProgressView(
                        value: Double(store.subCategoriesScanned),
                        total: Double(max(store.subCategoriesTotal, 1))
                    )
                    .frame(maxWidth: 300)
                } else {
                    ProgressView().scaleEffect(0.6)
                }
                Text(store.subCategoriesProgress)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 6)
        } else if store.subCategories.isEmpty {
            Text("没有显著子目录").font(.caption2).foregroundStyle(.tertiary)
                .padding(.vertical, 4)
        } else {
            let subMax = store.subCategories.map(\.bytes).max() ?? 1
            VStack(alignment: .leading, spacing: 3) {
                ForEach(store.subCategories) { sub in
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.caption2)
                            .foregroundStyle(parent.color.opacity(0.6))
                            .frame(width: 12)
                        Text(sub.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: 140, alignment: .leading)
                        GeometryReader { geo in
                            let ratio = Double(sub.bytes) / Double(max(subMax, 1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(parent.color.opacity(0.5).gradient)
                                .frame(width: max(geo.size.width * ratio, 2), height: 12)
                        }
                        .frame(height: 12)
                        Text(ByteFormatter.format(sub.bytes))
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func barRow(cat: StorageCategory, maxBytes: Int64, total: Int64) -> some View {
        let isExpanded = store.expandedCategoryKey == cat.key
        let canExpand = cat.key != "_other"
        return HStack(spacing: 10) {
            // 左：展开箭头 + 图标 + 名称
            HStack(spacing: 4) {
                if canExpand {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)
                } else {
                    Spacer().frame(width: 10)
                }
                Image(systemName: cat.icon)
                    .font(.caption)
                    .foregroundStyle(cat.color)
                    .frame(width: 16)
                Text(cat.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(width: 130, alignment: .leading)

            // 中：横向 bar
            GeometryReader { geo in
                let ratio = Double(cat.bytes) / Double(max(maxBytes, 1))
                let barWidth = max(geo.size.width * ratio, 2)
                RoundedRectangle(cornerRadius: 4)
                    .fill(cat.color.gradient)
                    .frame(width: barWidth, height: 18)
            }
            .frame(height: 18)

            // 右：大小 + 百分比
            HStack(spacing: 6) {
                Text(ByteFormatter.format(cat.bytes))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                Text(pctLabel(cat.bytes, total: total))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 110, alignment: .trailing)
        }
        .help("\(cat.name) · \(ByteFormatter.format(cat.bytes))")
    }

    private func pctLabel(_ bytes: Int64, total: Int64) -> String {
        guard total > 0, bytes > 0 else { return "0%" }
        let pct = Double(bytes) / Double(total) * 100
        if pct < 1 { return "< 1%" }
        return "\(Int(pct.rounded()))%"
    }

    // MARK: - Modules Grid

    private var modulesGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("功能模块").font(.headline).padding(.leading, 4)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                moduleCard(title: "系统垃圾", subtitle: "~/Library/Caches",
                           icon: "trash.fill", tint: .orange) {
                    router.selection = .systemJunk
                    if store.caches.isEmpty { store.scanCaches() }
                }
                moduleCard(title: "文件清理", subtitle: "大文件 / 久未使用",
                           icon: "doc.zipper", tint: .blue) {
                    router.selection = .largeFiles
                    if store.largeFiles.isEmpty { store.scanLargeFiles() }
                }
                moduleCard(title: "清理最近", subtitle: "截图 / 安装包 / 录屏",
                           icon: "calendar.badge.clock", tint: .pink) {
                    router.selection = .recentFiles
                }
                moduleCard(title: "重复文件", subtitle: "SHA256 比对去重",
                           icon: "doc.on.doc.fill", tint: .green) {
                    router.selection = .duplicates
                }
                moduleCard(title: "应用卸载", subtitle: "App + 残留扫描",
                           icon: "trash.square.fill", tint: .red) {
                    router.selection = .appUninstaller
                }
                moduleCard(title: "无痕清理", subtitle: "浏览器 / 系统 / 终端",
                           icon: "eye.slash.fill", tint: .purple) {
                    router.selection = .privacy
                }
            }
        }
    }

    private func moduleCard(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundStyle(tint).font(.body)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(tint.opacity(0.5)).font(.caption)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - History Trend

    private var historyTrendCard: some View {
        let trend = history.dailyTrend(days: 30)
        let total7 = history.bytesFreed(in: 7)
        let total30 = history.bytesFreed(in: 30)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis").foregroundStyle(.purple)
                Text("清理趋势（30 天）").font(.headline)
                Spacer()
                Text("本周 \(ByteFormatter.format(total7)) · 本月 \(ByteFormatter.format(total30))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if trend.allSatisfy({ $0.bytes == 0 }) {
                Text("还没有清理记录").font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Chart(trend, id: \.date) { item in
                    BarMark(
                        x: .value("日期", item.date, unit: .day),
                        y: .value("释放", item.bytes)
                    )
                    .foregroundStyle(Color.purple.gradient)
                    .cornerRadius(2)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .frame(height: 80)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Last Clean Banner

    private func lastCleanBanner(_ result: CleanResult) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.green.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: "checkmark")
                    .font(.callout.weight(.bold)).foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("上次清理已完成").font(.subheadline.weight(.semibold))
                Text("已移入废纸篓 \(result.movedCount) 项 · 释放 \(ByteFormatter.format(result.bytesFreed))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !result.failed.isEmpty {
                Text("\(result.failed.count) 失败")
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.red.opacity(0.15), in: Capsule())
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.green.opacity(0.25), lineWidth: 1))
        )
    }
}
