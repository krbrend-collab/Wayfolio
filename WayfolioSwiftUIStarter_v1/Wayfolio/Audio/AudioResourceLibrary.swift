import Foundation

struct AudioResourceLibrary: Sendable {
    private let bundle: Bundle
    private let supportedExtensions = ["m4a", "wav", "aiff", "mp3", "caf"]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func url(for cue: String, on bus: AudioBus) -> URL? {
        guard isSafeCue(cue) else { return nil }

        let subdirectory: String
        switch bus {
        case .voice: subdirectory = "Audio/Voice"
        case .sfx: subdirectory = "Audio/SFX"
        case .ambience: subdirectory = "Audio/Ambience"
        case .music: subdirectory = "Audio/Music"
        case .ui: subdirectory = "Audio/UI"
        }

        for fileExtension in supportedExtensions {
            if let url = bundle.url(forResource: cue, withExtension: fileExtension, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    private func isSafeCue(_ cue: String) -> Bool {
        !cue.isEmpty &&
        !cue.contains("..") &&
        !cue.contains("/") &&
        !cue.contains("\\")
    }
}
