import SwiftUI
import UIKit

struct WayfolioShellEntryPresentation: Equatable {
    var backgroundOpacity: Double = 0
    var headerOpacity: Double = 0
    var headerOffset: CGFloat = -54
    var dockOpacity: Double = 0
    var dockOffset: CGFloat = 74
    var paneOpacity: Double = 0
    var contentOpacity: Double = 0
    var frameOpacity: Double = 0

    static let hidden = WayfolioShellEntryPresentation()
    static let complete = WayfolioShellEntryPresentation(
        backgroundOpacity: 1,
        headerOpacity: 1,
        headerOffset: 0,
        dockOpacity: 1,
        dockOffset: 0,
        paneOpacity: 0,
        contentOpacity: 1,
        frameOpacity: 1
    )
}

struct WayfolioShell<Content: View>: View {
    @EnvironmentObject private var session: GameSessionClient
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let section: WayfolioSection
    let title: String
    let subtitle: String
    let canGoBack: Bool
    var entryPresentation: WayfolioShellEntryPresentation = .complete
    var onReady: (() -> Void)?
    let onBack: () -> Void
    let onOpenProfile: () -> Void
    let onSelectSection: (WayfolioSection) -> Void
    let content: Content

    init(
        section: WayfolioSection,
        title: String,
        subtitle: String,
        canGoBack: Bool,
        entryPresentation: WayfolioShellEntryPresentation = .complete,
        onReady: (() -> Void)? = nil,
        onBack: @escaping () -> Void,
        onOpenProfile: @escaping () -> Void,
        onSelectSection: @escaping (WayfolioSection) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.title = title
        self.subtitle = subtitle
        self.canGoBack = canGoBack
        self.entryPresentation = entryPresentation
        self.onReady = onReady
        self.onBack = onBack
        self.onOpenProfile = onOpenProfile
        self.onSelectSection = onSelectSection
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                WayfolioPersonalSurfaceBackground()
                    .opacity(entryPresentation.backgroundOpacity)

                ProjectedCanvasFrame()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .opacity(entryPresentation.frameOpacity)

                VStack(spacing: 0) {
                    WayfolioHeader(
                        canGoBack: canGoBack,
                        onBack: onBack,
                        onOpenProfile: onOpenProfile
                    )
                    .opacity(entryPresentation.headerOpacity)
                    .offset(y: reduceMotion ? 0 : entryPresentation.headerOffset)

                    ZStack {
                        WayfolioEntryPaneScaffold()
                            .opacity(entryPresentation.paneOpacity)

                        content
                            .toolbar(.hidden, for: .navigationBar)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.clear)
                            .opacity(entryPresentation.contentOpacity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .clipped()

                    WayfolioDock(
                        selected: section,
                        bottomInset: max(geometry.safeAreaInsets.bottom, windowBottomInset),
                        onSelect: onSelectSection
                    )
                        .zIndex(100)
                        .opacity(entryPresentation.dockOpacity)
                        .offset(y: reduceMotion ? 0 : entryPresentation.dockOffset)
                }
                // Keep wide, horizontally scrolling feature rows from expanding the
                // projected canvas beyond the physical phone screen.
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear { reportReady(for: geometry.size) }
            .onChange(of: geometry.size) { _, size in reportReady(for: size) }
        }
        // Use physical screen coordinates. Header art may render behind the
        // status bar/camera region; the dock internally protects the home area.
        .ignoresSafeArea()
    }

    private func reportReady(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        onReady?()
    }

    private var windowBottomInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
    }
}

struct WayfolioPersonalSurfaceBackground: View {
    var body: some View {
        ZStack {
            Image(WayfolioSurfaceAsset.woodNeutral.catalogName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            RadialGradient(
                colors: [WayfolioPalette.cyan.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            LinearGradient(
                colors: [Color.black.opacity(0.10), WayfolioPalette.midnight.opacity(0.14), Color.black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct WayfolioEntryPaneScaffold: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WayfolioPalette.navy.opacity(0.48))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(WayfolioPalette.cyan.opacity(0.70), lineWidth: 1))
                .frame(height: 94)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WayfolioPalette.navy.opacity(0.38))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(WayfolioPalette.cyan.opacity(0.52), lineWidth: 1))
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, WayfolioMetrics.contentInset)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}
