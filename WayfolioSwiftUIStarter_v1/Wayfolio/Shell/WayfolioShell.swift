import SwiftUI

struct WayfolioShell<Content: View>: View {
    let section: WayfolioSection
    let title: String
    let subtitle: String
    let canGoBack: Bool
    let onBack: () -> Void
    let onSelectSection: (WayfolioSection) -> Void
    let characterName: String
    let contextText: String
    let content: Content

    init(
        section: WayfolioSection,
        title: String,
        subtitle: String,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        onSelectSection: @escaping (WayfolioSection) -> Void,
        characterName: String = "Renn Hazel",
        contextText: String = "Clear · Dusk",
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.title = title
        self.subtitle = subtitle
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.onSelectSection = onSelectSection
        self.characterName = characterName
        self.contextText = contextText
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let topBarHeight = WayfolioMetrics.topBarHeight(for: proxy.size.width)
            let scale = WayfolioMetrics.topBarScale(for: proxy.size.width)

            ZStack(alignment: .top) {
                WayfolioBackground()

                WayfolioAmbientHaze(scale: scale)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topBarHeight)

                    if canGoBack {
                        backControl
                    }

                    content
                        .toolbar(.hidden, for: .navigationBar)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.trailing, WayfolioMetrics.quickRailWidth + WayfolioMetrics.quickRailGap)
                }
                .padding(.horizontal, WayfolioMetrics.outerMargin)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    WayfolioDock(selected: section, onSelect: onSelectSection)
                }

                WayfolioQuickRail()
                    .padding(.trailing, WayfolioMetrics.outerMargin + 2)
                    .padding(.top, topBarHeight + 12)
                    .padding(.bottom, WayfolioMetrics.dockHeight + 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                WayfolioHeader(
                    characterName: characterName,
                    contextText: contextText
                )
                .frame(width: proxy.size.width, height: topBarHeight)
                .zIndex(30)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var backControl: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WayfolioPalette.cyan)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityHint("Return from \(title)")

            Spacer()
        }
        .frame(height: 52)
    }
}

private struct WayfolioAmbientHaze: View {
    let scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let hazeTop = 100 * scale
            let hazeBottom = 118 * scale
            let hazeWidth = width * 1.22
            let hazeHeight = max(1, height - hazeTop - hazeBottom)
            let blur = 14 * scale

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0x31B1D4, alpha: 0.07), location: 0),
                        .init(color: Color(hex: 0x12455B, alpha: 0.018), location: 0.49),
                        .init(color: Color(hex: 0x30AED0, alpha: 0.05), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x54E8FF, alpha: 0.31), location: 0),
                                .init(color: Color(hex: 0x3ABCE5, alpha: 0.18), location: 0.34),
                                .init(color: .clear, location: 0.74)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: hazeWidth * 0.42
                        )
                    )
                    .frame(width: hazeWidth * 1.68, height: hazeHeight * 0.36)
                    .position(x: hazeWidth * 0.50, y: hazeHeight * 0.02)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0x47D0F1, alpha: 0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: hazeWidth * 0.19
                        )
                    )
                    .frame(width: hazeWidth * 0.76, height: hazeHeight * 1.10)
                    .position(x: hazeWidth * 0.18, y: hazeHeight * 0.40)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0x30A0CE, alpha: 0.07), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: hazeWidth * 0.19
                        )
                    )
                    .frame(width: hazeWidth * 0.76, height: hazeHeight * 1.10)
                    .position(x: hazeWidth * 0.82, y: hazeHeight * 0.64)
            }
            .frame(width: hazeWidth, height: hazeHeight)
            .blur(radius: blur)
            .opacity(0.84)
            .position(
                x: width / 2,
                y: hazeTop + hazeHeight / 2
            )
        }
    }
}

private struct WayfolioBackground: View {
    var body: some View {
        LinearGradient(
            colors: [WayfolioPalette.navy, WayfolioPalette.midnight],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
