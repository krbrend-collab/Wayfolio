import Foundation

enum WayfolioSection: String, CaseIterable, Identifiable, Hashable {
    case guide
    case entries
    case map
    case notes
    case more

    var id: Self { self }

    var title: String {
        switch self {
        case .guide: "Guide"
        case .entries: "Entries"
        case .map: "Map"
        case .notes: "Notes"
        case .more: "More"
        }
    }

    var symbol: String {
        switch self {
        case .guide: "sparkles.rectangle.stack"
        case .entries: "books.vertical"
        case .map: "map"
        case .notes: "note.text"
        case .more: "ellipsis.circle"
        }
    }
}

enum WayfolioRoute: Hashable {
    case creature(UUID)
}
