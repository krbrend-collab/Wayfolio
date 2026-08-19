import SwiftUI

struct WayfolioHeader: View {
    let title: String
    let subtitle: String
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: WayfolioMetrics.standardGap) {
            headerControl(
                symbol: canGoBack ? "chevron.left" : "sparkles",
                accessibility: canGoBack ? "Back" : "Wayfolio",
                action: canGoBack ? onBack : {}
            )
            .opacity(canGoBack ? 1 : 0.72)

            VStack(spacing: 3) {
                Text(title)
                    .font(WayfolioTypography.display)
                    .foregroundStyle(WayfolioPalette.ink)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text(subtitle.uppercased())
                    .font(WayfolioTypography.caption)
                    .tracking(1.2)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
            }
            .frame(maxWidth: .infinity)

            headerControl(symbol: "hare.fill", accessibility: "Profile", action: {})
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(minHeight: WayfolioMetrics.headerMinHeight)
        .parchmentSurface(radius: 22)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
    }

    private func headerControl(symbol: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(WayfolioPalette.brassBright)
                .frame(width: 48, height: 48)
                .background(Circle().fill(WayfolioPalette.navy))
                .overlay(Circle().stroke(WayfolioPalette.brass, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}
