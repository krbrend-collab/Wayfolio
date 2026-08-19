import SwiftUI

struct WayfolioShell<Content: View>: View {
    let section: WayfolioSection
    let title: String
    let subtitle: String
    let canGoBack: Bool
    let onBack: () -> Void
    let onSelectSection: (WayfolioSection) -> Void
    let content: Content

    init(
        section: WayfolioSection,
        title: String,
        subtitle: String,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        onSelectSection: @escaping (WayfolioSection) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.title = title
        self.subtitle = subtitle
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.onSelectSection = onSelectSection
        self.content = content()
    }

    var body: some View {
        ZStack {
            WayfolioBackground()

            VStack(spacing: 0) {
                WayfolioHeader(
                    title: title,
                    subtitle: subtitle,
                    canGoBack: canGoBack,
                    onBack: onBack
                )

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
                .padding(.top, WayfolioMetrics.headerMinHeight + 36)
                .padding(.bottom, WayfolioMetrics.dockHeight + 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

private struct WayfolioBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WayfolioPalette.navy, WayfolioPalette.midnight],
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
    }
}
