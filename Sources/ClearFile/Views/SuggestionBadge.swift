import SwiftUI

struct SuggestionBadge: View {
    let suggestion: Suggestion
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(suggestion.level.color)
                .frame(width: 6, height: 6)
            Text(suggestion.level.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(suggestion.level.color)
            if !compact {
                Text("·").foregroundStyle(.tertiary)
                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .help("\(suggestion.level.label) — \(suggestion.reason)")
    }
}
