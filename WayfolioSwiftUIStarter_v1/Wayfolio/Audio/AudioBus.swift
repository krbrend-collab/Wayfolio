import Foundation

enum AudioBus: String, CaseIterable, Sendable {
    case voice
    case sfx
    case ambience
    case music
    case ui

    var defaultVolume: Float {
        switch self {
        case .voice: 1
        case .sfx: 0.9
        case .ambience: 0.55
        case .music: 0.5
        case .ui: 0.75
        }
    }
}

struct AudioBusMix: Equatable, Sendable {
    var volume: Float
    var isMuted: Bool

    init(volume: Float, isMuted: Bool = false) {
        self.volume = min(max(volume, 0), 1)
        self.isMuted = isMuted
    }
}
