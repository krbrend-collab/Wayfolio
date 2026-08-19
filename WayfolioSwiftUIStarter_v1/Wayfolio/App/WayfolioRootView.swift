import SwiftUI

struct WayfolioRootView: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @State private var selectedSection: WayfolioSection = .entries
    @State private var guidePath: [WayfolioRoute] = []
    @State private var entriesPath: [WayfolioRoute] = []
    @State private var mapPath: [WayfolioRoute] = []
    @State private var notesPath: [WayfolioRoute] = []
    @State private var morePath: [WayfolioRoute] = []

    var body: some View {
        WayfolioShell(
            section: selectedSection,
            title: currentTitle,
            subtitle: currentSubtitle,
            canGoBack: currentPathIsNotEmpty,
            onBack: popCurrentPath,
            onSelectSection: switchSection
        ) {
            currentNavigationStack
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var currentNavigationStack: some View {
        switch selectedSection {
        case .guide:
            NavigationStack(path: $guidePath) {
                GuideHomeView(onOpenCreature: { guidePath.append(.creature($0)) })
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .entries:
            NavigationStack(path: $entriesPath) {
                EntriesView(onOpenCreature: { entriesPath.append(.creature($0)) })
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .map:
            NavigationStack(path: $mapPath) {
                MapPlaceholderView()
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .notes:
            NavigationStack(path: $notesPath) {
                NotesPlaceholderView()
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .more:
            NavigationStack(path: $morePath) {
                MorePlaceholderView()
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: WayfolioRoute) -> some View {
        switch route {
        case .creature(let id):
            FieldGuideView(creatureID: id)
        }
    }

    private var currentTitle: String {
        currentPathIsNotEmpty ? "Field Guide" : selectedSection.title
    }

    private var currentSubtitle: String {
        if currentPathIsNotEmpty { return "Living Specimen Record" }
        switch selectedSection {
        case .guide: return "Field Reference"
        case .entries: return "Collection Ledger"
        case .map: return "World Exploration"
        case .notes: return "Research & Lore"
        case .more: return "Wayfolio Systems"
        }
    }

    private var currentPathIsNotEmpty: Bool {
        switch selectedSection {
        case .guide: !guidePath.isEmpty
        case .entries: !entriesPath.isEmpty
        case .map: !mapPath.isEmpty
        case .notes: !notesPath.isEmpty
        case .more: !morePath.isEmpty
        }
    }

    private func popCurrentPath() {
        audio.playUISound("navigation_back")
        switch selectedSection {
        case .guide:
            if !guidePath.isEmpty { guidePath.removeLast() }
        case .entries:
            if !entriesPath.isEmpty { entriesPath.removeLast() }
        case .map:
            if !mapPath.isEmpty { mapPath.removeLast() }
        case .notes:
            if !notesPath.isEmpty { notesPath.removeLast() }
        case .more:
            if !morePath.isEmpty { morePath.removeLast() }
        }
    }

    private func switchSection(_ section: WayfolioSection) {
        guard section != selectedSection else { return }
        audio.playUISound("navigation_select")
        withAnimation(.snappy(duration: 0.28)) {
            selectedSection = section
        }
    }
}
