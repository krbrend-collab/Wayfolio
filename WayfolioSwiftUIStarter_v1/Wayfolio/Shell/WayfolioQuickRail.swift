import SwiftUI

enum WayfolioQuickAction: String, CaseIterable, Identifiable {
    case discoveries
    case creatures
    case botanicals
    case alchemy
    case settings

    var id: Self { self }

    var symbol: String {
        switch self {
        case .discoveries: "sparkles"
        case .creatures: "pawprint.fill"
        case .botanicals: "leaf.fill"
        case .alchemy: "flask.fill"
        case .settings: "gearshape.fill"
        }
    }

    var title: String { rawValue.capitalized }
}

struct WayfolioQuickRail: View {
    let onSelect: (WayfolioQuickAction) -> Void

    var body: some View {
        VStack(spacing: 7) {
            ForEach(WayfolioQuickAction.allCases) { action in
                Button { onSelect(action) } label: {
                    Image(systemName: action.symbol)
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
                .accessibilityLabel(action.title)
            }
        }
        .padding(5)
        .navySurface(radius: 16)
        .frame(width: WayfolioMetrics.quickRailWidth)
    }
}
