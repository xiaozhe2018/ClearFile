import Foundation
import SwiftUI

struct CleanFailure: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let reason: String
    let occurredAt: Date

    static func == (lhs: CleanFailure, rhs: CleanFailure) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class ErrorCenter: ObservableObject {
    @Published var failures: [CleanFailure] = []

    func record(_ failed: [(URL, Error)]) {
        let now = Date()
        let new = failed.map { CleanFailure(url: $0.0, reason: $0.1.localizedDescription, occurredAt: now) }
        failures.insert(contentsOf: new, at: 0)
        // 上限
        if failures.count > 200 {
            failures = Array(failures.prefix(200))
        }
    }

    func clear() { failures = [] }

    var unresolvedCount: Int { failures.count }
}
