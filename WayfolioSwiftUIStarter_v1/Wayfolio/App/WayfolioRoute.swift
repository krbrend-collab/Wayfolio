import Foundation

enum WayfolioSection: String, CaseIterable, Identifiable, Hashable {
    case character
    case pack
    case live
    case journal
    case world

    var id: Self { self }

    var title: String {
        switch self {
        case .character: "Character"
        case .pack: "Pack"
        case .live: "Live"
        case .journal: "Journal"
        case .world: "World"
        }
    }

    var symbol: String {
        switch self {
        case .character: "person.crop.circle"
        case .pack: "backpack.fill"
        case .live: "sparkle"
        case .journal: "book.closed.fill"
        case .world: "map.fill"
        }
    }

    var navigationAssetName: String {
        switch self {
        case .character: "wayfolio-nav-character"
        case .pack: "wayfolio-nav-pack"
        case .live: "wayfolio-nav-live"
        case .journal: "wayfolio-nav-journal"
        case .world: "wayfolio-nav-world"
        }
    }
}

enum WayfolioRoute: Hashable {
    case creature(String)
    case item(String)

    var title: String {
        switch self {
        case .creature: "Creature Record"
        case .item: "Item Record"
        }
    }

    var subtitle: String {
        switch self {
        case .creature: "Progressive Field Discovery"
        case .item: "Known Item Details"
        }
    }
}

/// Local presentation state only. Campaign and session authority remain elsewhere.
struct WayfolioNavigationState: Equatable {
    private(set) var selectedSection: WayfolioSection = .character
    private var paths: [WayfolioSection: [WayfolioRoute]] = [:]

    init(selectedSection: WayfolioSection = .character) {
        self.selectedSection = selectedSection
    }

    var currentPath: [WayfolioRoute] {
        path(for: selectedSection)
    }

    var currentRoute: WayfolioRoute? {
        currentPath.last
    }

    var canGoBack: Bool {
        !currentPath.isEmpty
    }

    func path(for section: WayfolioSection) -> [WayfolioRoute] {
        guard section != .live else { return [] }
        return paths[section, default: []]
    }

    mutating func setPath(_ path: [WayfolioRoute], for section: WayfolioSection) {
        guard section != .live else { return }
        paths[section] = path
    }

    mutating func push(_ route: WayfolioRoute, in section: WayfolioSection) {
        guard section != .live else { return }
        paths[section, default: []].append(route)
    }

    mutating func pop() {
        guard selectedSection != .live, paths[selectedSection]?.isEmpty == false else { return }
        paths[selectedSection]?.removeLast()
    }

    mutating func select(_ section: WayfolioSection) {
        if section == selectedSection {
            setPath([], for: section)
        } else {
            selectedSection = section
        }
    }
}
