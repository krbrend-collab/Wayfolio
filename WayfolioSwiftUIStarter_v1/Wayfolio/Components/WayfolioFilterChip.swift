import SwiftUI

struct WayfolioFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WayfolioTypography.caption)
                .foregroundStyle(selected ? WayfolioPalette.midnight : WayfolioPalette.parchment)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? WayfolioPalette.cyan.opacity(0.88) : WayfolioPalette.navyRaised)
                )
                .overlay(Capsule().stroke(selected ? WayfolioPalette.cyan : WayfolioPalette.brass.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
