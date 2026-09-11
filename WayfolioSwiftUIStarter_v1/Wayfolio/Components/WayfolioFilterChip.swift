import SwiftUI

struct WayfolioFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(selected ? WayfolioPalette.brassBright : WayfolioPalette.brass.opacity(0.42))
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(WayfolioTypography.caption)
            }
            .foregroundStyle(selected ? WayfolioPalette.cyan : WayfolioPalette.parchment.opacity(0.82))
            .padding(.horizontal, 13)
            .frame(minHeight: 40)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Capsule().fill(WayfolioPalette.navy.opacity(selected ? 0.44 : 0.25)))
            .overlay(Capsule().stroke(selected ? WayfolioPalette.cyan : WayfolioPalette.brass.opacity(0.55), lineWidth: selected ? 1.4 : 1))
            .shadow(color: selected ? WayfolioPalette.cyan.opacity(0.28) : .clear, radius: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Filters the visible records")
    }
}
