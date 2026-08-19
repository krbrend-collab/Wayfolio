import Foundation
import SwiftData

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
