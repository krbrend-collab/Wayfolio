import SwiftUI
import SwiftData

struct GuideHomeView: View {
    @Query(sort: \CreatureRecord.name) private var creatures: [CreatureRecord]
    @Query private var discoveryRecords: [CreatureDiscoveryRecord]
    let onOpenCreature: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Field Reference")
                    .font(WayfolioTypography.title)
                    .foregroundStyle(WayfolioPalette.ink)
                Text("Quick access to recent discoveries and active research.")
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.72))

                ForEach(creatures.prefix(2)) { creature in
                    Button { onOpenCreature(creature.id) } label: {
                        EntryCard(
                            creature: creature,
                            discoveryLevel: discoveryLevel(for: creature)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(WayfolioMetrics.contentInset)
            .parchmentSurface()
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func discoveryLevel(for creature: CreatureRecord) -> CreatureDiscoveryLevel {
        discoveryRecords.first(where: { $0.creatureID == creature.id })?.level
            ?? SampleData.initialDiscoveryLevel(for: creature)
    }
}
