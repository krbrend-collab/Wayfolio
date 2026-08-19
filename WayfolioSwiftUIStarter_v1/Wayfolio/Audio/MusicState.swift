import Foundation

enum MusicState: Equatable, Sendable {
    case stopped
    case playing(cue: String, intensity: Float)

    var cue: String? {
        guard case .playing(let cue, _) = self else { return nil }
        return cue
    }
}
