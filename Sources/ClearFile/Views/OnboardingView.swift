import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var hasFDA: Bool = PermissionsHelper.hasFullDiskAccess()

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            footer
        }
        .frame(width: 560, height: 480)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomePage
        case 1: featurePage
        case 2: permissionPage
        default: EmptyView()
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.gradient).frame(width: 96, height: 96)
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            Text("欢迎使用 ClearFile")
                .font(.title.bold())
            Text("一款保守、可恢复的 Mac 磁盘清理工具")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("所有清理都走废纸篓 · 30 天内可恢复 · 敏感目录永远不动")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(40)
    }

    private var featurePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("功能速览").font(.title2.bold())
            featureRow(icon: "wand.and.sparkles", color: .accentColor,
                       title: "一键安全清理",
                       desc: "扫描缓存 + 大文件，自动只勾选「绿色 · 安全」等级")
            featureRow(icon: "calendar.badge.clock", color: .pink,
                       title: "清理最近",
                       desc: "找出近期截图、安装包、压缩包，用完即清")
            featureRow(icon: "clock.arrow.circlepath", color: .purple,
                       title: "定时清理",
                       desc: "自动按规则清理 Downloads / 桌面 / 任意目录")
            featureRow(icon: "shield.lefthalf.filled", color: .green,
                       title: "保护清单",
                       desc: "右键加入永久白名单，下次扫描自动跳过")
            featureRow(icon: "arrow.uturn.backward.circle.fill", color: .blue,
                       title: "30 秒撤销",
                       desc: "刚清理的可一键恢复（从废纸篓搬回原位）")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var permissionPage: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color.green.opacity(0.18)).frame(width: 80, height: 80)
                Image(systemName: hasFDA ? "checkmark.shield.fill" : "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            }
            Text(hasFDA ? "✅ 已获得完整磁盘访问" : "建议授予完整磁盘访问")
                .font(.title2.bold())
            Text("只有授权后，ClearFile 才能扫描 ~/Library/Mail、Containers 等系统保护目录中的缓存。\n你可以稍后随时在系统设置中开启。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !hasFDA {
                Button {
                    PermissionsHelper.openFullDiskAccessSettings()
                } label: {
                    Label("打开系统设置", systemImage: "gearshape")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Spacer()
        }
        .padding(40)
        .onAppear {
            hasFDA = PermissionsHelper.hasFullDiskAccess()
        }
    }

    private var footer: some View {
        HStack {
            Button("跳过") { complete() }
                .buttonStyle(.borderless)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            Button(step < 2 ? "下一步" : "开始使用") {
                if step < 2 { step += 1 } else { complete() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "ClearFile.onboardingDone")
        dismiss()
    }
}
