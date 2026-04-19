import Foundation

enum AppRoute: String, CaseIterable, Identifiable, Hashable {
    case overview
    case systemJunk
    case largeFiles
    case recentFiles
    case duplicates
    case appUninstaller
    case privacy
    case schedules
    case fileSearch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:       return L10n.overview
        case .systemJunk:     return L10n.systemJunk
        case .largeFiles:     return L10n.fileClean
        case .recentFiles:    return L10n.cleanRecent
        case .duplicates:     return L10n.duplicates
        case .appUninstaller: return L10n.appUninstaller
        case .privacy:        return L10n.privacy
        case .schedules:      return L10n.schedules
        case .fileSearch:     return L10n.fileSearch
        }
    }

    var icon: String {
        switch self {
        case .overview:       return "chart.pie.fill"
        case .systemJunk:     return "trash.fill"
        case .largeFiles:     return "doc.zipper"
        case .recentFiles:    return "calendar.badge.clock"
        case .duplicates:     return "doc.on.doc.fill"
        case .appUninstaller: return "trash.square.fill"
        case .privacy:        return "eye.slash.fill"
        case .schedules:      return "clock.arrow.circlepath"
        case .fileSearch:     return "magnifyingglass.circle.fill"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selection: AppRoute = .overview
}
