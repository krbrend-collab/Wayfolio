import SwiftUI

/// Persistent iPhone projector bar.
///
/// Geometry is intentionally asset-led: `wayfolio-topbar-approved` is the
/// approved user-corrected artwork and must not be reconstructed from separate
/// camera/ellipse shapes in SwiftUI. If the asset is temporarily unavailable,
/// the pure-black backing keeps the hardware camera region visually safe rather
/// than substituting an approximate design.
struct WayfolioHeader: View {
    let characterName: String
    let contextText: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scale = WayfolioMetrics.topBarScale(for: width)
            let runtimeY = WayfolioMetrics.topBarRuntimeCenterY * scale

            ZStack(alignment: .topLeading) {
                Color.black

                Image("wayfolio-topbar-approved")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                runtimeText("✦  \(characterName)", alignment: .leading, scale: scale)
                    .frame(width: width * 0.28, alignment: .leading)
                    .position(
                        x: width * (0.11 + 0.14),
                        y: runtimeY
                    )

                runtimeText("☀  \(contextText)", alignment: .trailing, scale: scale)
                    .frame(width: width * 0.31, alignment: .trailing)
                    .position(
                        x: width * (1 - 0.096 - 0.155),
                        y: runtimeY
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(characterName), \(contextText)")
    }

    private func runtimeText(_ value: String, alignment: Alignment, scale: CGFloat) -> some View {
        Text(value)
            .font(.custom("Georgia", size: 10 * scale))
            .foregroundStyle(Color(hex: 0xEFD79C))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: alignment)
            .shadow(color: Color.white.opacity(0.95), radius: 0.1 * scale)
            .shadow(color: Color(hex: 0xFFD67D, alpha: 0.12), radius: 0.7 * scale)
    }
}
