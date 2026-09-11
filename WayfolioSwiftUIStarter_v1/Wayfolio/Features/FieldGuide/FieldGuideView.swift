import SwiftUI

struct FieldGuideView: View {
    @EnvironmentObject private var session: GameSessionClient
    let creatureID: String

    private var creature: GameSessionClient.KnowledgeRecord? {
        (session.knownCreatures + session.companions).first { $0.id == creatureID }
    }

    var body: some View {
        ScrollView {
            if let creature {
                LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                    VStack(spacing: 12) {
                        Image(systemName: creature.id == "unidentified-slime" ? "drop.fill" : "pawprint.fill")
                            .font(.system(size: 62)).foregroundStyle(WayfolioPalette.cyan)
                            .frame(width: 126, height: 126).background(WayfolioPalette.navy, in: Circle())
                            .overlay(Circle().stroke(WayfolioPalette.brass, lineWidth: 2))
                        Text(creature.name).font(WayfolioTypography.display).multilineTextAlignment(.center)
                        Text(creature.status.replacingOccurrences(of: "_", with: " ").uppercased())
                            .font(WayfolioTypography.caption).tracking(1)
                    }
                    .foregroundStyle(WayfolioPalette.ink).frame(maxWidth: .infinity).padding(20).parchmentSurface()

                    VStack(alignment: .leading, spacing: 11) {
                        Label("Confirmed Observations", systemImage: "sparkles.rectangle.stack.fill")
                            .font(WayfolioTypography.headline)
                        ForEach(creature.notes, id: \.self) { note in
                            Label(note, systemImage: "diamond.fill").font(WayfolioTypography.body)
                        }
                    }
                    .foregroundStyle(WayfolioPalette.ink).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16).parchmentSurface()

                    WayfolioStateCard(kind: .empty, title: "Unknown details remain concealed",
                                      message: "Identity, capabilities, motives, and statistics appear only when the active journey confirms them.")
                }
                .padding(.horizontal, WayfolioMetrics.contentInset).padding(.bottom, 28)
            } else {
                ContentUnavailableView("Entry unavailable", systemImage: "questionmark.folder")
            }
        }
        .scrollIndicators(.hidden)
    }
}
