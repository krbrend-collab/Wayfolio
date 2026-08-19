import SwiftUI

struct ParchmentSurface: ViewModifier {
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WayfolioPalette.parchment, WayfolioPalette.parchmentDeep.opacity(0.94)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(WayfolioPalette.brass.opacity(0.8), lineWidth: 1)
                    }
            )
    }
}

struct NavySurface: ViewModifier {
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WayfolioPalette.navyRaised, WayfolioPalette.midnight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(WayfolioPalette.brass.opacity(0.7), lineWidth: 1)
                    }
            )
    }
}

extension View {
    func parchmentSurface(radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(ParchmentSurface(radius: radius))
    }

    func navySurface(radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(NavySurface(radius: radius))
    }
}
