import Foundation
import SwiftData

enum CreatureDiscoveryLevel: String, Codable, CaseIterable {
    case unknown
    case sighted
    case identified
    case studied
    case mastered

    var progress: Double {
        switch self {
        case .unknown: return 0.0
        case .sighted: return 0.25
        case .identified: return 0.5
        case .studied: return 0.75
        case .mastered: return 1.0
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    var next: CreatureDiscoveryLevel? {
        switch self {
        case .unknown: return .sighted
        case .sighted: return .identified
        case .identified: return .studied
        case .studied: return .mastered
        case .mastered: return nil
        }
    }
}

@Model
final class CreatureDiscoveryRecord {
    @Attribute(.unique) var creatureID: UUID
    var levelRawValue: String
    var updatedAt: Date

    init(
        creatureID: UUID,
        level: CreatureDiscoveryLevel = .unknown,
        updatedAt: Date = .now
    ) {
        self.creatureID = creatureID
        self.levelRawValue = level.rawValue
        self.updatedAt = updatedAt
    }

    var level: CreatureDiscoveryLevel {
        get { CreatureDiscoveryLevel(rawValue: levelRawValue) ?? .unknown }
        set {
            levelRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

@Model
final class CreatureRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var shortDescriptor: String
    var completion: Double
    var affinity: String
    var temperament: String
    var habitat: String
    var activeHours: String
    var healingUses: String
    var unknownNotes: String
    var fieldNote: String
    var assetName: String
    var fallbackSymbol: String
    var isCompanion: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "Creature",
        shortDescriptor: String,
        completion: Double,
        affinity: String,
        temperament: String,
        habitat: String,
        activeHours: String,
        healingUses: String,
        unknownNotes: String,
        fieldNote: String,
        assetName: String,
        fallbackSymbol: String,
        isCompanion: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.shortDescriptor = shortDescriptor
        self.completion = completion
        self.affinity = affinity
        self.temperament = temperament
        self.habitat = habitat
        self.activeHours = activeHours
        self.healingUses = healingUses
        self.unknownNotes = unknownNotes
        self.fieldNote = fieldNote
        self.assetName = assetName
        self.fallbackSymbol = fallbackSymbol
        self.isCompanion = isCompanion
    }
}
