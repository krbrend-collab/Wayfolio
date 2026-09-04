import SwiftUI

struct WayfolioRootView: View {
    @EnvironmentObject private var audioRuntime: WayfolioAudioRuntime

    @State private var selectedSection: WayfolioSection = .entries
    @State private var guidePath: [WayfolioRoute] = []
    @State private var entriesPath: [WayfolioRoute] = []
    @State private var mapPath: [WayfolioRoute] = []
    @State private var notesPath: [WayfolioRoute] = []
    @State private var morePath: [WayfolioRoute] = []
    @State private var didEmitLoginAudio = false

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
        .onAppear(perform: emitLoginAudioOnce)
    }

    @ViewBuilder
    private var currentNavigationStack: some View {
        switch selectedSection {
        case .guide:
            NavigationStack(path: $guidePath) {
                GuideHomeView(onOpenCreature: openCreatureFromGuide)
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .entries:
            NavigationStack(path: $entriesPath) {
                EntriesView(onOpenCreature: openCreatureFromEntries)
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

    private func emitLoginAudioOnce() {
        guard !didEmitLoginAudio else { return }
        didEmitLoginAudio = true
        WayfolioAudioTrigger.emit(.musicLoginWayfolio)
        WayfolioAudioTrigger.emit(.wayfolioLogin)
    }

    private func openCreatureFromGuide(_ id: String) {
        WayfolioAudioTrigger.emit(.wayfolioOpen)
        guidePath.append(.creature(id))
    }

    private func openCreatureFromEntries(_ id: String) {
        WayfolioAudioTrigger.emit(.wayfolioOpen)
        entriesPath.append(.creature(id))
    }

    private func popCurrentPath() {
        WayfolioAudioTrigger.emit(.wayfolioClose)
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
        WayfolioAudioTrigger.emit(.wayfolioSelect)
        withAnimation(.snappy(duration: 0.28)) {
            selectedSection = section
        }
    }
}
