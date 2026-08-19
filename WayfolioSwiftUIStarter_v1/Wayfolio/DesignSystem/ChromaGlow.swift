import SwiftUI

struct ChromaGlow: ViewModifier {
    var isActive: Bool
    var radius: CGFloat = WayfolioMetrics.cardRadius

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    WayfolioPalette.cyan,
                                    WayfolioPalette.violet,
                                    WayfolioPalette.magenta,
                                    WayfolioPalette.brassBright,
                                    WayfolioPalette.cyan
                                ],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .shadow(color: WayfolioPalette.cyan.opacity(0.4), radius: 8)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func chromaGlow(active: Bool, radius: CGFloat = WayfolioMetrics.cardRadius) -> some View {
        modifier(ChromaGlow(isActive: active, radius: radius))
    }
}
