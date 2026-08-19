import Foundation

@MainActor
final class PresentationAudioCoordinator {
    private let audio: WayfolioAudioEngine
    private var eventTask: Task<Void, Never>?

    init(audio: WayfolioAudioEngine) {
        self.audio = audio
    }

    func connect(to channel: PresentationEventChannel) {
        disconnect()
        eventTask = Task {
            do {
                for try await event in await channel.events() {
                    guard !Task.isCancelled else { return }
                    handle(event.command)
                }
            } catch {
                // Connection failures do not affect campaign or app state. A
                // higher-level connection UI can observe status in a later milestone.
            }
        }
    }

    func disconnect() {
        eventTask?.cancel()
        eventTask = nil
    }

    private func handle(_ command: PresentationCommand) {
        switch command {
        case .uiOneShot(let cue, let volume):
            audio.playUISound(cue, volume: volume)
        case .worldOneShot(let cue, let volume):
            audio.playWorldSound(cue, volume: volume)
        case .ambience(let action, let cue, let volume):
            if action == .stop {
                audio.stopAmbience()
            } else if let cue {
                audio.playAmbience(cue, volume: volume)
            }
        case .music(let action, let cue, let intensity, let volume, let fadeDuration):
            audio.applyMusic(
                action: action,
                cue: cue,
                intensity: intensity,
                volume: volume,
                fadeDuration: fadeDuration
            )
        }
    }
}
