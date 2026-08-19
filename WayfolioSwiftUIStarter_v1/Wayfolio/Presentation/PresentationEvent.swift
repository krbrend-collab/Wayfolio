import Foundation

/// Commands received from the DM are deliberately limited to presentation.
/// Campaign and gameplay state are not represented in this protocol.
struct PresentationEvent: Decodable, Identifiable, Sendable {
    let id: UUID
    let sequence: Int?
    let sentAt: Date?
    let command: PresentationCommand

    private enum CodingKeys: String, CodingKey {
        case id
        case sequence
        case sentAt = "sent_at"
        case type
        case cue
        case volume
        case action
        case intensity
        case fadeDuration = "fade_duration"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sequence = try values.decodeIfPresent(Int.self, forKey: .sequence)
        sentAt = try values.decodeIfPresent(Date.self, forKey: .sentAt)

        let type = try values.decode(EventType.self, forKey: .type)
        let cue = try values.decodeIfPresent(String.self, forKey: .cue)
        let volume = try values.decodeIfPresent(Float.self, forKey: .volume)

        switch type {
        case .uiSound:
            command = .uiOneShot(try Self.requiredCue(cue, type: type), volume: volume)
        case .soundEffect:
            command = .worldOneShot(try Self.requiredCue(cue, type: type), volume: volume)
        case .creatureSound:
            command = .worldOneShot(try Self.requiredCue(cue, type: type), volume: volume)
        case .ambience:
            let action = try values.decodeIfPresent(LoopAction.self, forKey: .action) ?? .play
            command = .ambience(action: action, cue: cue, volume: volume)
        case .music:
            let action = try values.decodeIfPresent(LoopAction.self, forKey: .action) ?? .play
            let intensity = try values.decodeIfPresent(Float.self, forKey: .intensity)
            let fadeDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .fadeDuration)
            command = .music(action: action, cue: cue, intensity: intensity, volume: volume, fadeDuration: fadeDuration)
        }
    }

    private static func requiredCue(_ cue: String?, type: EventType) throws -> String {
        guard let cue, !cue.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "A cue is required for \(type.rawValue)")
            )
        }
        return cue
    }
}

extension PresentationEvent {
    enum EventType: String, Decodable, Sendable {
        case uiSound = "ui_sound"
        case soundEffect = "sound_effect"
        case creatureSound = "creature_sound"
        case ambience
        case music
    }
}

enum LoopAction: String, Decodable, Sendable {
    case play
    case stop
}

enum PresentationCommand: Sendable {
    case uiOneShot(String, volume: Float?)
    case worldOneShot(String, volume: Float?)
    case ambience(action: LoopAction, cue: String?, volume: Float?)
    case music(action: LoopAction, cue: String?, intensity: Float?, volume: Float?, fadeDuration: TimeInterval?)
}
