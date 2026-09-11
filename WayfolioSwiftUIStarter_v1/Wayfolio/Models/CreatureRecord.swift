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
    var armorClass: String = "Unknown"
    var hitPoints: String = "Unknown"
    var speed: String = "Unknown"
    var challengeRating: String = "Unknown"
    var abilities: String = "Unknown"
    var mainActivities: String = "Unknown"
    var signatureResponse: String = "Unknown"
    var soundCue: String = "creature_beast_alert"

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
        isCompanion: Bool = false,
        armorClass: String = "Unknown",
        hitPoints: String = "Unknown",
        speed: String = "Unknown",
        challengeRating: String = "Unknown",
        abilities: String = "Unknown",
        mainActivities: String = "Unknown",
        signatureResponse: String = "Unknown",
        soundCue: String = "creature_beast_alert"
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
        self.armorClass = armorClass
        self.hitPoints = hitPoints
        self.speed = speed
        self.challengeRating = challengeRating
        self.abilities = abilities
        self.mainActivities = mainActivities
        self.signatureResponse = signatureResponse
        self.soundCue = soundCue
    }
}
