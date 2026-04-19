import SwiftUI

struct RootView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var store: ScanStore
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "ClearFile.onboardingDone")
    @State private var showScanAll = false

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack(alignment: .top) {
                Group {
                    switch router.selection {
                    case .overview:       OverviewView()
                    case .systemJunk:     SystemJunkView()
                    case .largeFiles:     LargeFilesView()
                    case .recentFiles:    RecentFilesView()
                    case .duplicates:
                        ProGateView(feature: .duplicateDetection) { DuplicatesView() }
                    case .appUninstaller:
                        ProGateView(feature: .appUninstaller) { AppUninstallerView() }
                    case .privacy:
                        ProGateView(feature: .privacyClean) { PrivacyView() }
                    case .schedules:
                        ProGateView(feature: .scheduledClean) { SchedulesView() }
                    case .fileSearch:     FileSearchView()
                    }
                }
                UndoBanner()
            }
        }
        .onAppear {
            store.refreshDisk()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        // Cmd+1~8 切换侧边栏
        .background {
            ForEach(Array(AppRoute.allCases.enumerated()), id: \.element) { idx, route in
                Button("") { router.selection = route }
                    .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                    .hidden()
            }
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var errorCenter: ErrorCenter
    @EnvironmentObject var store: ScanStore
    @EnvironmentObject var license: LicenseStore
    @State private var showWhitelist = false
    @State private var showErrors = false
    @State private var showActivation = false

    var body: some View {
        VStack(spacing: 0) {
            List(AppRoute.allCases, selection: $router.selection) { route in
                NavigationLink(value: route) {
                    HStack {
                        Label(route.title, systemImage: route.icon)
                        Spacer()
                        if let badge = badgeText(for: route) {
                            Text(badge)
                                .font(.caption2.weight(.medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            if let daysLeft = license.trialDaysLeft {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill").foregroundStyle(.green)
                        Text("Pro 试用中").font(.caption.weight(.semibold))
                        Spacer()
                        Text("剩余 \(daysLeft) 天")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    ProgressView(value: Double(license.trialDays - daysLeft), total: Double(license.trialDays))
                        .tint(.green)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
                .padding(.horizontal, 8).padding(.top, 6)
            } else if !license.isPro {
                Button {
                    showActivation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text(L10n.upgradePro)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("¥9.9")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8).padding(.top, 6)
            }

            Divider()
            HStack(spacing: 8) {
                Button {
                    showWhitelist = true
                } label: {
                    Label("保护清单", systemImage: "shield.lefthalf.filled")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    showErrors = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: errorCenter.unresolvedCount > 0
                              ? "exclamationmark.triangle.fill"
                              : "checkmark.shield")
                        if errorCenter.unresolvedCount > 0 {
                            Text("\(errorCenter.unresolvedCount)")
                                .font(.caption2.bold())
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(errorCenter.unresolvedCount > 0 ? Color.red : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("错误中心")
            }
            .padding(8)
        }
        .navigationTitle("ClearFile")
        .sheet(isPresented: $showWhitelist) { WhitelistSheet() }
        .sheet(isPresented: $showErrors) { ErrorCenterSheet() }
        .sheet(isPresented: $showActivation) { ActivationView() }
    }

    private func badgeText(for route: AppRoute) -> String? {
        switch route {
        case .systemJunk:
            let total = store.caches.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return total > 0 ? ByteFormatter.format(total) : nil
        case .largeFiles:
            let total = store.largeFiles.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return total > 0 ? ByteFormatter.format(total) : nil
        case .recentFiles:
            let total = store.recentFiles.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return total > 0 ? ByteFormatter.format(total) : nil
        case .duplicates:
            let total = store.duplicateGroups.reduce(Int64(0)) { $0 + $1.wastedBytes }
            return total > 0 ? ByteFormatter.format(total) : nil
        case .appUninstaller:
            return store.apps.isEmpty ? nil : "\(store.apps.count)"
        case .privacy:
            let total = store.privacyTraces.reduce(Int64(0)) { $0 + $1.sizeBytes }
            return total > 0 ? ByteFormatter.format(total) : nil
        default: return nil
        }
    }
}
