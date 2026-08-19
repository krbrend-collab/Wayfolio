import SwiftUI

struct WayfolioDock: View {
    let selected: WayfolioSection
    let onSelect: (WayfolioSection) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                ForEach(WayfolioSection.allCases) { section in
                    Button {
                        onSelect(section)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 19, weight: .medium))
                            Text(section.title)
                                .font(WayfolioTypography.tiny)
                        }
                        .foregroundStyle(selected == section ? WayfolioPalette.brassBright : WayfolioPalette.parchment.opacity(0.68))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityAddTraits(selected == section ? .isSelected : [])
                }
            }
            .frame(height: WayfolioMetrics.dockHeight)
            .padding(.horizontal, 6)
            .navySurface(radius: 24)

            CentralMedallion(isActive: true)
                .offset(y: -(WayfolioMetrics.medallionDiameter * 0.43))
                .allowsHitTesting(false)
        }
        .padding(.top, WayfolioMetrics.medallionDiameter * 0.43)
        .padding(.horizontal, WayfolioMetrics.outerMargin)
        .padding(.bottom, 5)
    }
}

private struct CentralMedallion: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(WayfolioPalette.navy)
                .overlay(Circle().stroke(WayfolioPalette.brass, lineWidth: 2))
                .shadow(color: WayfolioPalette.cyan.opacity(isActive ? 0.28 : 0), radius: 12)

            Circle()
                .stroke(WayfolioPalette.brass.opacity(0.55), lineWidth: 1)
                .padding(8)

            Image(systemName: "sparkle")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(WayfolioPalette.brassBright)
        }
        .frame(width: WayfolioMetrics.medallionDiameter, height: WayfolioMetrics.medallionDiameter)
        .accessibilityHidden(true)
    }
}
