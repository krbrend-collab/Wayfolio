import AVFoundation
import Combine
import Foundation

@MainActor
final class PresentationRuntime: ObservableObject {
    let audio = WayfolioAudioEngine()

    private lazy var audioCoordinator = PresentationAudioCoordinator(audio: audio)
    private var channel: PresentationEventChannel?
    private var voiceTask: Task<Void, Never>?

    private struct AmbienceProfile {
        let cue: String
        let volume: Float
        let music: String?
        let musicVolume: Float
    }

    private static let ambienceProfiles: [String: AmbienceProfile] = [
        "forest_day": .init(cue: "recorded_forest_wind", volume: 0.42, music: "forest_exploration", musicVolume: 0.27),
        "tavern_busy": .init(cue: "hemlock_tavern", volume: 0.44, music: "crowded_pub", musicVolume: 0.24),
        "festival_lively": .init(cue: "festival", volume: 0.48, music: "market_day", musicVolume: 0.30),
        "market_busy": .init(cue: "market", volume: 0.46, music: "market_day", musicVolume: 0.27),
        "river_calm": .init(cue: "recorded_river", volume: 0.44, music: "harvest_season", musicVolume: 0.20),
        "village_day": .init(cue: "village", volume: 0.43, music: "harvest_season", musicVolume: 0.24),
        "cave_dripping": .init(cue: "cave", volume: 0.42, music: "cave_exploration", musicVolume: 0.20),
        "ruins_windy": .init(cue: "ruins", volume: 0.44, music: "cave_exploration", musicVolume: 0.18),
        "coast_harbor": .init(cue: "coast", volume: 0.50, music: "crowded_pub", musicVolume: 0.20),
        "rain_storm": .init(cue: "rain", volume: 0.46, music: "cave_exploration", musicVolume: 0.16),
    ]

    func handle(_ event: [String: Any]) {
        guard let type = event["type"] as? String else { return }
        let volume = Self.float(event["volume"])
        switch type {
        case "ui_sound":
            if let cue = event["cue"] as? String { audio.playUISound(cue, volume: volume) }
        case "sound_effect", "creature_sound":
            if let cue = event["cue"] as? String { audio.playWorldSound(cue, volume: volume) }
        case "ambience":
            if event["action"] as? String == "stop" {
                audio.stopAmbience()
            } else if let cue = event["cue"] as? String {
                audio.playAmbience(cue, volume: volume)
            }
        case "ambience_scene":
            applyAmbienceScene(event)
        case "music":
            let action: LoopAction = event["action"] as? String == "stop" ? .stop : .play
            audio.applyMusic(
                action: action,
                cue: event["cue"] as? String,
                intensity: Self.float(event["intensity"]),
                volume: volume,
                fadeDuration: Self.double(event["fade_duration"])
            )
        case "dialogue":
            queueVoice(event)
        case "audio_control":
            if event["action"] as? String == "stop_all" { stopAll() }
        default:
            break
        }
    }

    func restore(_ state: [String: Any]) {
        if let ambience = state["ambience"] as? [String: Any] { handle(ambience) }
        if let music = state["music"] as? [String: Any] { handle(music) }
    }

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
        stopAll()
        audioCoordinator.disconnect()
        guard let channel else { return }
        self.channel = nil
        Task { await channel.disconnect() }
    }

    private func applyAmbienceScene(_ event: [String: Any]) {
        if event["action"] as? String == "stop" {
            audio.stopAmbience()
            audio.applyMusic(action: .stop, cue: nil, fadeDuration: Self.double(event["fade_duration"]))
            return
        }
        guard let id = event["profile"] as? String, let profile = Self.ambienceProfiles[id] else { return }
        audio.playAmbience(profile.cue, volume: Self.float(event["volume"]) ?? profile.volume)
        if let cue = profile.music {
            audio.applyMusic(
                action: .play,
                cue: cue,
                volume: profile.musicVolume,
                fadeDuration: Self.double(event["fade_duration"])
            )
        } else {
            audio.applyMusic(action: .stop, cue: nil)
        }
    }

    private func queueVoice(_ event: [String: Any]) {
        guard let text = event["text"] as? String, !text.isEmpty else { return }
        let previous = voiceTask
        voiceTask = Task { [weak self] in
            _ = await previous?.result
            guard !Task.isCancelled, let self else { return }
            guard let url = await self.fetchVoice(
                speakerID: event["voice_profile_id"] as? String ?? event["speaker_id"] as? String,
                text: text,
                performance: event["performance"] as? String ?? event["emotion"] as? String
            ) else { return }
            guard !Task.isCancelled else { return }
            self.audio.playVoiceFile(at: url)
            if let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 {
                let duration = Double(file.length) / file.processingFormat.sampleRate
                try? await Task.sleep(for: .seconds(duration))
            }
        }
    }

    private func fetchVoice(speakerID: String?, text: String, performance: String?) async -> URL? {
        let supported = Set(["narrator", "soren", "lupin", "wayfolio"])
        let normalized = (speakerID ?? "narrator").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let speaker = supported.contains(normalized) ? normalized : "narrator"
        guard let directorURL = URL(string: "https://wayfolio-voice-proxy-wxlq.vercel.app/api/voice-director"),
              let speechURL = URL(string: "https://wayfolio-voice-proxy-wxlq.vercel.app/api/speech") else { return nil }
        do {
            var request = URLRequest(url: directorURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "speaker": speaker,
                "text": text,
                "performance": performance ?? "neutral",
            ])
            let (directorData, directorResponse) = try await URLSession.shared.data(for: request)
            guard (directorResponse as? HTTPURLResponse)?.statusCode == 200,
                  let body = try JSONSerialization.jsonObject(with: directorData) as? [String: Any],
                  let packet = body["packet"] as? [String: Any],
                  let direction = packet["performance"] as? [String: Any] else { return nil }

            request = URLRequest(url: speechURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "speaker": speaker,
                "text": text,
                "pace": direction["pace"] as? String ?? "measured",
            ])
            let (voiceData, voiceResponse) = try await URLSession.shared.data(for: request)
            guard (voiceResponse as? HTTPURLResponse)?.statusCode == 200, !voiceData.isEmpty else { return nil }
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WayfolioVoice", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
            try voiceData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func stopAll() {
        voiceTask?.cancel()
        voiceTask = nil
        audio.stopAllPresentationAudio()
    }

    private static func float(_ value: Any?) -> Float? {
        (value as? NSNumber)?.floatValue
    }

    private static func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}
