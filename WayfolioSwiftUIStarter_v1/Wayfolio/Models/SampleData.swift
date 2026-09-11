import Foundation

enum SampleData {
    static let creatureSeedVersion = 3

    static var creatures: [CreatureRecord] {
        [
            CreatureRecord(
                name: "Crown Hare", shortDescriptor: "Crested Mineral-Root Forager", completion: 0.20,
                affinity: "Not yet recorded.", temperament: "Wary.", habitat: "A disturbed mineral-root bed near Hemlock.",
                activeHours: "Not yet recorded.", healingUses: "No safe use established.",
                unknownNotes: "Movement, defenses, and the function of its keratin crest remain under study.",
                fieldNote: "Compact hare. A broad forehead crest leaves digging marks in mineral-rich soil.",
                assetName: "crown-hare", fallbackSymbol: "hare.fill", isCompanion: true,
                armorClass: "14", hitPoints: "9 average", speed: "45 ft.", challengeRating: "1/4",
                abilities: "STR 6 · DEX 18 · CON 11 · INT 2 · WIS 14 · CHA 11",
                mainActivities: "Dig mineral roots; court and display.",
                signatureResponse: "Crest Ram — the integrated keratin skull crest supports digging and impact.",
                soundCue: "creature_small_timid_startle"
            ),
            CreatureRecord(
                name: "Gloam Hound", shortDescriptor: "Twilight Pack Predator", completion: 0.45,
                affinity: "Twilight, pursuit, and coordinated movement.",
                temperament: "Aggressive predator; behavior is ecological rather than moral.",
                habitat: "Forest margins and low-light hunting corridors.", activeHours: "Twilight and night.",
                healingUses: "None established.", unknownNotes: "Full pack signals and defensive limits remain unknown.",
                fieldNote: "Large low-light eyes and flank-sensitive ears. Individuals turn as if reading the whole pack.",
                assetName: "gloam-hound", fallbackSymbol: "pawprint.fill",
                armorClass: "15", hitPoints: "40 average", speed: "50 ft.", challengeRating: "1",
                abilities: "STR 15 · DEX 17 · CON 15 · INT 5 · WIS 16 · CHA 11",
                mainActivities: "Pack patrol; twilight hunting.",
                signatureResponse: "Flank Bite — low-running anatomy supports coordinated pack movement.",
                soundCue: "creature_large_predator_warning"
            ),
            CreatureRecord(
                name: "Coppice Goblin", shortDescriptor: "Woodland Tool-User", completion: 0.70,
                affinity: "Woodland materials, salvage, craft, and practical exchange.",
                temperament: "Usually friendly or wary; never inherently evil.",
                habitat: "Coppices, canopy routes, scavenging grounds, and small woodland settlements.",
                activeHours: "Daylight into early evening.", healingUses: "May trade useful herbs and crafted field supplies.",
                unknownNotes: "Local customs, individual loyalties, and settlement routes require respectful observation.",
                fieldNote: "Compact climbing build, clever hands, and simple gear assembled from scavenged natural materials.",
                assetName: "coppice-goblin", fallbackSymbol: "figure.hiking",
                armorClass: "14", hitPoints: "22 average", speed: "30 ft.", challengeRating: "1/2",
                abilities: "STR 10 · DEX 15 · CON 12 · INT 11 · WIS 13 · CHA 12",
                mainActivities: "Salvage and build; forage and trade.",
                signatureResponse: "Snare Toss — large dexterous hands and a climbing body support practical tool use.",
                soundCue: "recorded_monster_growl_01"
            ),
            CreatureRecord(
                name: "Mimic Slime", shortDescriptor: "Imperfect Gelatinous Imitator", completion: 0.96,
                affinity: "Residue, imitation, and elastic transformation.",
                temperament: "Curious or wary; potentially comic, puzzling, or dangerous.",
                habitat: "Places rich in discarded objects, residue, and observed shapes.",
                activeHours: "Activity follows opportunity rather than a fixed daily cycle.",
                healingUses: "No safe medicinal harvesting protocol established.",
                unknownNotes: "Long-term memory and the limits of companion bonding remain unconfirmed.",
                fieldNote: "Copies objects and small creatures, but every imitation remains visibly soft, gelatinous, and imperfect.",
                assetName: "mimic-slime", fallbackSymbol: "drop.fill", isCompanion: true,
                armorClass: "13", hitPoints: "38 average", speed: "25 ft.", challengeRating: "1",
                abilities: "STR 14 · DEX 10 · CON 16 · INT 6 · WIS 12 · CHA 13",
                mainActivities: "Copy encountered shapes; scavenge residue.",
                signatureResponse: "Adhesive Copy — its silhouette changes while its gelatinous material remains unmistakable.",
                soundCue: "creature_slime_curious_move"
            )
        ]
    }
}
