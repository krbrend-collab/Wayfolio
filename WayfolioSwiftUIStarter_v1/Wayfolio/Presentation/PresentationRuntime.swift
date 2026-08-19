import Combine
import Foundation

@MainActor
final class PresentationRuntime: ObservableObject {
    let audio = WayfolioAudioEngine()

    private lazy var audioCoordinator = PresentationAudioCoordinator(audio: audio)
    private var channel: PresentationEventChannel?

    func connectConfiguredEndpoint() {
        guard channel == nil,
              let value = Bundle.main.object(
                forInfoDictionaryKey: "WAYFOLIO_PRESENTATION_WEBSOCKET_URL"
              ) as? String,
              let url = URL(string: value),
              ["ws", "wss"].contains(url.scheme?.lowercased() ?? "") else { return }

        let channel = PresentationEventChannel(
            transport: WebSocketPresentationTransport(url: url)
        )
        self.channel = channel
        audioCoordinator.connect(to: channel)
    }

    func disconnect() {
        audioCoordinator.disconnect()
        guard let channel else { return }
        self.channel = nil
        Task { await channel.disconnect() }
    }
}
