import SwiftUI
import SwiftData

struct EntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreatureRecord.name) private var creatures: [CreatureRecord]
    @Query private var discoveryRecords: [CreatureDiscoveryRecord]

    @State private var searchText = ""
    @State private var selectedFilter = "All"

    let onOpenCreature: (UUID) -> Void

    private let filters = ["All", "Creatures", "Companions", "Materials"]
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var visibleCreatures: [CreatureRecord] {
        creatures.filter { creature in
            let level = discoveryLevel(for: creature)
            let matchesSearch = searchText.isEmpty || displayName(for: creature, level: level)
                .localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch selectedFilter {
            case "Companions":
                matchesFilter = creature.isCompanion && level.progress >= CreatureDiscoveryLevel.identified.progress
            case "Creatures":
                matchesFilter = creature.category == "Creature"
            case "Materials":
                matchesFilter = creature.category == "Material"
            default:
                matchesFilter = true
            }

            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                collectionSummary
                searchField
                filtersRow

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleCreatures) { creature in
                        let level = discoveryLevel(for: creature)
                        Button {
                            onOpenCreature(creature.id)
                        } label: {
                            EntryCard(creature: creature, discoveryLevel: level)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .task(seedIfNeeded)
        .background(Color.clear)
    }

    private var collectionSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Living Catalog")
                    .font(WayfolioTypography.title)
                    .foregroundStyle(WayfolioPalette.ink)
                Text("\(creatures.count) known records")
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.65))
            }
            Spacer()
            Image(systemName: "sparkles")
                .foregroundStyle(WayfolioPalette.cyan)
                .font(.title2)
        }
        .padding(14)
        .parchmentSurface()
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(WayfolioPalette.brassBright)
            TextField("Search entries", text: $searchText)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.parchment)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(WayfolioPalette.mutedText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .navySurface(radius: 14)
    }

    private var filtersRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    WayfolioFilterChip(title: filter, selected: selectedFilter == filter) {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func discoveryLevel(for creature: CreatureRecord) -> CreatureDiscoveryLevel {
        discoveryRecords.first(where: { $0.creatureID == creature.id })?.level
            ?? SampleData.initialDiscoveryLevel(for: creature)
    }

    private func displayName(for creature: CreatureRecord, level: CreatureDiscoveryLevel) -> String {
        switch level {
        case .unknown:
            return "Unknown Creature"
        case .sighted:
            return "Unidentified Creature"
        case .identified, .studied, .mastered:
            return creature.name
        }
    }

    @MainActor
    private func seedIfNeeded() async {
        for sample in SampleData.creatures {
            let storedCreature: CreatureRecord

            if let existing = creatures.first(where: { $0.name == sample.name }) {
                storedCreature = existing
            } else {
                modelContext.insert(sample)
                storedCreature = sample
            }

            let alreadyHasDiscovery = discoveryRecords.contains {
                $0.creatureID == storedCreature.id
            }

            if !alreadyHasDiscovery {
                modelContext.insert(
                    CreatureDiscoveryRecord(
                        creatureID: storedCreature.id,
                        level: SampleData.initialDiscoveryLevel(for: storedCreature)
                    )
                )
            }
        }

        try? modelContext.save()
    }
}
