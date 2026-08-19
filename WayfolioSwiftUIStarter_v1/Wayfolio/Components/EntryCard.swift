import SwiftUI
import UIKit

struct EntryCard: View {
    let creature: CreatureRecord
    var discoveryLevel: CreatureDiscoveryLevel? = nil

    private var progress: Double {
        discoveryLevel?.progress ?? creature.completion
    }

    private var displayedName: String {
        guard let discoveryLevel else { return creature.name }
        switch discoveryLevel {
        case .unknown:
            return "Unknown Creature"
        case .sighted:
            return "Unidentified Creature"
        case .identified, .studied, .mastered:
            return creature.name
        }
    }

    private var displayedDescriptor: String {
        guard let discoveryLevel else { return creature.shortDescriptor }
        switch discoveryLevel {
        case .unknown:
            return "No confirmed observation"
        case .sighted:
            return "Sighted — identification pending"
        case .identified, .studied, .mastered:
            return creature.shortDescriptor
        }
    }

    private var displayedCategory: String {
        discoveryLevel == .unknown ? "Unknown" : creature.category
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                CreatureArtwork(assetName: creature.assetName, symbol: creature.fallbackSymbol)
                    .frame(height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if discoveryLevel == .unknown {
                            Rectangle()
                                .fill(WayfolioPalette.navy.opacity(0.72))
                                .overlay {
                                    Image(systemName: "questionmark")
                                        .font(.system(size: 38, weight: .light))
                                        .foregroundStyle(WayfolioPalette.parchment.opacity(0.85))
                                }
                        }
                    }

                Text(displayedCategory.uppercased())
                    .font(WayfolioTypography.tiny)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }

            Text(displayedName)
                .font(WayfolioTypography.headline)
                .foregroundStyle(WayfolioPalette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(displayedDescriptor)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.64))
                .lineLimit(1)

            WayfolioProgressStrip(value: progress, showLabel: false)

            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
        }
        .padding(10)
        .parchmentSurface(radius: WayfolioMetrics.cardRadius)
        .chromaGlow(active: progress >= CreatureDiscoveryLevel.studied.progress)
    }
}

struct CreatureArtwork: View {
    let assetName: String
    let symbol: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WayfolioPalette.navyRaised, WayfolioPalette.emerald.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(WayfolioPalette.parchment)
            }
        }
    }
}
