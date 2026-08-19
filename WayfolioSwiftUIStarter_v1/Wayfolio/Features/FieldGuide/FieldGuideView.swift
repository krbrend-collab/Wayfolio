import SwiftUI
import SwiftData

struct FieldGuideView: View {
    @Query private var creatures: [CreatureRecord]
    let creatureID: UUID

    private var creature: CreatureRecord? {
        creatures.first { $0.id == creatureID }
    }

    private let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if let creature {
                LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                    hero(for: creature)
                    WayfolioProgressStrip(value: creature.completion)
                        .padding(14)
                        .parchmentSurface()

                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        fieldCard("Affinity", creature.affinity, symbol: "leaf.fill")
                        fieldCard("Temperament", creature.temperament, symbol: "heart.fill")
                        fieldCard("Habitat", creature.habitat, symbol: "tree.fill")
                        fieldCard("Active Hours", creature.activeHours, symbol: "clock.fill")
                        fieldCard("Healing Uses", creature.healingUses, symbol: "cross.case.fill")
                        fieldCard("Unknown Notes", creature.unknownNotes, symbol: "questionmark.circle.fill")
                    }

                    fieldNote(creature.fieldNote)
                }
                .padding(.horizontal, WayfolioMetrics.contentInset)
                .padding(.bottom, 28)
            } else {
                ContentUnavailableView("Entry unavailable", systemImage: "questionmark.folder")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func hero(for creature: CreatureRecord) -> some View {
        VStack(spacing: 0) {
            CreatureArtwork(assetName: creature.assetName, symbol: creature.fallbackSymbol)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WayfolioPalette.brass, lineWidth: 1.2)
                }

            VStack(spacing: 4) {
                Text(creature.name)
                    .font(WayfolioTypography.display)
                    .foregroundStyle(WayfolioPalette.ink)
                    .multilineTextAlignment(.center)
                Text(creature.shortDescriptor.uppercased())
                    .font(WayfolioTypography.caption)
                    .tracking(1)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .parchmentSurface(radius: 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .chromaGlow(active: creature.completion > 0.6, radius: 18)
    }

    private func fieldCard(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(WayfolioTypography.headline)
                .foregroundStyle(WayfolioPalette.ink)
            Text(value)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .parchmentSurface(radius: WayfolioMetrics.cardRadius)
    }

    private func fieldNote(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Field Note", systemImage: "pencil.and.scribble")
                .font(WayfolioTypography.headline)
                .foregroundStyle(WayfolioPalette.ink)
            Text(note)
                .font(WayfolioTypography.body.italic())
                .foregroundStyle(WayfolioPalette.ink.opacity(0.78))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentSurface()
    }
}
