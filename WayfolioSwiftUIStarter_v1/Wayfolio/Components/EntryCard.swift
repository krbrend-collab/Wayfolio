import SwiftUI
import UIKit

struct EntryCard: View {
    let creature: CreatureRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                CreatureArtwork(assetName: creature.assetName, symbol: creature.fallbackSymbol)
                    .frame(height: 126)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(creature.category.uppercased())
                    .font(WayfolioTypography.tiny)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }

            Text(creature.name)
                .font(WayfolioTypography.headline)
                .foregroundStyle(WayfolioPalette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(creature.shortDescriptor)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.64))
                .lineLimit(1)

            WayfolioProgressStrip(value: creature.completion, showLabel: false)

            Text(creature.completion, format: .percent.precision(.fractionLength(0)))
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
        }
        .padding(10)
        .parchmentSurface(radius: WayfolioMetrics.cardRadius)
        .chromaGlow(active: creature.completion >= 0.7)
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
