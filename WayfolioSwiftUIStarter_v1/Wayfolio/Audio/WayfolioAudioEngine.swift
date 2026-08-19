import AVFoundation
import Foundation

@MainActor
final class WayfolioAudioEngine: ObservableObject {
    @Published private(set) var musicState: MusicState = .stopped
    @Published private(set) var ambienceCue: String?
    @Published private(set) var mix: [AudioBus: AudioBusMix]

    private let engine = AVAudioEngine()
    private let library: AudioResourceLibrary
    private let mixers: [AudioBus: AVAudioMixerNode]
    private let oneShotPlayers: [AudioBus: [AVAudioPlayerNode]]
    private let ambiencePlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private var fadeTasks: [AudioBus: Task<Void, Never>] = [:]

    init(library: AudioResourceLibrary = AudioResourceLibrary()) {
        self.library = library

        var initialMix: [AudioBus: AudioBusMix] = [:]
        var createdMixers: [AudioBus: AVAudioMixerNode] = [:]
        for bus in AudioBus.allCases {
            initialMix[bus] = AudioBusMix(volume: bus.defaultVolume)
            createdMixers[bus] = AVAudioMixerNode()
        }
        mix = initialMix
        mixers = createdMixers

        oneShotPlayers = [
            .voice: (0..<2).map { _ in AVAudioPlayerNode() },
            .sfx: (0..<6).map { _ in AVAudioPlayerNode() },
            .ui: (0..<4).map { _ in AVAudioPlayerNode() }
        ]

        configureGraph()
        applyMix()
    }

    func setVolume(_ volume: Float, for bus: AudioBus) {
        guard var busMix = mix[bus] else { return }
        busMix.volume = min(max(volume, 0), 1)
        mix[bus] = busMix
        applyMix(for: bus)
    }

    func setMuted(_ isMuted: Bool, for bus: AudioBus) {
        guard var busMix = mix[bus] else { return }
        busMix.isMuted = isMuted
        mix[bus] = busMix
        applyMix(for: bus)
    }

    func playUISound(_ cue: String, volume: Float? = nil) {
        playOneShot(cue, on: .ui, volume: volume)
    }

    func playWorldSound(_ cue: String, volume: Float? = nil) {
        playOneShot(cue, on: .sfx, volume: volume)
    }

    /// Existing or future voice playback can use this method without sharing
    /// effect, ambience, or music volume state.
    func playVoiceFile(at url: URL, volume: Float? = nil) {
        playFile(at: url, on: .voice, volume: volume)
    }

    func playAmbience(_ cue: String, volume: Float? = nil) {
        guard let url = library.url(for: cue, on: .ambience),
              let buffer = loopBuffer(at: url) else { return }
        startIfNeeded()
        ambiencePlayer.stop()
        ambiencePlayer.volume = normalized(volume)
        ambiencePlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        ambiencePlayer.play()
        ambienceCue = cue
    }

    func stopAmbience() {
        fadeTasks[.ambience]?.cancel()
        ambiencePlayer.stop()
        ambienceCue = nil
    }

    func applyMusic(
        action: LoopAction,
        cue: String?,
        intensity: Float? = nil,
        volume: Float? = nil,
        fadeDuration: TimeInterval? = nil
    ) {
        switch action {
        case .stop:
            fadeOutMusic(duration: fadeDuration ?? 0.4)
        case .play:
            guard let cue,
                  let url = library.url(for: cue, on: .music),
                  let buffer = loopBuffer(at: url) else { return }
            let resolvedIntensity = normalized(intensity)
            startIfNeeded()
            fadeTasks[.music]?.cancel()
            musicPlayer.stop()
            musicPlayer.volume = normalized(volume)
            musicPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            musicPlayer.play()
            musicState = .playing(cue: cue, intensity: resolvedIntensity)
        }
    }

    func stopAllPresentationAudio() {
        oneShotPlayers.values.flatMap { $0 }.forEach { $0.stop() }
        stopAmbience()
        fadeTasks.values.forEach { $0.cancel() }
        fadeTasks.removeAll()
        musicPlayer.stop()
        musicState = .stopped
    }

    private func configureGraph() {
        for mixer in mixers.values {
            engine.attach(mixer)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        }

        for (bus, players) in oneShotPlayers {
            guard let mixer = mixers[bus] else { continue }
            for player in players {
                engine.attach(player)
                engine.connect(player, to: mixer, format: nil)
            }
        }

        if let ambienceMixer = mixers[.ambience] {
            engine.attach(ambiencePlayer)
            engine.connect(ambiencePlayer, to: ambienceMixer, format: nil)
        }
        if let musicMixer = mixers[.music] {
            engine.attach(musicPlayer)
            engine.connect(musicPlayer, to: musicMixer, format: nil)
        }
    }

    private func applyMix() {
        for bus in AudioBus.allCases { applyMix(for: bus) }
    }

    private func applyMix(for bus: AudioBus) {
        guard let busMix = mix[bus] else { return }
        mixers[bus]?.outputVolume = busMix.isMuted ? 0 : busMix.volume
    }

    private func startIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
        } catch {
            // Playback commands are presentation enhancements and must never
            // interrupt the primary app flow when audio is unavailable.
        }
    }

    private func playOneShot(_ cue: String, on bus: AudioBus, volume: Float?) {
        guard let url = library.url(for: cue, on: bus) else { return }
        playFile(at: url, on: bus, volume: volume)
    }

    private func playFile(at url: URL, on bus: AudioBus, volume: Float?) {
        guard let players = oneShotPlayers[bus],
              let player = players.first(where: { !$0.isPlaying }) ?? players.first,
              let file = try? AVAudioFile(forReading: url) else { return }
        startIfNeeded()
        player.stop()
        player.volume = normalized(volume)
        player.scheduleFile(file, at: nil)
        player.play()
    }

    private func loopBuffer(at url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ) else { return nil }
        do {
            try file.read(into: buffer)
            return buffer
        } catch {
            return nil
        }
    }

    private func fadeOutMusic(duration: TimeInterval) {
        fadeTasks[.music]?.cancel()
        guard musicPlayer.isPlaying, duration > 0 else {
            musicPlayer.stop()
            musicState = .stopped
            return
        }

        let initialVolume = musicPlayer.volume
        let steps = 20
        fadeTasks[.music] = Task { [weak self] in
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
                self?.musicPlayer.volume = initialVolume * (1 - Float(step) / Float(steps))
            }
            self?.musicPlayer.stop()
            self?.musicState = .stopped
        }
    }

    private func normalized(_ value: Float?) -> Float {
        min(max(value ?? 1, 0), 1)
    }
}
