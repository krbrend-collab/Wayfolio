import SwiftUI

struct EntriesView: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @EnvironmentObject private var session: GameSessionClient
    @State private var searchText = ""
    @State private var selectedFilter = "All"

    let onOpenCreature: (String) -> Void

    private var records: [(GameSessionClient.KnowledgeRecord, Bool)] {
        let creatures = session.knownCreatures.map { ($0, false) }
        let companions = session.companions.map { ($0, true) }
        let unique = creatures + companions.filter { companion in
            !creatures.contains(where: { $0.0.id == companion.0.id })
        }
        return unique.filter { record, companion in
            let searchMatches = searchText.isEmpty || record.name.localizedCaseInsensitiveContains(searchText)
                || record.notes.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            let filterMatches = selectedFilter == "All"
                || (selectedFilter == "Creatures" && !companion)
                || (selectedFilter == "Companions" && companion)
            return searchMatches && filterMatches
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Living Catalog").font(WayfolioTypography.title)
                        Text("\(records.count) journey-confirmed records")
                            .font(WayfolioTypography.caption).foregroundStyle(WayfolioPalette.ink.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "sparkles").foregroundStyle(WayfolioPalette.cyan).font(.title2)
                }
                .foregroundStyle(WayfolioPalette.ink).padding(14).parchmentSurface()

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(WayfolioPalette.brassBright)
                    TextField("Search known creatures", text: $searchText)
                        .font(WayfolioTypography.body).foregroundStyle(WayfolioPalette.parchment)
                        .accessibilityLabel("Search journey-confirmed creatures and companions")
                }
                .padding(.horizontal, 14).frame(height: 46).navySurface(radius: 14)

                HStack(spacing: 8) {
                    ForEach(["All", "Creatures", "Companions"], id: \.self) { filter in
                        WayfolioFilterChip(title: filter, selected: selectedFilter == filter) { selectedFilter = filter }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if records.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No creature record published",
                                      message: "Creatures appear only after the selected character encounters or confirms them in the active journey.")
                } else {
                    ForEach(records, id: \.0.id) { record, companion in
                        Button {
                            audio.playUISound("navigation_select")
                            onOpenCreature(record.id)
                        } label: {
                            HStack(spacing: 13) {
                                creatureThumbnail(for: record, companion: companion)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.status.replacingOccurrences(of: "_", with: " ").uppercased())
                                        .font(WayfolioTypography.tiny).tracking(0.7)
                                    Text(record.name).font(WayfolioTypography.title)
                                    Text(record.notes.first ?? "Journey-confirmed record")
                                        .font(WayfolioTypography.caption).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(WayfolioPalette.ink).padding(14).parchmentSurface()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(record.name), \(companion ? "companion" : "creature"), \(record.status.replacingOccurrences(of: "_", with: " "))")
                        .accessibilityHint("Shows only journey-confirmed information")
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func creatureThumbnail(for record: GameSessionClient.KnowledgeRecord, companion: Bool) -> some View {
        if ["crown-hare", "gloam-hound", "mimic-slime", "coppice-goblin"].contains(record.id) {
            ManifestCreatureThumbnail(recordID: record.id, name: record.name)
        } else {
            Image(systemName: companion ? "pawprint.fill" : "questionmark.diamond.fill")
                .font(.system(size: 28))
                .foregroundStyle(WayfolioPalette.cyan)
                .frame(width: 66, height: 66)
                .background(WayfolioPalette.navy, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        }
    }
}

private struct ManifestCreatureThumbnail: View {
    let recordID: String
    let name: String
    @State private var manifestImage: UIImage?

    var body: some View {
        Group {
            if let manifestImage { Image(uiImage: manifestImage).resizable().scaledToFill() }
            else { Image(recordID).resizable().scaledToFill() }
        }
        .frame(width: 66, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(WayfolioPalette.brass.opacity(0.72), lineWidth: 1))
        .accessibilityLabel("Approved illustration of \(name)")
        .task(id: recordID) {
            manifestImage = await WayfolioManifestImage.load(
                subjectID: WayfolioManifestImage.creatureSubject(for: recordID),
                subjectType: "CREATURE",
                role: "CREATURE_RECORD_ART"
            )
        }
    }
}
