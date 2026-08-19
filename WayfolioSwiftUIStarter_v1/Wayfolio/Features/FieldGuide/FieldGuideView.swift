import SwiftUI
import SwiftData

struct FieldGuideView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var creatures: [CreatureRecord]
    @Query private var discoveryRecords: [CreatureDiscoveryRecord]

    let creatureID: UUID

    private var creature: CreatureRecord? {
        creatures.first { $0.id == creatureID }
    }

    private var discoveryRecord: CreatureDiscoveryRecord? {
        discoveryRecords.first { $0.creatureID == creatureID }
    }

    private let twoColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if let creature {
                let level = discoveryLevel(for: creature)

                LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                    hero(for: creature, level: level)
                    discoverySummary(level: level)

                    if level.progress >= CreatureDiscoveryLevel.sighted.progress {
                        fieldNote(creature.fieldNote)
                    }

                    if level.progress >= CreatureDiscoveryLevel.identified.progress {
                        LazyVGrid(columns: twoColumns, spacing: 12) {
                            fieldCard("Affinity", creature.affinity, symbol: "leaf.fill")
                            fieldCard("Temperament", creature.temperament, symbol: "heart.fill")
                        }
                    }

                    if level.progress >= CreatureDiscoveryLevel.studied.progress {
                        LazyVGrid(columns: twoColumns, spacing: 12) {
                            fieldCard("Habitat", creature.habitat, symbol: "tree.fill")
                            fieldCard("Active Hours", creature.activeHours, symbol: "clock.fill")
                            fieldCard("Healing Uses", creature.healingUses, symbol: "cross.case.fill")
                            fieldCard("Open Questions", creature.unknownNotes, symbol: "questionmark.circle.fill")
                        }
                    }

                    if level == .mastered {
                        masteryNotice
                    }

                    if let next = level.next {
                        prototypeRuntimeControl(nextLevel: next)
                    }
                }
                .padding(.horizontal, WayfolioMetrics.contentInset)
                .padding(.bottom, 28)
            } else {
                ContentUnavailableView("Entry unavailable", systemImage: "questionmark.folder")
            }
        }
        .scrollIndicators(.hidden)
    }

    private func discoveryLevel(for creature: CreatureRecord) -> CreatureDiscoveryLevel {
        discoveryRecord?.level ?? SampleData.initialDiscoveryLevel(for: creature)
    }

    private func hero(for creature: CreatureRecord, level: CreatureDiscoveryLevel) -> some View {
        VStack(spacing: 0) {
            CreatureArtwork(assetName: creature.assetName, symbol: creature.fallbackSymbol)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WayfolioPalette.brass, lineWidth: 1.2)
                }
                .overlay {
                    if level == .unknown {
                        Rectangle()
                            .fill(WayfolioPalette.navy.opacity(0.78))
                            .overlay {
                                Image(systemName: "questionmark")
                                    .font(.system(size: 72, weight: .ultraLight))
                                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.82))
                            }
                    }
                }

            VStack(spacing: 4) {
                Text(displayName(for: creature, level: level))
                    .font(WayfolioTypography.display)
                    .foregroundStyle(WayfolioPalette.ink)
                    .multilineTextAlignment(.center)

                Text(displayDescriptor(for: creature, level: level).uppercased())
                    .font(WayfolioTypography.caption)
                    .tracking(1)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .parchmentSurface(radius: 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .chromaGlow(active: level.progress >= CreatureDiscoveryLevel.studied.progress, radius: 18)
    }

    private func discoverySummary(level: CreatureDiscoveryLevel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Discovery", systemImage: "scope")
                    .font(WayfolioTypography.headline)
                    .foregroundStyle(WayfolioPalette.ink)
                Spacer()
                Text(level.displayName.uppercased())
                    .font(WayfolioTypography.tiny)
                    .tracking(1)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.64))
            }

            WayfolioProgressStrip(value: level.progress)

            Text(discoveryDescription(for: level))
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.74))
        }
        .padding(14)
        .parchmentSurface()
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
            Label("Observed", systemImage: "eye.fill")
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

    private var masteryNotice: some View {
        Label("Current field record fully studied", systemImage: "checkmark.seal.fill")
            .font(WayfolioTypography.headline)
            .foregroundStyle(WayfolioPalette.ink)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentSurface()
    }

    private func prototypeRuntimeControl(nextLevel: CreatureDiscoveryLevel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROTOTYPE RUNTIME EVENT")
                .font(WayfolioTypography.tiny)
                .tracking(1.2)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.62))

            Text("This control temporarily stands in for a committed campaign discovery event so the vertical slice can be tested end-to-end.")
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.76))

            Button {
                advanceDiscovery(to: nextLevel)
            } label: {
                Label("Record \(nextLevel.displayName)", systemImage: "sparkles")
                    .font(WayfolioTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(WayfolioPalette.parchment)
            .background(WayfolioPalette.navyRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(WayfolioPalette.brass, lineWidth: 1)
            }
        }
        .padding(14)
        .navySurface(radius: WayfolioMetrics.cardRadius)
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

    private func displayDescriptor(for creature: CreatureRecord, level: CreatureDiscoveryLevel) -> String {
        switch level {
        case .unknown:
            return "No confirmed observation"
        case .sighted:
            return "Living specimen sighted"
        case .identified, .studied, .mastered:
            return creature.shortDescriptor
        }
    }

    private func discoveryDescription(for level: CreatureDiscoveryLevel) -> String {
        switch level {
        case .unknown:
            return "No reliable field observation has been recorded yet."
        case .sighted:
            return "The Wayfolio has recorded the creature's presence and observable movement, but its identity remains unconfirmed."
        case .identified:
            return "The species has been identified. Basic affinity and temperament notes are now available."
        case .studied:
            return "Repeated observation has unlocked habitat, active-hour, and practical field information."
        case .mastered:
            return "The currently available player-facing field record has been fully studied. Future campaign discoveries may still expand it."
        }
    }

    @MainActor
    private func advanceDiscovery(to nextLevel: CreatureDiscoveryLevel) {
        if let discoveryRecord {
            discoveryRecord.level = nextLevel
        } else {
            modelContext.insert(
                CreatureDiscoveryRecord(
                    creatureID: creatureID,
                    level: nextLevel
                )
            )
        }

        try? modelContext.save()
    }
}
