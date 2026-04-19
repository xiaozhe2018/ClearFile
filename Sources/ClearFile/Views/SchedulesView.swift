import SwiftUI
import AppKit

struct SchedulesView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @State private var editing: CleanSchedule?
    @State private var showingNew = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if scheduleStore.schedules.isEmpty {
                ContentUnavailableView(
                    "暂无定时清理任务",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("点击右上角「新建」添加自动清理规则\n例如：每周清理 Downloads 中 30 天未访问的文件")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(scheduleStore.schedules) { schedule in
                        ScheduleRow(schedule: schedule) {
                            editing = schedule
                        } onRunNow: {
                            Task { await scheduleStore.runSchedule(schedule.id) }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { scheduleStore.delete(scheduleStore.schedules[i]) }
                    }
                }
                .listStyle(.inset)
            }
            if !scheduleStore.history.isEmpty {
                Divider()
                historyFooter
            }
        }
        .navigationTitle("定时清理")
        .sheet(item: $editing) { schedule in
            ScheduleEditorView(schedule: schedule) { updated in
                scheduleStore.upsert(updated)
            }
        }
        .sheet(isPresented: $showingNew) {
            ScheduleEditorView(schedule: CleanSchedule(
                name: "",
                directoryPaths: [],
                olderThanDays: 30,
                minSizeBytes: 0,
                frequency: .weekly
            )) { newOne in
                scheduleStore.upsert(newOne)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("定时清理任务").font(.title2.bold())
            Spacer()
            if scheduleStore.isRunning {
                ProgressView().scaleEffect(0.7)
                Text("正在执行…").font(.caption).foregroundStyle(.secondary)
            }
            Button {
                showingNew = true
            } label: {
                Label("新建", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }

    private var historyFooter: some View {
        DisclosureGroup("最近运行记录") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(scheduleStore.history.prefix(5)) { rec in
                    HStack {
                        Image(systemName: rec.failedCount > 0 ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundStyle(rec.failedCount > 0 ? .orange : .green)
                        Text(rec.scheduleName).fontWeight(.medium)
                        Text("·")
                        Text("\(rec.fileCount) 项 · \(ByteFormatter.format(rec.bytesFreed))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(rec.runAt, style: .relative)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }
}

private struct ScheduleRow: View {
    let schedule: CleanSchedule
    let onEdit: () -> Void
    let onRunNow: () -> Void
    @EnvironmentObject var scheduleStore: ScheduleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: Binding(
                    get: { schedule.enabled },
                    set: { _ in scheduleStore.toggleEnabled(schedule.id) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.name).font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("立即运行", action: onRunNow)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("编辑", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            HStack(spacing: 12) {
                Label(schedule.frequency.label, systemImage: "clock")
                if schedule.olderThanDays > 0 {
                    Label("\(schedule.olderThanDays) 天未访问", systemImage: "calendar")
                }
                if schedule.minSizeBytes > 0 {
                    Label(">\(ByteFormatter.format(schedule.minSizeBytes))", systemImage: "doc")
                }
                if let last = schedule.lastRunAt {
                    Label("上次：\(last, style: .relative)前 · 释放 \(ByteFormatter.format(schedule.lastRunBytesFreed))", systemImage: "checkmark.seal")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        if schedule.directoryPaths.isEmpty { return "未设定目录" }
        let names = schedule.directoryPaths
            .map { ($0 as NSString).lastPathComponent }
            .joined(separator: " · ")
        return names
    }
}

// MARK: - Editor

struct ScheduleEditorView: View {
    @State var schedule: CleanSchedule
    let onSave: (CleanSchedule) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(schedule.name.isEmpty ? "新建定时清理" : "编辑：\(schedule.name)")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(20)
            Divider()

            Form {
                Section("基本信息") {
                    TextField("名称", text: $schedule.name, prompt: Text("如：清理下载夹旧文件"))
                    Picker("频率", selection: $schedule.frequency) {
                        ForEach(ScheduleFrequency.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    Toggle("启用", isOn: $schedule.enabled)
                }

                Section("清理目录") {
                    if schedule.directoryPaths.isEmpty {
                        Text("尚未添加目录").foregroundStyle(.secondary).font(.caption)
                    } else {
                        ForEach(schedule.directoryPaths, id: \.self) { p in
                            HStack {
                                Image(systemName: "folder")
                                Text(p.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    schedule.directoryPaths.removeAll { $0 == p }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                            .font(.caption)
                        }
                    }
                    Button {
                        pickDirectory()
                    } label: {
                        Label("添加目录", systemImage: "plus.circle")
                    }
                }

                Section("筛选条件") {
                    Stepper(
                        "清理 \(schedule.olderThanDays) 天未访问的文件",
                        value: $schedule.olderThanDays,
                        in: 0...365,
                        step: 1
                    )
                    Picker("最小文件大小", selection: $schedule.minSizeBytes) {
                        Text("不限").tag(Int64(0))
                        Text("> 1 MB").tag(Int64(1_048_576))
                        Text("> 10 MB").tag(Int64(10_485_760))
                        Text("> 50 MB").tag(Int64(52_428_800))
                        Text("> 100 MB").tag(Int64(104_857_600))
                        Text("> 500 MB").tag(Int64(524_288_000))
                    }
                }

                Section {
                    Text("⚠️ 命中保护规则的文件（敏感目录、iCloud、密钥、.git 等）会被自动跳过，不会被删除。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("保存") {
                    onSave(schedule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(schedule.name.isEmpty || schedule.directoryPaths.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 540, height: 600)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK {
            for url in panel.urls where !schedule.directoryPaths.contains(url.path) {
                schedule.directoryPaths.append(url.path)
            }
        }
    }
}
