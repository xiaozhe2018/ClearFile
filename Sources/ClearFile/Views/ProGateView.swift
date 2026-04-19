import SwiftUI

/// Pro 功能门控视图。包裹在功能页面外层，未解锁时覆盖"升级 Pro"遮罩。
struct ProGateView<Content: View>: View {
    let feature: ProFeature
    @ViewBuilder let content: () -> Content
    @EnvironmentObject var license: LicenseStore
    @State private var showActivation = false

    var body: some View {
        if license.isUnlocked(feature) {
            content()
        } else {
            ZStack {
                content()
                    .blur(radius: 6)
                    .allowsHitTesting(false)

                lockOverlay
            }
            .sheet(isPresented: $showActivation) {
                ActivationView()
            }
        }
    }

    private var lockOverlay: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.accentColor.gradient).frame(width: 72, height: 72)
                Image(systemName: "lock.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
            Text("\(feature.displayName) \(L10n.proFeature)")
                .font(.title2.weight(.bold))
            Text(L10n.unlockAll)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showActivation = true
            } label: {
                Label("\(L10n.upgradePro) · $4.99", systemImage: "crown.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(L10n.enterLicenseKey) {
                showActivation = true
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

/// 激活 / 购买页面
struct ActivationView: View {
    @EnvironmentObject var license: LicenseStore
    @Environment(\.dismiss) private var dismiss
    @State private var inputKey: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 480, height: 420)
    }

    private var header: some View {
        HStack {
            Text("激活 ClearFile Pro").font(.title3.bold())
            Spacer()
        }
        .padding(20)
    }

    private var content: some View {
        VStack(spacing: 20) {
            // Pro 功能列表
            VStack(alignment: .leading, spacing: 10) {
                Text("Pro 包含").font(.headline)
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(ProFeature.allCases, id: \.rawValue) { f in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(f.displayName).font(.caption)
                            Spacer()
                        }
                    }
                }
            }

            Divider()

            // 输入密钥
            VStack(alignment: .leading, spacing: 8) {
                Text("输入许可证密钥").font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    TextField("CF-XXXX-XXXX-XXXX", text: $inputKey)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await license.activate(key: inputKey) }
                    } label: {
                        Text("激活").frame(width: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputKey.isEmpty || license.isActivating)
                }
                if license.isActivating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.5)
                        Text("验证中…").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let err = license.activationError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                if license.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("已激活 Pro").font(.callout.weight(.semibold)).foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            // 购买链接
            HStack {
                Text("还没有密钥？").font(.caption).foregroundStyle(.secondary)
                Link("购买 ClearFile Pro →", destination: URL(string: "https://clearfile.app")!)
                    .font(.caption)
            }
        }
        .padding(20)
    }

    private var footer: some View {
        HStack {
            if license.isPro {
                Button("取消激活", role: .destructive) {
                    license.deactivate()
                }
                .font(.caption)
            }
            Spacer()
            Button(license.isPro ? "完成" : "稍后再说") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }
}
