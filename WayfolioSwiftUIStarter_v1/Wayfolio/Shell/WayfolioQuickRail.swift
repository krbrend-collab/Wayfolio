import SwiftUI

struct WayfolioQuickRail: View {
    private let actions: [(String, String)] = [
        ("sparkles", "Discoveries"),
        ("pawprint.fill", "Creatures"),
        ("leaf.fill", "Botanicals"),
        ("flask.fill", "Alchemy"),
        ("gearshape.fill", "Settings")
    ]

    var body: some View {
        VStack(spacing: 7) {
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                Button(action: {}) {
                    Image(systemName: action.0)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WayfolioPalette.brassBright)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(WayfolioPalette.navyRaised.opacity(0.96))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(WayfolioPalette.brass.opacity(0.65), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.1)
            }
        }
        .padding(5)
        .navySurface(radius: 16)
        .frame(width: WayfolioMetrics.quickRailWidth)
    }
}
