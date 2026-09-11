import SwiftUI

struct WayfolioShellPresentation: Equatable {
    var chromeVisible: Bool
    var transitionPanelsOpacity: Double
    var contentOpacity: Double
    var backgroundOpacity: Double

    static let hidden = WayfolioShellPresentation(
        chromeVisible: false,
        transitionPanelsOpacity: 0,
        contentOpacity: 0,
        backgroundOpacity: 0
    )

    static let active = WayfolioShellPresentation(
        chromeVisible: true,
        transitionPanelsOpacity: 0,
        contentOpacity: 1,
        backgroundOpacity: 1
    )
}

struct WayfolioShell<Content: View>: View {
    let section: WayfolioSection
    let title: String
    let subtitle: String
    let canGoBack: Bool
    let presentation: WayfolioShellPresentation
    let backgroundAssetName: String
    let onBack: () -> Void
    let onSelectSection: (WayfolioSection) -> Void
    let content: Content

    init(
        section: WayfolioSection,
        title: String,
        subtitle: String,
        canGoBack: Bool,
        presentation: WayfolioShellPresentation = .active,
        backgroundAssetName: String = "hemlock-map",
        onBack: @escaping () -> Void,
        onSelectSection: @escaping (WayfolioSection) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.title = title
        self.subtitle = subtitle
        self.canGoBack = canGoBack
        self.presentation = presentation
        self.backgroundAssetName = backgroundAssetName
        self.onBack = onBack
        self.onSelectSection = onSelectSection
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            WayfolioBackground(imageName: backgroundAssetName)
                .opacity(presentation.backgroundOpacity)
                .animation(.easeOut(duration: 0.65), value: presentation.backgroundOpacity)

            VStack(spacing: 0) {
                WayfolioHeader(
                    title: title,
                    subtitle: subtitle,
                    canGoBack: canGoBack,
                    onBack: onBack
                )
                .opacity(presentation.chromeVisible ? 1 : 0)
                .offset(y: presentation.chromeVisible ? 0 : -150)
                .animation(
                    .spring(response: 0.48, dampingFraction: 0.86),
                    value: presentation.chromeVisible
                )

                ZStack {
                    WayfolioTransitionPanelStack()
                        .opacity(presentation.transitionPanelsOpacity)
                        .animation(.easeOut(duration: 0.30), value: presentation.transitionPanelsOpacity)
                        .allowsHitTesting(false)

                    content
                        .toolbar(.hidden, for: .navigationBar)
                        .opacity(presentation.contentOpacity)
                        .animation(.easeOut(duration: 0.32), value: presentation.contentOpacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, WayfolioMetrics.quickRailWidth + WayfolioMetrics.quickRailGap)
            }
            .padding(.horizontal, WayfolioMetrics.outerMargin)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WayfolioDock(selected: section, onSelect: onSelectSection)
                    .opacity(presentation.chromeVisible ? 1 : 0)
                    .offset(y: presentation.chromeVisible ? 0 : 180)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.86),
                        value: presentation.chromeVisible
                    )
            }

            WayfolioQuickRail()
                .padding(.trailing, WayfolioMetrics.outerMargin + 2)
                .padding(.top, WayfolioMetrics.headerMinHeight + 36)
                .padding(.bottom, WayfolioMetrics.dockHeight + 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .opacity(presentation.transitionPanelsOpacity > 0 || presentation.contentOpacity > 0 ? 1 : 0)
                .animation(.easeOut(duration: 0.30), value: presentation.transitionPanelsOpacity)
        }
    }
}

private struct WayfolioTransitionPanelStack: View {
    var body: some View {
        VStack(spacing: 14) {
            transitionPanel(height: 146)
            transitionPanel(height: 178)
            transitionPanel(height: 132)
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private func transitionPanel(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(WayfolioPalette.navy.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WayfolioPalette.cyan.opacity(0.42), lineWidth: 1.1)
            }
            .shadow(color: WayfolioPalette.cyan.opacity(0.14), radius: 18)
            .frame(height: height)
    }
}

private struct WayfolioBackground: View {
    let imageName: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WayfolioPalette.navy, WayfolioPalette.midnight],
                startPoint: .top,
                endPoint: .bottom
            )

            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(Color.black.opacity(0.18))

            LinearGradient(
                colors: [
                    WayfolioPalette.midnight.opacity(0.10),
                    WayfolioPalette.midnight.opacity(0.22),
                    WayfolioPalette.midnight.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [WayfolioPalette.cyan.opacity(0.09), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(WayfolioPalette.brass.opacity(0.65), lineWidth: 1.2)
                .padding(5)
        }
        .ignoresSafeArea()
        .id(imageName)
    }
}
