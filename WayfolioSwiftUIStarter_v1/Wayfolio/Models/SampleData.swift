import Foundation

enum SampleData {
    static let tubelumeID = UUID(uuidString: "A1B2C3D4-E5F6-47A8-9B0C-D1E2F3A4B5C6")!

    static func initialDiscoveryLevel(for creature: CreatureRecord) -> CreatureDiscoveryLevel {
        creature.name == "Tubelume" ? .sighted : .studied
    }

    static var creatures: [CreatureRecord] {
        [
            CreatureRecord(
                id: tubelumeID,
                name: "Tubelume",
                category: "Creature",
                shortDescriptor: "Will-o'-Wisp Companion Spirit",
                completion: 0.25,
                affinity: "Spirit light, warm emotion, and gentle air currents.",
                temperament: "Curious, affectionate, and wary around sudden noise. It prefers to approach on its own terms.",
                habitat: "Lantern paths, shrine approaches, old inns, and quiet woodland clearings.",
                activeHours: "Most active from twilight through the night.",
                healingUses: "No confirmed medicinal harvest. Its calm hovering presence may have a soothing effect on nearby companions.",
                unknownNotes: "Long-range migration, mature bonding behavior, and deeper spirit ecology remain unconfirmed.",
                fieldNote: "A long-bodied spirit observed flying in looping ribbon paths, trailing a soft will-o'-wisp glow as it turns.",
                assetName: "",
                fallbackSymbol: "sparkles",
                isCompanion: true
            ),
            CreatureRecord(
                name: "Mossglow Sprinter",
                shortDescriptor: "Verdant Creature",
                completion: 0.43,
                affinity: "Verdancy attuned; a faint water presence is also detected.",
                temperament: "Curious, fleet, and shy. It avoids conflict when an escape path is available.",
                habitat: "Mossy woodlands, rooted valleys, and shaded glens.",
                activeHours: "Most active from dawnspring through twilight.",
                healingUses: "Luminous moss may have restorative properties; analysis remains incomplete.",
                unknownNotes: "Several behavioral and ecological details remain unconfirmed.",
                fieldNote: "Luminous moss along the spine. Moves like wind through soft places; almost seen, then gone.",
                assetName: "mossglow",
                fallbackSymbol: "hare.fill"
            ),
            CreatureRecord(
                name: "Lanternshell Tortoise",
                shortDescriptor: "Patient Guardian",
                completion: 0.52,
                affinity: "Earth, stillness, and gentle warmth.",
                temperament: "Calm, observant, and defensive. Rarely aggressive.",
                habitat: "Fern terraces, warm stones, and old woodland paths.",
                activeHours: "Late morning to dusk.",
                healingUses: "Shell moss paste may ease fatigue and soothe sore joints.",
                unknownNotes: "Lantern fungi on the shell may brighten during moonrise.",
                fieldNote: "Often found basking beside warm stones. Withdraws when startled, then slowly returns.",
                assetName: "lanternshell",
                fallbackSymbol: "tortoise.fill"
            ),
            CreatureRecord(
                name: "Brookwhistle Axolotl",
                shortDescriptor: "Freshwater Familiar",
                completion: 0.61,
                affinity: "Clear water, soft resonance, and cool mineral light.",
                temperament: "Gentle and social near quiet pools.",
                habitat: "Spring-fed streams and luminous freshwater caves.",
                activeHours: "Dawn and evening.",
                healingUses: "Gill secretions may be useful in cooling preparations.",
                unknownNotes: "The purpose of its tonal whistle remains uncertain.",
                fieldNote: "Its call carries farther through water than through air.",
                assetName: "",
                fallbackSymbol: "drop.fill",
                isCompanion: true
            ),
            CreatureRecord(
                name: "Petalwing Mothfox",
                shortDescriptor: "Twilight Pollinator",
                completion: 0.37,
                affinity: "Moonlight, petals, and airborne pollen.",
                temperament: "Graceful and cautious; approaches fragrant gardens.",
                habitat: "Flowering forest edges and moonlit clearings.",
                activeHours: "Twilight through early night.",
                healingUses: "Wing-dusted pollen may have calming uses.",
                unknownNotes: "Migration routes are not yet mapped.",
                fieldNote: "Never lands on the same flower twice in succession.",
                assetName: "",
                fallbackSymbol: "butterfly.fill"
            )
        ]
    }
}
