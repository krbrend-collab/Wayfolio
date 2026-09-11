import SwiftUI
import SwiftData
import AVFoundation
#if os(iOS)
import UIKit
#endif

@main
struct WayfolioApp: App {
    @StateObject private var audioRuntime = WayfolioAudioRuntime()

    var body: some Scene {
        WindowGroup {
            WayfolioRootView()
                .environmentObject(audioRuntime)
        }
        .modelContainer(for: CreatureRecord.self)
    }
}

// MARK: - Semantic Audio Runtime

/// Stable semantic IDs used by gameplay and UI code. Audio files can be replaced
/// without changing the trigger contract as long as these IDs remain stable.
enum WayfolioAudioCue: String, CaseIterable, Sendable {
    // Music
    case musicLoginWayfolio = "music.login_wayfolio"
    case musicSafeVillage = "music.location.safe_village"
    case musicMarketShop = "music.location.market_shop"
    case musicTavernInn = "music.location.tavern_inn"
    case musicWildernessCalm = "music.location.wilderness_calm"
    case musicWater = "music.location.water"
    case musicSacred = "music.location.sacred"
    case musicRuinsDungeon = "music.location.ruins_dungeon"
    case musicHostile = "music.location.hostile"
    case musicSafeHaven = "music.state.safe_haven"
    case musicStoryReflection = "music.story.reflection"
    case musicCombatStandard = "music.combat.standard"
    case musicCombatBoss = "music.combat.boss"

    // Ambience
    case ambienceVillageMorning = "ambience.village.morning"
    case ambienceVillageEvening = "ambience.village.evening"
    case ambienceMarketCrowd = "ambience.market.crowd"
    case ambienceTavernRoom = "ambience.tavern.room"
    case ambienceForestDay = "ambience.forest.day"
    case ambienceForestNight = "ambience.forest.night"
    case ambienceRain = "ambience.weather.rain"
    case ambienceStream = "ambience.water.stream"
    case ambienceCave = "ambience.cave.underground"
    case ambienceShrineGarden = "ambience.shrine.garden"
    case ambienceCampfireNight = "ambience.campfire.night"

    // Wayfolio system
    case wayfolioOpen = "wayfolio.open"
    case wayfolioClose = "wayfolio.close"
    case wayfolioSelect = "wayfolio.select"
    case wayfolioConfirm = "wayfolio.confirm"
    case wayfolioLogin = "wayfolio.login"
    case wayfolioProjectionAppear = "wayfolio.projection_appear"
    case wayfolioProjectionDismiss = "wayfolio.projection_dismiss"
    case wayfolioNewRecord = "wayfolio.new_record"
    case wayfolioRecordUpdated = "wayfolio.record_updated"
    case wayfolioQuestUpdate = "wayfolio.quest_update"
    case wayfolioItemReceived = "wayfolio.item_received"
    case wayfolioConnectionEstablished = "wayfolio.connection_established"
    case wayfolioWarning = "wayfolio.warning"
    case wayfolioVisualGeneratingStart = "wayfolio.visual_generating_start"
    case wayfolioVisualGeneratingLoop = "wayfolio.visual_generating_loop"
    case wayfolioVisualGeneratingComplete = "wayfolio.visual_generating_complete"

    // Gameplay
    case gameplayDiceRoll = "gameplay.dice_roll"
    case gameplayCheckSuccess = "gameplay.check_success"
    case gameplayCheckFailure = "gameplay.check_failure"
    case gameplayInitiativeStart = "gameplay.initiative_start"
    case gameplayTurnChange = "gameplay.turn_change"
    case gameplayHealing = "gameplay.healing"
    case gameplayDamage = "gameplay.damage"
    case gameplayStatusPositive = "gameplay.status_positive"
    case gameplayStatusNegative = "gameplay.status_negative"
    case gameplayDiscovery = "gameplay.discovery"
    case gameplayObjectiveComplete = "gameplay.objective_complete"
    case gameplayChoiceAppears = "gameplay.choice_appears"
    case gameplayMapReveal = "gameplay.map_reveal"
    case gameplayStoryDiscovery = "gameplay.story_discovery"
    case gameplayCraftingComplete = "gameplay.crafting_complete"

    // Character / creature reveals
    case revealNPCFriendly = "reveal.npc.friendly"
    case revealNPCMysterious = "reveal.npc.mysterious"
    case revealCreatureCute = "reveal.creature.cute"
    case revealCreatureCuriosity = "reveal.creature.curiosity"
    case revealEntityMajestic = "reveal.entity.majestic"
    case revealEntityUncanny = "reveal.entity.uncanny"
    case revealThreatStandard = "reveal.threat.standard"
    case revealThreatBoss = "reveal.threat.boss"

    // Story / transitions
    case storyLocationArrival = "story.location_arrival"
    case storyLocationDeparture = "story.location_departure"
    case storyLandmarkDiscovery = "story.landmark_discovery"
    case storySceneTransition = "story.scene_transition"
    case storySuspenseRise = "story.suspense_rise"
    case storyDangerEscalation = "story.danger_escalation"
    case storyRevelation = "story.revelation"
    case storyResolution = "story.resolution"
    case storyRestCamp = "story.rest_camp"
    case storyQuestPhaseChange = "story.quest_phase_change"
}

enum WayfolioAudioCategory: Sendable {
    case music, ambience, system, gameplay, reveal, story
}

enum WayfolioAudioScope: Sendable {
    case sharedIPad, personalIPhone, dmPrivate, allPublic
}

enum WayfolioAudioPriority: Int, Sendable {
    case low = 0, normal = 1, high = 2, critical = 3
}

struct WayfolioAudioDefinition: Sendable {
    let cue: WayfolioAudioCue
    let fileName: String
    let category: WayfolioAudioCategory
    let scope: WayfolioAudioScope
    let priority: WayfolioAudioPriority
    let loops: Bool
}

/// Canonical app-side copy of the approved Audio Library Manifest trigger map.
/// Missing files are intentionally a safe no-op until the approved source bytes are ingested.
enum WayfolioAudioCatalog {
    static let definitions: [WayfolioAudioCue: WayfolioAudioDefinition] = {
        var map: [WayfolioAudioCue: WayfolioAudioDefinition] = [:]

        func add(_ cue: WayfolioAudioCue, _ file: String, _ category: WayfolioAudioCategory,
                 _ scope: WayfolioAudioScope, _ priority: WayfolioAudioPriority = .normal,
                 loops: Bool = false) {
            map[cue] = .init(cue: cue, fileName: file, category: category, scope: scope,
                             priority: priority, loops: loops)
        }

        // Music loops
        add(.musicLoginWayfolio, "wayfolio_music_login_wayfolio_v01.wav", .music, .sharedIPad, loops: true)
        add(.musicSafeVillage, "wayfolio_music_safe_village_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicMarketShop, "wayfolio_music_market_shop_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicTavernInn, "wayfolio_music_tavern_inn_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicWildernessCalm, "wayfolio_music_wilderness_calm_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicWater, "wayfolio_music_water_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicSacred, "wayfolio_music_sacred_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicRuinsDungeon, "wayfolio_music_ruins_dungeon_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicHostile, "wayfolio_music_hostile_v01.m4a", .music, .sharedIPad, .normal, loops: true)
        add(.musicSafeHaven, "wayfolio_music_safe_haven_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicStoryReflection, "wayfolio_music_story_reflection_v01.m4a", .music, .sharedIPad, .low, loops: true)
        add(.musicCombatStandard, "wayfolio_music_combat_standard_v01.m4a", .music, .sharedIPad, .high, loops: true)
        add(.musicCombatBoss, "wayfolio_music_combat_boss_v01.m4a", .music, .sharedIPad, .critical, loops: true)

        // Ambience beds
        add(.ambienceVillageMorning, "wayfolio_ambience_village_morning_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceVillageEvening, "wayfolio_ambience_village_evening_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceMarketCrowd, "wayfolio_ambience_market_crowd_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceTavernRoom, "wayfolio_ambience_tavern_room_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceForestDay, "wayfolio_ambience_forest_day_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceForestNight, "wayfolio_ambience_forest_night_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceRain, "wayfolio_ambience_rain_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceStream, "wayfolio_ambience_stream_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceCave, "wayfolio_ambience_cave_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceShrineGarden, "wayfolio_ambience_shrine_garden_v01.m4a", .ambience, .sharedIPad, .low, loops: true)
        add(.ambienceCampfireNight, "wayfolio_ambience_campfire_night_v01.m4a", .ambience, .sharedIPad, .low, loops: true)

        // Wayfolio system cues
        add(.wayfolioOpen, "wayfolio_ui_open_v01.wav", .system, .personalIPhone, .low)
        add(.wayfolioClose, "wayfolio_ui_close_v01.wav", .system, .personalIPhone, .low)
        add(.wayfolioSelect, "wayfolio_ui_select_v01.wav", .system, .personalIPhone, .low)
        add(.wayfolioConfirm, "wayfolio_ui_confirm_v01.wav", .system, .personalIPhone)
        add(.wayfolioLogin, "wayfolio_ui_login_crystal_chime_v01.wav", .system, .sharedIPad)
        add(.wayfolioProjectionAppear, "wayfolio_ui_projection_appear_v01.wav", .system, .allPublic)
        add(.wayfolioProjectionDismiss, "wayfolio_ui_projection_dismiss_v01.wav", .system, .allPublic, .low)
        add(.wayfolioNewRecord, "wayfolio_ui_new_record_v01.wav", .system, .allPublic, .high)
        add(.wayfolioRecordUpdated, "wayfolio_ui_record_updated_v01.wav", .system, .allPublic)
        add(.wayfolioQuestUpdate, "wayfolio_ui_quest_update_v01.wav", .system, .allPublic, .high)
        add(.wayfolioItemReceived, "wayfolio_ui_item_received_v01.wav", .system, .allPublic)
        add(.wayfolioConnectionEstablished, "wayfolio_ui_connection_established_v01.wav", .system, .allPublic, .high)
        add(.wayfolioWarning, "wayfolio_ui_warning_v01.wav", .system, .allPublic, .critical)
        add(.wayfolioVisualGeneratingStart, "wayfolio_ui_visual_generating_start_v01.wav", .system, .allPublic)
        add(.wayfolioVisualGeneratingLoop, "wayfolio_ui_visual_generating_loop_v01.wav", .system, .allPublic, .low, loops: true)
        add(.wayfolioVisualGeneratingComplete, "wayfolio_ui_visual_generating_complete_v01.wav", .system, .allPublic, .high)

        // Gameplay cues
        add(.gameplayDiceRoll, "wayfolio_gameplay_dice_roll_v01.wav", .gameplay, .sharedIPad)
        add(.gameplayCheckSuccess, "wayfolio_gameplay_check_success_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayCheckFailure, "wayfolio_gameplay_check_failure_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayInitiativeStart, "wayfolio_gameplay_initiative_start_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayTurnChange, "wayfolio_gameplay_turn_change_v01.wav", .gameplay, .sharedIPad)
        add(.gameplayHealing, "wayfolio_gameplay_healing_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayDamage, "wayfolio_gameplay_damage_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayStatusPositive, "wayfolio_gameplay_status_positive_v01.wav", .gameplay, .sharedIPad)
        add(.gameplayStatusNegative, "wayfolio_gameplay_status_negative_v01.wav", .gameplay, .sharedIPad)
        add(.gameplayDiscovery, "wayfolio_gameplay_discovery_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayObjectiveComplete, "wayfolio_gameplay_objective_complete_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayChoiceAppears, "wayfolio_gameplay_choice_appears_v01.wav", .gameplay, .sharedIPad)
        add(.gameplayMapReveal, "wayfolio_gameplay_map_reveal_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayStoryDiscovery, "wayfolio_gameplay_story_discovery_v01.wav", .gameplay, .sharedIPad, .high)
        add(.gameplayCraftingComplete, "wayfolio_gameplay_crafting_complete_v01.wav", .gameplay, .personalIPhone)

        // Reusable reveal stingers
        add(.revealNPCFriendly, "wayfolio_reveal_npc_friendly_v01.wav", .reveal, .sharedIPad)
        add(.revealNPCMysterious, "wayfolio_reveal_npc_mysterious_v01.wav", .reveal, .sharedIPad, .high)
        add(.revealCreatureCute, "wayfolio_reveal_creature_cute_v01.wav", .reveal, .sharedIPad)
        add(.revealCreatureCuriosity, "wayfolio_reveal_creature_curiosity_v01.wav", .reveal, .sharedIPad)
        add(.revealEntityMajestic, "wayfolio_reveal_entity_majestic_v01.wav", .reveal, .sharedIPad, .high)
        add(.revealEntityUncanny, "wayfolio_reveal_entity_uncanny_v01.wav", .reveal, .sharedIPad, .high)
        add(.revealThreatStandard, "wayfolio_reveal_threat_standard_v01.wav", .reveal, .sharedIPad, .high)
        add(.revealThreatBoss, "wayfolio_reveal_threat_boss_v01.wav", .reveal, .sharedIPad, .critical)

        // Story/location stingers
        add(.storyLocationArrival, "wayfolio_story_location_arrival_v01.wav", .story, .sharedIPad)
        add(.storyLocationDeparture, "wayfolio_story_location_departure_v01.wav", .story, .sharedIPad, .low)
        add(.storyLandmarkDiscovery, "wayfolio_story_landmark_discovery_v01.wav", .story, .sharedIPad, .high)
        add(.storySceneTransition, "wayfolio_story_scene_transition_v01.wav", .story, .sharedIPad)
        add(.storySuspenseRise, "wayfolio_story_suspense_rise_v01.wav", .story, .sharedIPad, .high)
        add(.storyDangerEscalation, "wayfolio_story_danger_escalation_v01.wav", .story, .sharedIPad, .high)
        add(.storyRevelation, "wayfolio_story_revelation_v01.wav", .story, .sharedIPad, .high)
        add(.storyResolution, "wayfolio_story_resolution_v01.wav", .story, .sharedIPad, .high)
        add(.storyRestCamp, "wayfolio_story_rest_camp_v01.wav", .story, .sharedIPad)
        add(.storyQuestPhaseChange, "wayfolio_story_quest_phase_change_v01.wav", .story, .sharedIPad, .high)

        precondition(map.count == WayfolioAudioCue.allCases.count, "Every semantic cue must have exactly one audio definition")
        return map
    }()
}

extension Notification.Name {
    static let wayfolioSemanticAudioEvent = Notification.Name("Wayfolio.SemanticAudioEvent")
}

/// Runtime-independent trigger bridge. The AI storyteller, local gameplay runtime,
/// UI, or sync layer can emit the stable semantic ID without knowing the filename.
enum WayfolioAudioTrigger {
    static let semanticIDKey = "semanticCue"

    static func emit(_ cue: WayfolioAudioCue) {
        emit(semanticID: cue.rawValue)
    }

    static func emit(semanticID: String) {
        NotificationCenter.default.post(
            name: .wayfolioSemanticAudioEvent,
            object: nil,
            userInfo: [semanticIDKey: semanticID]
        )
    }
}

final class WayfolioAudioRuntime: NSObject, ObservableObject {
    @Published private(set) var currentMusic: WayfolioAudioCue?
    @Published private(set) var currentAmbience: WayfolioAudioCue?

    private var players: [WayfolioAudioCue: AVAudioPlayer] = [:]
    private var semanticObserver: NSObjectProtocol?

    override init() {
        super.init()
        configureAudioSession()
        semanticObserver = NotificationCenter.default.addObserver(
            forName: .wayfolioSemanticAudioEvent,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let semanticID = note.userInfo?[WayfolioAudioTrigger.semanticIDKey] as? String else { return }
            self?.play(semanticID: semanticID)
        }
    }

    deinit {
        if let semanticObserver {
            NotificationCenter.default.removeObserver(semanticObserver)
        }
    }

    func play(_ cue: WayfolioAudioCue) {
        guard let definition = WayfolioAudioCatalog.definitions[cue] else { return }
        guard shouldPlay(scope: definition.scope) else { return }
        guard let url = assetURL(for: definition.fileName) else {
            // Expected until the approved audio source bytes are ingested into the app bundle.
            #if DEBUG
            print("[WayfolioAudio] Trigger received but asset is not bundled yet: \(cue.rawValue) -> \(definition.fileName)")
            #endif
            return
        }

        do {
            if definition.category == .music {
                stopCurrentMusic(except: cue)
            } else if definition.category == .ambience {
                stopCurrentAmbience(except: cue)
            }

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = definition.loops ? -1 : 0
            player.volume = defaultVolume(for: definition.category)
            player.prepareToPlay()
            players[cue] = player

            if definition.category == .music { currentMusic = cue }
            if definition.category == .ambience { currentAmbience = cue }

            player.play()
            duckBackgroundIfNeeded(for: definition, transientPlayer: player)
        } catch {
            #if DEBUG
            print("[WayfolioAudio] Could not play \(cue.rawValue): \(error.localizedDescription)")
            #endif
        }
    }

    func play(semanticID: String) {
        guard let cue = WayfolioAudioCue(rawValue: semanticID) else {
            #if DEBUG
            print("[WayfolioAudio] Unknown semantic cue: \(semanticID)")
            #endif
            return
        }
        play(cue)
    }

    /// Sets the two long-running baseline layers for the current story state.
    /// Passing nil leaves that layer unchanged; use stopMusic/stopAmbience to clear it.
    func applyScene(music: WayfolioAudioCue? = nil, ambience: WayfolioAudioCue? = nil) {
        if let music { play(music) }
        if let ambience { play(ambience) }
    }

    func stop(_ cue: WayfolioAudioCue, fadeDuration: TimeInterval = 0.25) {
        guard let player = players[cue] else { return }
        player.setVolume(0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak self, weak player] in
            player?.stop()
            self?.players[cue] = nil
            if self?.currentMusic == cue { self?.currentMusic = nil }
            if self?.currentAmbience == cue { self?.currentAmbience = nil }
        }
    }

    func stopMusic() {
        if let currentMusic { stop(currentMusic) }
    }

    func stopAmbience() {
        if let currentAmbience { stop(currentAmbience) }
    }

    private func stopCurrentMusic(except cue: WayfolioAudioCue) {
        if let currentMusic, currentMusic != cue { stop(currentMusic, fadeDuration: 0.45) }
    }

    private func stopCurrentAmbience(except cue: WayfolioAudioCue) {
        if let currentAmbience, currentAmbience != cue { stop(currentAmbience, fadeDuration: 0.45) }
    }

    private func duckBackgroundIfNeeded(for definition: WayfolioAudioDefinition, transientPlayer: AVAudioPlayer) {
        guard definition.category == .reveal || definition.category == .story || definition.priority == .critical else { return }

        let music = currentMusic.flatMap { players[$0] }
        let ambience = currentAmbience.flatMap { players[$0] }
        let musicVolume = music?.volume
        let ambienceVolume = ambience?.volume

        music?.setVolume(0.12, fadeDuration: 0.08)
        ambience?.setVolume(0.12, fadeDuration: 0.08)

        let restoreDelay = max(0.25, transientPlayer.duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            if let musicVolume { music?.setVolume(musicVolume, fadeDuration: 0.18) }
            if let ambienceVolume { ambience?.setVolume(ambienceVolume, fadeDuration: 0.18) }
        }
    }

    private func defaultVolume(for category: WayfolioAudioCategory) -> Float {
        switch category {
        case .music: return 0.34
        case .ambience: return 0.28
        case .system: return 0.62
        case .gameplay: return 0.68
        case .reveal: return 0.72
        case .story: return 0.68
        }
    }

    private func assetURL(for fileName: String) -> URL? {
        let nsName = fileName as NSString
        let ext = nsName.pathExtension
        let base = nsName.deletingPathExtension
        let subdirectories = [
            nil,
            "Audio",
            "Audio/01 Music Loops",
            "Audio/02 Ambience Beds",
            "Audio/03 Wayfolio System Cues",
            "Audio/04 Gameplay & Encounter SFX",
            "Audio/05 Character, Creature & Reveal Stingers",
            "Audio/06 Story, Location & Transition Stingers"
        ] as [String?]

        for subdirectory in subdirectories {
            if let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }

    private func shouldPlay(scope: WayfolioAudioScope) -> Bool {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            // The shared iPad is the primary public table output. This also prevents
            // all-public cues from being duplicated across every player's phone.
            return scope == .sharedIPad || scope == .allPublic
        case .phone:
            return scope == .personalIPhone
        default:
            return scope == .personalIPhone
        }
        #else
        return scope == .dmPrivate
        #endif
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[WayfolioAudio] Audio session setup failed: \(error.localizedDescription)")
            #endif
        }
        #endif
    }
}
