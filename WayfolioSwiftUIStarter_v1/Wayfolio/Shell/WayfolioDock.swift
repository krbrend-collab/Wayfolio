import SwiftUI

struct WayfolioDock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let selected: WayfolioSection
    var bottomInset: CGFloat = 0
    let onSelect: (WayfolioSection) -> Void

    var body: some View {
        GeometryReader { proxy in
            let sections = WayfolioSection.allCases
            let selectedIndex = sections.firstIndex(of: selected) ?? 0
            let itemWidth = proxy.size.width / CGFloat(max(sections.count, 1))
            let activeCenterX = (CGFloat(selectedIndex) + 0.5) * itemWidth

            ZStack(alignment: .top) {
                WayfolioDockBarShape(notchCenterX: activeCenterX)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.94), WayfolioPalette.midnight.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        WayfolioDockBarShape(notchCenterX: activeCenterX)
                            .stroke(WayfolioPalette.cyan.opacity(0.42), lineWidth: 0.8)
                    }
                    .shadow(color: WayfolioPalette.cyan.opacity(0.32), radius: 16, y: -5)
                    .frame(height: WayfolioMetrics.dockHardwareHeight + bottomInset)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .animation(
                        reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32),
                        value: activeCenterX
                    )
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    ForEach(sections) { section in
                        dockVisual(for: section, width: itemWidth)
                    }
                }
                .frame(height: WayfolioMetrics.dockGridHeight)
                .padding(.bottom, bottomInset)
                .allowsHitTesting(false)
                .zIndex(1)

                // Keep interaction in a separate, stable layer. The artwork intentionally
                // moves above the dock bar when selected; using it as the hit target makes
                // taps unreliable on iPhone where the visual may extend outside its cell.
                HStack(spacing: 0) {
                    ForEach(sections) { section in
                        Button {
                            onSelect(section)
                        } label: {
                            Rectangle()
                                // A nearly transparent fill is intentional: fully clear
                                // shapes can be dropped from hit testing on physical iOS.
                                .fill(Color.white.opacity(0.01))
                                .frame(width: itemWidth, height: WayfolioMetrics.dockHeight + bottomInset)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(section == .live ? "Live game" : section.title)
                        .accessibilityAddTraits(selected == section ? .isSelected : [])
                        .accessibilitySortPriority(accessibilityPriority(for: section))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: WayfolioMetrics.dockHeight + bottomInset)
                .contentShape(Rectangle())
                .zIndex(2)
            }
        }
        .frame(height: WayfolioMetrics.dockHeight + bottomInset)
    }

    private func dockVisual(for section: WayfolioSection, width: CGFloat) -> some View {
        let isSelected = selected == section
        let orbSize = WayfolioMetrics.activeDockMedallion
        let iconSize = isSelected ? WayfolioMetrics.activeDockIcon : 38

        return VStack(spacing: 3) {
                ZStack {
                if isSelected {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    WayfolioPalette.cyan.opacity(0.72),
                                    WayfolioPalette.violet.opacity(0.58),
                                    Color.black.opacity(0.96)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: orbSize * 0.72
                            )
                        )
                        .overlay(Circle().stroke(WayfolioPalette.cyan, lineWidth: 1.4))
                        .shadow(color: WayfolioPalette.cyan.opacity(0.74), radius: 14)
                        .frame(width: orbSize, height: orbSize)
                }

                Image(section.navigationAssetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .saturation(isSelected ? 1 : 0.05)
                    .opacity(isSelected ? 1 : 0.46)
                    .foregroundStyle(isSelected ? WayfolioPalette.cyan : WayfolioPalette.mutedText)
                    .shadow(color: isSelected ? WayfolioPalette.violet : .clear, radius: 9)
                }
                .frame(width: WayfolioMetrics.activeDockMedallion, height: WayfolioMetrics.activeDockMedallion)
                .offset(y: isSelected ? -16 : 8)

                Text(section.title)
                    .font(WayfolioTypography.tiny)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .offset(y: isSelected ? -12 : 1)
        }
        .foregroundStyle(isSelected ? WayfolioPalette.cyan : WayfolioPalette.mutedText.opacity(0.62))
        .frame(width: width, height: WayfolioMetrics.dockGridHeight)
        .contentShape(Rectangle())
        .animation(
            reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32),
            value: selected
        )
        .accessibilityHidden(true)
    }

    private func accessibilityPriority(for section: WayfolioSection) -> Double {
        switch section {
        case .character: 5
        case .pack: 4
        case .live: 3
        case .journal: 2
        case .world: 1
        }
    }
}

private struct WayfolioDockBarShape: Shape {
    var notchCenterX: CGFloat

    var animatableData: CGFloat {
        get { notchCenterX }
        set { notchCenterX = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let top: CGFloat = 27
        let shoulder: CGFloat = 54
        let socket: CGFloat = 37
        let depth: CGFloat = 30
        let radius: CGFloat = 20
        let center = min(max(notchCenterX, shoulder + radius), rect.width - shoulder - radius)

        var path = Path()
        path.move(to: CGPoint(x: radius, y: top))
        path.addLine(to: CGPoint(x: center - shoulder, y: top))
        path.addCurve(
            to: CGPoint(x: center - socket, y: top + depth * 0.48),
            control1: CGPoint(x: center - 47, y: top),
            control2: CGPoint(x: center - 43, y: top + depth * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: center, y: top + depth),
            control1: CGPoint(x: center - 29, y: top + depth * 0.84),
            control2: CGPoint(x: center - 15, y: top + depth)
        )
        path.addCurve(
            to: CGPoint(x: center + socket, y: top + depth * 0.48),
            control1: CGPoint(x: center + 15, y: top + depth),
            control2: CGPoint(x: center + 29, y: top + depth * 0.84)
        )
        path.addCurve(
            to: CGPoint(x: center + shoulder, y: top),
            control1: CGPoint(x: center + 43, y: top + depth * 0.24),
            control2: CGPoint(x: center + 47, y: top)
        )
        path.addLine(to: CGPoint(x: rect.width - radius, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: top + radius), control: CGPoint(x: rect.width, y: top))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: top + radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: top), control: CGPoint(x: 0, y: top))
        path.closeSubpath()
        return path
    }
}

enum WayfolioFeatureIcon: String {
    case character = "wayfolio-feature-character"
    case abilities = "wayfolio_feature_abilities_v02"
    case inventory = "wayfolio-feature-inventory"
    case crafting = "wayfolio-feature-crafting"
    case companion = "wayfolio-feature-companion"
    case peopleBonds = "wayfolio-feature-people-bonds"
    case quests = "wayfolio-feature-quests"
    case connections = "wayfolio-feature-connections"
    case wallet = "wayfolio-feature-wallet"
    case archive = "wayfolio-feature-archive"
    case settings = "wayfolio-feature-settings"
}

struct WayfolioApprovedIcon: View {
    let assetName: String
    var size: CGFloat = 30

    init(_ feature: WayfolioFeatureIcon, size: CGFloat = 30) {
        self.assetName = feature.rawValue
        self.size = size
    }

    init(assetName: String, size: CGFloat = 30) {
        self.assetName = assetName
        self.size = size
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
