import Foundation

@MainActor
final class GameSessionClient: ObservableObject {
    enum ReactionMode: String, CaseIterable, Equatable {
        case ask = "ASK"
        case automatic = "AUTOMATIC"
        case off = "OFF"
    }
    enum PlayMode: String, Equatable {
        case iPhoneOnly = "iphone_only"
        case iPhoneSharedIPad = "iphone_shared_ipad"
    }
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(code: String)
        case failed(String)
    }

    struct Prompt: Identifiable, Equatable, Codable {
        let id: String
        let title: String
        let message: String
        let choices: [String]
        let allowsFreeform: Bool
    }

    struct CheckResult: Equatable, Codable {
        let title: String
        let detail: String
        let succeeded: Bool
    }

    struct GameAction: Identifiable, Equatable, Codable {
        let id: String
        let text: String
        let visibility: String
        let author: String
    }

    struct DialoguePresentation: Identifiable, Equatable, Codable {
        let id: String
        let speakerID: String
        let speakerName: String
        let text: String
        let performance: String?
    }

    struct VisualPresentation: Identifiable, Equatable, Codable {
        let id: String
        let title: String
        let path: String
        let revision: String?
    }

    struct PendingRoll: Identifiable, Equatable, Codable {
        let id: String
        let playerID: String
        let playerName: String
        let skill: String
        let modifier: Int
        let difficulty: Int?
        let dieType: Int
        let diceCount: Int
        let selection: String?

        var requiredDiceCount: Int {
            selection == "advantage" || selection == "disadvantage" ? 2 : max(1, diceCount)
        }
    }

    struct Encounter: Equatable {
        struct Combatant: Identifiable, Equatable {
            let id: String; let name: String; let kind: String
            let hp: Int; let maximumHP: Int; let hpVisible: Bool; let publicStatus: String
            let conditions: [String]
        }
        let name: String; let status: String; let outcome: String?; let round: Int
        let activeCombatantID: String?; let combatants: [Combatant]
    }

    struct CharacterSummary: Equatable, Codable {
        struct EquipmentItem: Equatable, Codable {
            let slot: String
            let name: String
            let detail: String
            let qualityLevel: Int?
            let family: String?

            init(slot: String, name: String, detail: String, qualityLevel: Int? = nil, family: String? = nil) {
                self.slot = slot
                self.name = name
                self.detail = detail
                self.qualityLevel = qualityLevel.map { min(5, max(1, $0)) }
                self.family = family
            }
        }
        let name: String
        let species: String
        let className: String
        let level: Int
        let background: String
        let hp: Int
        let maximumHP: Int
        let armorClass: Int
        let initiative: Int
        let abilities: [String: Int]
        let skills: [String: Int]
        let magic: [String]
        let traits: [String]
        let equipment: [EquipmentItem]
        let resources: [String: Int]
        let resourceLimits: [String: Int]
    }

    struct CharacterOption: Identifiable, Equatable {
        let id: String
        let name: String
        let species: String
        let className: String
        let assigned: Bool
    }

    struct KnowledgeRecord: Identifiable, Equatable {
        let id: String
        let kind: String
        let name: String
        let status: String
        let notes: [String]
        let updatedAt: String?
        let knowledgeScope: String
        let ownerCharacterID: String?
        let relevance: Int
    }

    struct NarrativeMoment: Identifiable, Equatable {
        let id: String
        let presentation: String
        let tone: String?
        let knowledgeScope: String
    }

    struct ContextualAffordance: Identifiable, Equatable {
        let id: String
        let kind: String
        let label: String
        let relevance: Int
    }

    struct ExperimentRecord: Identifiable, Equatable {
        let id: String
        let question: String
        let status: String
        let samples: [String]
    }

    struct ImportedCharacter: Equatable {
        let id: String
        let name: String
        let species: String
        let className: String
        let level: Int
    }

    struct CharacterVisualReference: Identifiable, Equatable {
        let id = UUID()
        let filename: String
        let mimeType: String
        let role: String
        let data: Data
    }

    struct CharacterSupportingDocument: Identifiable, Equatable {
        let id = UUID()
        let filename: String
        let mimeType: String
        var visibility: String
        let data: Data
    }

    struct InventoryItem: Identifiable, Equatable, Codable {
        struct MechanicalDelta: Identifiable, Equatable, Codable {
            let id: String
            let label: String
            let value: String
            let direction: String
        }

        let id: String
        let name: String
        let quantity: Int
        let category: String?
        let artAssetName: String?
        let artURL: String?
        let consumable: Bool
        let mechanicalDeltas: [MechanicalDelta]
        let equippedSlot: String?
        let comparedToItemID: String?
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var sceneTitle = "Waiting for the adventure"
    @Published private(set) var sceneText = "Join the central game to connect this Wayfolio."
    @Published private(set) var currentLocation = "Location unknown"
    @Published private(set) var timeOfDay: String?
    @Published private(set) var weather: String?
    @Published private(set) var prompt: Prompt?
    @Published private(set) var checkResult: CheckResult?
    @Published private(set) var awaitingSharedRoll = false
    @Published private(set) var character: CharacterSummary?
    @Published private(set) var inventory: [String] = []
    @Published private(set) var inventoryItems: [InventoryItem] = []
    @Published private(set) var secondaryResourceSummary: String?
    @Published private(set) var discoveries: [String] = []
    @Published private(set) var journal: [String] = []
    @Published private(set) var knownLocations: [KnowledgeRecord] = []
    @Published private(set) var knownPeople: [KnowledgeRecord] = []
    @Published private(set) var knownCreatures: [KnowledgeRecord] = []
    @Published private(set) var companions: [KnowledgeRecord] = []
    @Published private(set) var botanicals: [KnowledgeRecord] = []
    @Published private(set) var recipes: [KnowledgeRecord] = []
    @Published private(set) var experiments: [ExperimentRecord] = []
    @Published private(set) var pendingThreads: [String] = []
    @Published private(set) var completedWork: [String] = []
    @Published private(set) var knowledgeRecords: [KnowledgeRecord] = []
    @Published private(set) var reactionPolicies: [String: ReactionMode] = [:]
    @Published private(set) var narrativeMoments: [NarrativeMoment] = []
    @Published private(set) var contextualAffordances: [ContextualAffordance] = []
    @Published private(set) var actions: [GameAction] = []
    @Published private(set) var encounter: Encounter?
    @Published private(set) var dialoguePresentation: DialoguePresentation?
    @Published private(set) var visualPresentation: VisualPresentation?
    @Published private(set) var pendingRoll: PendingRoll?
    @Published private(set) var transferCode: String?
    @Published private(set) var notice: String?
    @Published private(set) var playMode: PlayMode = .iPhoneSharedIPad
    @Published private(set) var sharedIPadConnected = false
    @Published private(set) var preferredPlayMode: PlayMode = .iPhoneSharedIPad
    @Published private(set) var isStandaloneSession = false
    @Published private(set) var characterCatalog: [CharacterOption] = [
        .init(id: "renn", name: "Renn", species: "Harengon", className: "Ranger", assigned: false),
        .init(id: "yugen", name: "Yūgen", species: "Kitsune / Yōkai-Blooded", className: "Warlock", assigned: false)
    ]
    @Published var selectedCharacterID: String

    /// Presentation rides the authenticated game connection so an iPhone-only
    /// session cannot drift onto a second, unjoined WebSocket.
    var presentationEventHandler: (([String: Any]) -> Void)?
    var presentationStateHandler: (([String: Any]) -> Void)?

    var playerID: String { selectedCharacterID }
    var playerName: String {
        characterCatalog.first(where: { $0.id == selectedCharacterID })?.name ?? selectedCharacterID
    }

    private let deviceID: String
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var lastHost = ""
    private var lastCode = ""
    private var reconnectAttempt = 0
    private var intentionallyDisconnected = true
    private var pendingActionMessages: [String: [String: String]] = [:]
    private var pendingActionRetryTasks: [String: Task<Void, Never>] = [:]
    private var pendingItemUseMessages: [String: [String: String]] = [:]
    private var pendingItemUseRetryTasks: [String: Task<Void, Never>] = [:]
    private var standaloneStoryStep = 0

    /// Durable canonical state for play that is owned by this iPhone rather than
    /// by a WebSocket transport. Presentation devices may observe this state,
    /// but their absence never blocks play or restoration.
    private struct StandaloneSnapshot: Codable {
        let schemaVersion: Int
        let characterID: String
        let sceneTitle: String
        let sceneText: String
        let currentLocation: String
        let timeOfDay: String?
        let weather: String?
        let character: CharacterSummary
        let inventoryItems: [InventoryItem]
        let discoveries: [String]
        let journal: [String]
        let actions: [GameAction]
        let prompt: Prompt?
        let checkResult: CheckResult?
        let dialogue: DialoguePresentation?
        let visual: VisualPresentation?
        let pendingRoll: PendingRoll?
        let storyStep: Int
    }

    init() {
        let defaults = UserDefaults.standard
#if DEBUG
        // Recovery switch for a development device whose saved shared-table
        // session cannot be exited because its previous shell is nonresponsive.
        // Launching once with this argument preserves campaign snapshots while
        // making the phone-owned runtime the persisted active session.
        if ProcessInfo.processInfo.arguments.contains("-WayfolioForceStandalone") {
            defaults.set(PlayMode.iPhoneOnly.rawValue, forKey: "wayfolio.session.play-mode")
            defaults.set("renn", forKey: "wayfolio.character.id")
            defaults.set(true, forKey: "wayfolio.session.active")
        }
#endif
        preferredPlayMode = PlayMode(rawValue: defaults.string(forKey: "wayfolio.session.play-mode") ?? "")
            ?? .iPhoneSharedIPad
        let savedCharacterID = defaults.string(forKey: "wayfolio.character.id") ?? "renn"
        selectedCharacterID = savedCharacterID == "yu-gen" ? "yugen" : savedCharacterID
        if savedCharacterID == "yu-gen" { defaults.set("yugen", forKey: "wayfolio.character.id") }
        if let saved = defaults.string(forKey: "wayfolio.device.id") {
            deviceID = saved
        } else {
            let created = UUID().uuidString
            defaults.set(created, forKey: "wayfolio.device.id")
            deviceID = created
        }
        playMode = preferredPlayMode
        if defaults.bool(forKey: "wayfolio.session.active"), preferredPlayMode == .iPhoneOnly {
            Task { [weak self] in
                await Task.yield()
                self?.startStandaloneSession()
            }
        } else if defaults.bool(forKey: "wayfolio.session.active"),
                  let host = defaults.string(forKey: "wayfolio.session.host"),
                  let code = defaults.string(forKey: "wayfolio.session.code") {
            Task { [weak self] in
                await Task.yield()
                self?.connect(host: host, code: code)
            }
        }
    }

    func connect(host: String, code: String, transferCode: String? = nil) {
        closeConnection()
        isStandaloneSession = false
        guard let url = Self.webSocketURL(from: host) else {
            state = .failed("Enter the host address shown on the shared screen.")
            return
        }

        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else {
            state = .failed("Enter the session code.")
            return
        }

        lastHost = host
        lastCode = normalizedCode
        intentionallyDisconnected = false
        let defaults = UserDefaults.standard
        defaults.set(host, forKey: "wayfolio.session.host")
        defaults.set(normalizedCode, forKey: "wayfolio.session.code")
        defaults.set(true, forKey: "wayfolio.session.active")
        defaults.set(selectedCharacterID, forKey: "wayfolio.character.id")
        state = .connecting
        let socket = URLSession.shared.webSocketTask(with: url)
        self.socket = socket
        socket.resume()

        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                var join = [
                    "type": "join",
                    "role": "wayfolio",
                    "session_code": normalizedCode,
                    "player_id": self.playerID,
                    "player_name": self.playerName,
                    "character_id": self.playerID,
                    "device_id": self.deviceID,
                    "play_mode": self.preferredPlayMode.rawValue
                ]
                if let token = UserDefaults.standard.string(forKey: "wayfolio.session.resume-token.\(self.playerID)")
                    ?? UserDefaults.standard.string(forKey: "wayfolio.session.resume-token") {
                    join["resume_token"] = token
                }
                if let transferCode, !transferCode.isEmpty { join["transfer_code"] = transferCode }
                try await self.send(join)
                while !Task.isCancelled {
                    let message = try await socket.receive()
                    let data: Data
                    switch message {
                    case .data(let value): data = value
                    case .string(let value): data = Data(value.utf8)
                    @unknown default: continue
                    }
                    self.handle(data, expectedCode: normalizedCode)
                }
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled && !self.intentionallyDisconnected {
                    self.state = .failed("Connection interrupted. Rejoining automatically…")
                    self.scheduleReconnect()
                }
            }
        }
    }

    /// Starts or restores the canonical campaign runtime on this phone. This is
    /// intentionally independent of the table WebSocket: an iPad or Mac may be
    /// attached later as a presentation sink, but is not a gameplay authority.
    func startStandaloneSession() {
        intentionallyDisconnected = true
        closeConnection()
        preferredPlayMode = .iPhoneOnly
        playMode = .iPhoneOnly
        sharedIPadConnected = false
        isStandaloneSession = true

        let defaults = UserDefaults.standard
        defaults.set(PlayMode.iPhoneOnly.rawValue, forKey: "wayfolio.session.play-mode")
        defaults.set(selectedCharacterID, forKey: "wayfolio.character.id")
        defaults.set(true, forKey: "wayfolio.session.active")

        if restoreStandaloneSnapshot() {
            state = .connected(code: "IPHONE")
            notice = "Standalone journey restored on this iPhone."
            return
        }

        guard selectedCharacterID == "renn" else {
            state = .failed("Standalone campaign data is not installed for this character yet.")
            isStandaloneSession = false
            return
        }

        applyRennStandaloneSeed()
        state = .connected(code: "IPHONE")
        notice = "Playing independently on this iPhone. A shared iPad can be added later."
        persistStandaloneSnapshot()
    }

    /// Replays the current phone-owned presentation after the app's audio
    /// runtime has attached. Text and campaign state remain usable if the
    /// network-backed voice service is unavailable.
    func replayStandalonePresentation() {
        guard isStandaloneSession else { return }
        presentationEventHandler?([
            "type": "ambience_scene", "profile": "forest_day", "action": "play"
        ])
        if let dialoguePresentation { emitStandaloneDialogue(dialoguePresentation) }
    }

    private func applyRennStandaloneSeed() {
        sceneTitle = "A Cry Beneath the Pine Roots"
        sceneText = "On the forest path outside Hemlock, a frightened blue-green slime lies punctured and immobilized by jagged rusted metal beneath the roots. It holds still while Renn approaches."
        currentLocation = "Pine-root path outside Hemlock"
        timeOfDay = "Evening"
        weather = "Clear"
        character = CharacterSummary(
            name: "Renn Hazel", species: "Harengon", className: "Ranger", level: 1,
            background: "Hemlock Herbalist", hp: 10, maximumHP: 10,
            armorClass: 15, initiative: 5,
            abilities: ["strength": 8, "dexterity": 16, "constitution": 10,
                        "intelligence": 12, "wisdom": 16, "charisma": 12],
            skills: ["Animal Handling": 5, "Medicine": 5, "Nature": 3,
                     "Perception": 5, "Stealth": 5, "Survival": 5],
            magic: ["Guidance", "Druidcraft", "Animal Friendship", "Cure Wounds",
                    "Speak with Animals", "Hunter's Mark"],
            traits: ["Rabbit Hop", "Lucky Footwork", "Leporine Senses", "Hemlock Kick Training"],
            equipment: [
                .init(slot: "Protective Gear", name: "Hemlock movement armor", detail: "Studded-leather equivalent; AC 15 with DEX 16; no shield", qualityLevel: 1, family: "Protective Gear"),
                .init(slot: "Primary tool", name: "Retractable ring-headed staff", detail: "Quarterstaff; Topple mastery; field tool and defensive control", qualityLevel: 1, family: "Equipment"),
                .init(slot: "Weapons", name: "Four kunai-style daggers", detail: "Ordinary daggers; finesse, light and thrown", qualityLevel: 1, family: "Equipment"),
                .init(slot: "Spellcasting focus", name: "Hemlock-sprig belt locket", detail: "Preserved sprig from the great Hemlock; the staff is not the focus", qualityLevel: 1, family: "Equipment")
            ],
            resources: ["level_1_slots": 2], resourceLimits: ["level_1_slots": 2]
        )
        let names = [
            "Herbalist pack", "Herbalism kit", "Healer's kit",
            "Compact cook's utensils and wooden spoon", "Potion of Healing brewed by Renn",
            "Wayfolio", "Field journal and recipe collection", "Practical fire-starting gear",
            "Ingredient and remedy containers"
        ]
        inventoryItems = names.enumerated().map { index, name in
            InventoryItem(
                id: "renn-item-\(index)", name: name, quantity: 1,
                category: nil, artAssetName: nil, artURL: nil,
                consumable: name == "Potion of Healing brewed by Renn",
                mechanicalDeltas: [], equippedSlot: nil, comparedToItemID: nil
            )
        }
        inventory = inventoryItems.map(\.name)
        discoveries = ["A frightened slime is trapped beneath the pine roots."]
        journal = ["Found an injured blue-green slime immobilized by rusted metal on the pine-root path."]
        actions = []
        prompt = Prompt(
            id: "standalone-opening", title: "The creature watches Renn",
            message: "How does Renn approach the injured slime?",
            choices: ["Observe it carefully", "Try to calm it", "Examine the rusted metal"],
            allowsFreeform: true
        )
        checkResult = nil
        pendingRoll = nil
        awaitingSharedRoll = false
        dialoguePresentation = DialoguePresentation(
            id: "standalone-opening-narration", speakerID: "narrator", speakerName: "Narrator",
            text: sceneText, performance: "Quiet forest ambience; the creature trembles when the metal shifts."
        )
        visualPresentation = VisualPresentation(
            id: "standalone-pine-root-path", title: "Pine-root path outside Hemlock",
            path: "bundle://hemlock-environment", revision: "approved-runtime-fixture-v1"
        )
        standaloneStoryStep = 0
    }

    @discardableResult
    private func restoreStandaloneSnapshot() -> Bool {
        let key = "wayfolio.standalone.snapshot.\(selectedCharacterID).v1"
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(StandaloneSnapshot.self, from: data),
              snapshot.schemaVersion == 1,
              snapshot.characterID == selectedCharacterID else { return false }
        sceneTitle = snapshot.sceneTitle
        sceneText = snapshot.sceneText
        currentLocation = snapshot.currentLocation
        timeOfDay = snapshot.timeOfDay
        weather = snapshot.weather
        character = snapshot.character
        inventoryItems = snapshot.inventoryItems
        inventory = inventoryItems.map(\.name)
        discoveries = snapshot.discoveries
        journal = snapshot.journal
        actions = snapshot.actions
        prompt = snapshot.prompt
        checkResult = snapshot.checkResult
        dialoguePresentation = snapshot.dialogue
        visualPresentation = snapshot.visual
        pendingRoll = snapshot.pendingRoll
        awaitingSharedRoll = pendingRoll != nil
        standaloneStoryStep = snapshot.storyStep
        return true
    }

    private func persistStandaloneSnapshot() {
        guard isStandaloneSession, let character else { return }
        let snapshot = StandaloneSnapshot(
            schemaVersion: 1, characterID: selectedCharacterID,
            sceneTitle: sceneTitle, sceneText: sceneText, currentLocation: currentLocation,
            timeOfDay: timeOfDay, weather: weather, character: character,
            inventoryItems: inventoryItems, discoveries: discoveries, journal: journal,
            actions: actions, prompt: prompt, checkResult: checkResult,
            dialogue: dialoguePresentation, visual: visualPresentation,
            pendingRoll: pendingRoll, storyStep: standaloneStoryStep
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: "wayfolio.standalone.snapshot.\(selectedCharacterID).v1")
        }
    }

    func submitChoice(_ choice: String) {
        guard let prompt else { return }
        if isStandaloneSession {
            handleStandaloneChoice(choice, prompt: prompt)
            return
        }
        notice = nil
        Task {
            do {
                try await send([
                    "type": "player_choice",
                    "player_id": playerID,
                    "prompt_id": prompt.id,
                    "choice": choice
                ])
                self.prompt = nil
                self.awaitingSharedRoll = true
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func submitDigitalRoll() {
        submitRoll(mode: "digital", dice: [])
    }

    func submitPhysicalRoll(_ dice: [Int]) {
        submitRoll(mode: "physical", dice: dice)
    }

    func requestCharacterTransfer() {
        Task {
            do { try await send(["type": "character_transfer_request"]) }
            catch { state = .failed(error.localizedDescription) }
        }
    }

    func selectPlayMode(_ mode: PlayMode) {
        preferredPlayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "wayfolio.session.play-mode")
        guard !isStandaloneSession else { return }
        guard case .connected = state else { return }
        Task {
            do { try await send(["type": "session_mode_set", "play_mode": mode.rawValue]) }
            catch { notice = "The table mode could not be changed. Reconnecting…"; scheduleReconnect() }
        }
    }

    func handleJoinLink(_ url: URL) {
        guard url.scheme == "wayfolio", url.host == "join",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let pairs = components.queryItems?.compactMap { item in item.value.map { (item.name, $0) } } ?? []
        let values = Dictionary(uniqueKeysWithValues: pairs)
        if let character = values["character"], ["renn", "yugen", "soren", "lupin"].contains(character) { selectedCharacterID = character }
        connect(host: values["host"] ?? "localhost", code: values["code"] ?? "HEMLOCK", transferCode: values["transfer"])
    }

    /// Selects the character this physical Wayfolio represents before it joins a table.
    /// The Host remains authoritative and may reject an identity already assigned to
    /// another device.
    func chooseCharacter(_ characterID: String) {
        guard state == .disconnected || {
            if case .failed = state { return true }
            return false
        }() else { return }
        let normalized = characterID == "yu-gen" ? "yugen" : characterID
        selectedCharacterID = normalized
        UserDefaults.standard.set(normalized, forKey: "wayfolio.character.id")
    }

    func gamePageURL(path: String) -> URL? {
        let savedHost = lastHost.isEmpty
            ? (UserDefaults.standard.string(forKey: "wayfolio.session.host") ?? "localhost")
            : lastHost
        let candidate = savedHost.contains("://") ? savedHost : "http://\(savedHost)"
        guard var components = URLComponents(string: candidate) else { return nil }
        components.scheme = "http"
        if components.port == nil { components.port = 8787 }
        components.path = path
        components.query = nil
        return components.url
    }

    func presentationAssetURL(path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        if let absolute = URL(string: path), absolute.scheme != nil { return absolute }
        guard let base = gamePageURL(path: "/") else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    func importCharacterPackage(
        _ data: Data,
        visualReferences: [CharacterVisualReference] = [],
        supportingDocuments: [CharacterSupportingDocument] = [],
        host: String
    ) async throws -> ImportedCharacter {
        guard var components = Self.httpComponents(from: host) else {
            throw URLError(.badURL)
        }
        components.path = "/api/characters/import"
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if visualReferences.isEmpty && supportingDocuments.isEmpty {
            request.httpBody = data
        } else {
            guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw URLError(.cannotParseResponse)
            }
            object["visual_references"] = visualReferences.map { reference in
                ["filename": reference.filename, "mime_type": reference.mimeType,
                 "role": reference.role, "data_base64": reference.data.base64EncodedString()]
            }
            object["source_documents"] = supportingDocuments.map { document in
                ["filename": document.filename, "mime_type": document.mimeType,
                 "visibility": document.visibility, "data_base64": document.data.base64EncodedString()]
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: object)
        }
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard let object = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        guard (200..<300).contains(http.statusCode), let value = object["character"] as? [String: Any],
              let id = value["id"] as? String, let name = value["name"] as? String else {
            let message = object["error"] as? String ?? "The central game could not import this character."
            throw NSError(domain: "WayfolioCharacterImport", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        let imported = ImportedCharacter(id: id, name: name,
                                         species: value["species"] as? String ?? "Unknown ancestry",
                                         className: value["class_name"] as? String ?? "Adventurer",
                                         level: value["level"] as? Int ?? 1)
        selectedCharacterID = id
        UserDefaults.standard.set(id, forKey: "wayfolio.character.id")
        UserDefaults.standard.set(data, forKey: "wayfolio.character.package.\(id)")
        if !characterCatalog.contains(where: { $0.id == id }) {
            characterCatalog.append(.init(id: id, name: name, species: imported.species,
                                          className: imported.className, assigned: false))
        }
        return imported
    }

    func submitAction(_ text: String, isPublic: Bool, inputMode: String = "typed") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isStandaloneSession {
            handleStandaloneAction(trimmed, isPublic: isPublic, inputMode: inputMode)
            return
        }
        notice = nil
        let clientActionID = UUID().uuidString
        let message = [
            "type": "action_submit", "client_action_id": clientActionID,
            "player_id": playerID, "author": playerName,
            "text": trimmed, "visibility": isPublic ? "public" : "private",
            "input_mode": inputMode
        ]
        pendingActionMessages[clientActionID] = message
        notice = "Sending to the table…"
        Task {
            do {
                var message = message
                if let prompt, prompt.allowsFreeform { message["prompt_id"] = prompt.id }
                pendingActionMessages[clientActionID] = message
                try await send(message)
                scheduleActionRetry(clientActionID)
                if prompt?.allowsFreeform == true {
                    self.prompt = nil
                    self.awaitingSharedRoll = true
                }
            } catch {
                notice = "The action is waiting to send. Reconnecting to the table…"
                scheduleActionRetry(clientActionID)
                scheduleReconnect()
            }
        }
    }

    func useItem(_ item: InventoryItem, quantity: Int = 1) {
        if isStandaloneSession {
            handleStandaloneItemUse(item, quantity: quantity)
            return
        }
        guard item.consumable, quantity > 0 else {
            notice = "This item does not have a host-published use action."
            return
        }
        let clientItemUseID = UUID().uuidString
        let message = [
            "type": "item_use",
            "client_item_use_id": clientItemUseID,
            "player_id": playerID,
            "item_id": item.id,
            "item_name": item.name,
            "quantity": String(quantity),
            "requested_action": "consume"
        ]
        pendingItemUseMessages[clientItemUseID] = message
        notice = "Asking the host to use \(item.name)…"
        Task {
            do {
                try await send(message)
                scheduleItemUseRetry(clientItemUseID)
            } catch {
                notice = "The item use is waiting to send. Reconnecting to the table…"
                scheduleItemUseRetry(clientItemUseID)
                scheduleReconnect()
            }
        }
    }

    func setReactionPolicy(_ mode: ReactionMode, behaviorClass: String, explicitlyAuthorized: Bool = false) {
        guard mode != .automatic || explicitlyAuthorized else {
            notice = "Automatic handling needs your explicit authorization."
            return
        }
        if isStandaloneSession {
            reactionPolicies[behaviorClass] = mode
            UserDefaults.standard.set(mode.rawValue, forKey: "wayfolio.standalone.reaction.\(behaviorClass)")
            notice = mode == .ask ? "Wayfolio will ask before that reaction."
                : mode == .automatic ? "Automatic handling was explicitly authorized."
                : "That reaction behavior is off until you change it."
            return
        }
        Task {
            do {
                try await sendAny([
                    "type": "reaction_policy_set", "player_id": playerID,
                    "behavior_class": behaviorClass, "mode": mode.rawValue,
                    "explicit_authorization": explicitlyAuthorized
                ])
            } catch {
                notice = "That reaction preference could not be saved."
            }
        }
    }

    private func handleStandaloneAction(_ text: String, isPublic: Bool, inputMode: String) {
        let action = GameAction(
            id: UUID().uuidString, text: text,
            visibility: isPublic ? "public" : "private", author: playerName
        )
        actions.insert(action, at: 0)
        checkResult = nil
        prompt = nil
        standaloneStoryStep += 1

        if !isPublic {
            dialoguePresentation = DialoguePresentation(
                id: UUID().uuidString, speakerID: "narrator", speakerName: "Wayfolio",
                text: "Your private note is recorded on this iPhone. It has not been shown to a shared display.",
                performance: nil
            )
            notice = "Private note recorded locally."
            if let dialoguePresentation { emitStandaloneDialogue(dialoguePresentation) }
            persistStandaloneSnapshot()
            return
        }

        let lower = text.lowercased()
        let skill: String
        let modifier: Int
        if lower.contains("calm") || lower.contains("speak") || lower.contains("gentle") {
            skill = "Animal Handling"; modifier = character?.skills["Animal Handling"] ?? 0
            sceneText = "Renn lowers their voice and posture. The slime's trembling eases, but the rusted metal shifts whenever it tries to respond."
        } else if lower.contains("heal") || lower.contains("wound") || lower.contains("medicine") {
            skill = "Medicine"; modifier = character?.skills["Medicine"] ?? 0
            sceneText = "Renn studies where the metal enters the slime. Treating the wound safely will require keeping both the creature and the jagged fragment still."
        } else if lower.contains("look") || lower.contains("observe") || lower.contains("examine") {
            skill = "Perception"; modifier = character?.skills["Perception"] ?? 0
            sceneText = "Renn studies the roots, the metal, and the creature's reactions before touching anything."
        } else {
            skill = "Survival"; modifier = character?.skills["Survival"] ?? 0
            sceneText = "Renn begins the approach. The roots leave little room to work, and a careless movement could drive the metal deeper."
        }

        sceneTitle = "Renn Acts at the Pine Roots"
        dialoguePresentation = DialoguePresentation(
            id: UUID().uuidString, speakerID: "narrator", speakerName: "Narrator",
            text: sceneText, performance: "The creature watches every movement."
        )
        pendingRoll = PendingRoll(
            id: UUID().uuidString, playerID: playerID, playerName: playerName,
            skill: skill, modifier: modifier, difficulty: 12,
            dieType: 20, diceCount: 1, selection: nil
        )
        awaitingSharedRoll = true
        notice = inputMode == "spoken" ? "Spoken action understood. Roll on this iPhone." : "Action understood. Roll on this iPhone."
        if let dialoguePresentation { emitStandaloneDialogue(dialoguePresentation) }
        persistStandaloneSnapshot()
    }

    private func handleStandaloneChoice(_ choice: String, prompt: Prompt) {
        let lower = choice.lowercased()
        let skill: String
        if lower.contains("calm") { skill = "Animal Handling" }
        else if lower.contains("metal") { skill = "Medicine" }
        else { skill = "Perception" }
        let modifier = character?.skills[skill] ?? 0
        actions.insert(.init(id: UUID().uuidString, text: choice, visibility: "private", author: playerName), at: 0)
        self.prompt = nil
        checkResult = nil
        pendingRoll = PendingRoll(
            id: "\(prompt.id)-roll-\(UUID().uuidString)", playerID: playerID, playerName: playerName,
            skill: skill, modifier: modifier, difficulty: 12,
            dieType: 20, diceCount: 1, selection: nil
        )
        awaitingSharedRoll = true
        dialoguePresentation = DialoguePresentation(
            id: UUID().uuidString, speakerID: "narrator", speakerName: "Narrator",
            text: "Renn chooses to \(choice.lowercased()). The situation is uncertain enough to call for a \(skill) check.",
            performance: nil
        )
        notice = "Choice recorded. Roll on this iPhone."
        if let dialoguePresentation { emitStandaloneDialogue(dialoguePresentation) }
        persistStandaloneSnapshot()
    }

    private func resolveStandaloneRoll(_ dice: [Int]) {
        guard let roll = pendingRoll else { return }
        let values = dice.isEmpty
            ? (0..<roll.requiredDiceCount).map { _ in Int.random(in: 1...max(2, roll.dieType)) }
            : dice
        guard !values.isEmpty else { return }
        let natural: Int
        if roll.selection == "advantage" { natural = values.max() ?? values[0] }
        else if roll.selection == "disadvantage" { natural = values.min() ?? values[0] }
        else { natural = values[0] }
        let total = natural + roll.modifier
        let succeeded = total >= (roll.difficulty ?? 10)

        pendingRoll = nil
        awaitingSharedRoll = false
        standaloneStoryStep += 1
        if succeeded {
            sceneTitle = "The Creature Settles"
            sceneText = "Renn's careful approach changes the situation: the slime stops pulling against the metal and gives Renn room to inspect the restraint without worsening the wound."
            let observation = "Careful movement keeps the injured slime stable while the rusted restraint is examined."
            if !discoveries.contains(observation) { discoveries.append(observation) }
            journal.append("Earned observation: \(observation)")
            checkResult = CheckResult(
                title: "The situation changes",
                detail: "Rolled \(natural) + \(roll.modifier) = \(total). The slime is stable and trust has increased.",
                succeeded: true
            )
        } else {
            sceneTitle = "The Metal Shifts"
            sceneText = "The attempt changes the situation: a root flexes, the jagged metal shifts, and the slime recoils in pain. It is now more distressed and abrupt handling will worsen the injury."
            journal.append("Complication: the rusted restraint shifted and the injured slime became more distressed.")
            checkResult = CheckResult(
                title: "A complication develops",
                detail: "Rolled \(natural) + \(roll.modifier) = \(total). The restraint shifted and the creature's distress increased.",
                succeeded: false
            )
        }
        dialoguePresentation = DialoguePresentation(
            id: UUID().uuidString, speakerID: "narrator", speakerName: "Narrator",
            text: sceneText, performance: succeeded ? "The creature grows still." : "A sharp tremor runs through the roots."
        )
        prompt = Prompt(
            id: "standalone-followup-\(standaloneStoryStep)", title: "What does Renn do next?",
            message: succeeded
                ? "The creature is stable for the moment. Renn can continue in any way that makes sense."
                : "The creature is frightened and the restraint is less stable. Renn can still choose any approach.",
            choices: succeeded
                ? ["Inspect the restraint", "Prepare the healer's kit", "Try to communicate"]
                : ["Pause and calm it", "Brace the metal", "Withdraw and seek help"],
            allowsFreeform: true
        )
        notice = succeeded ? "The check changed the situation." : "The failed check created a complication."
        presentationEventHandler?([
            "type": "sound_effect", "cue": succeeded ? "spell_chime" : "water_splash", "volume": 0.62
        ])
        if let dialoguePresentation { emitStandaloneDialogue(dialoguePresentation) }
        persistStandaloneSnapshot()
    }

    private func handleStandaloneItemUse(_ item: InventoryItem, quantity: Int) {
        guard item.consumable, quantity > 0 else {
            notice = "Describe how Renn uses this item in Live play. Wayfolio will not spend it automatically."
            return
        }
        let policy = reactionPolicies["resource_spend"]
            ?? ReactionMode(rawValue: UserDefaults.standard.string(forKey: "wayfolio.standalone.reaction.resource_spend") ?? "")
            ?? .ask
        guard policy == .automatic else {
            notice = policy == .off
                ? "Automatic resource spending is off. Change the preference before using this item."
                : "Confirm the item use through a described Live action; resource spending defaults to ASK."
            return
        }
        guard let index = inventoryItems.firstIndex(where: { $0.id == item.id }) else { return }
        inventoryItems.remove(at: index)
        inventory = inventoryItems.map(\.name)
        journal.append("Used \(item.name) during the pine-root encounter.")
        notice = "Used \(item.name) with explicit automatic-spend authorization."
        persistStandaloneSnapshot()
    }

    private func emitStandaloneDialogue(_ dialogue: DialoguePresentation) {
        presentationEventHandler?([
            "type": "dialogue",
            "line_id": dialogue.id,
            "speaker_id": dialogue.speakerID,
            "speaker_name": dialogue.speakerName,
            "text": dialogue.text,
            "performance": dialogue.performance ?? "neutral"
        ])
    }

    func disconnect() {
        intentionallyDisconnected = true
        UserDefaults.standard.set(false, forKey: "wayfolio.session.active")
        closeConnection()
        isStandaloneSession = false
        state = .disconnected
        prompt = nil
        checkResult = nil
        awaitingSharedRoll = false
        pendingActionRetryTasks.values.forEach { $0.cancel() }
        pendingActionRetryTasks.removeAll()
        pendingActionMessages.removeAll()
        pendingItemUseRetryTasks.values.forEach { $0.cancel() }
        pendingItemUseRetryTasks.removeAll()
        pendingItemUseMessages.removeAll()
        character = nil
        inventory = []
        inventoryItems = []
        discoveries = []
        journal = []
        knownLocations = []
        knownPeople = []
        knownCreatures = []
        companions = []
        botanicals = []
        recipes = []
        experiments = []
        pendingThreads = []
        completedWork = []
        knowledgeRecords = []
        reactionPolicies = [:]
        narrativeMoments = []
        contextualAffordances = []
        actions = []
        encounter = nil
        dialoguePresentation = nil
        visualPresentation = nil
        pendingRoll = nil
        notice = nil
    }

    func dismissNotice() {
        notice = nil
    }

    private func closeConnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil, !intentionallyDisconnected, !lastHost.isEmpty else { return }
        reconnectAttempt += 1
        let delay = min(12, max(1, 1 << min(reconnectAttempt - 1, 3)))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, !self.intentionallyDisconnected else { return }
            self.reconnectTask = nil
            self.connect(host: self.lastHost, code: self.lastCode)
        }
    }

    private func send(_ object: [String: String]) async throws {
        guard let socket else { throw URLError(.notConnectedToInternet) }
        let data = try JSONSerialization.data(withJSONObject: object)
        try await socket.send(.data(data))
    }

    private func scheduleActionRetry(_ clientActionID: String) {
        guard pendingActionRetryTasks[clientActionID] == nil else { return }
        pendingActionRetryTasks[clientActionID] = Task { [weak self] in
            guard let self else { return }
            for attempt in 1...5 {
                try? await Task.sleep(for: .seconds(attempt == 1 ? 2 : 3))
                guard !Task.isCancelled, let message = self.pendingActionMessages[clientActionID] else { return }
                guard case .connected = self.state else { continue }
                do { try await self.send(message) } catch { continue }
            }
            guard self.pendingActionMessages[clientActionID] != nil else { return }
            self.notice = "The Host has not confirmed this action. It remains unsent—check the connection and try again."
            self.pendingActionRetryTasks[clientActionID] = nil
        }
    }

    private func resendPendingActions() {
        for (clientActionID, message) in pendingActionMessages {
            Task { [weak self] in
                guard let self else { return }
                try? await self.send(message)
                self.scheduleActionRetry(clientActionID)
            }
        }
        for (clientItemUseID, message) in pendingItemUseMessages {
            Task { [weak self] in
                guard let self else { return }
                try? await self.send(message)
                self.scheduleItemUseRetry(clientItemUseID)
            }
        }
    }

    private func scheduleItemUseRetry(_ clientItemUseID: String) {
        guard pendingItemUseRetryTasks[clientItemUseID] == nil else { return }
        pendingItemUseRetryTasks[clientItemUseID] = Task { [weak self] in
            guard let self else { return }
            for attempt in 1...5 {
                try? await Task.sleep(for: .seconds(attempt == 1 ? 2 : 3))
                guard !Task.isCancelled, let message = self.pendingItemUseMessages[clientItemUseID] else { return }
                guard case .connected = self.state else { continue }
                do { try await self.send(message) } catch { continue }
            }
            guard self.pendingItemUseMessages[clientItemUseID] != nil else { return }
            self.notice = "The Host has not confirmed this item use. Nothing was changed locally."
            self.pendingItemUseRetryTasks[clientItemUseID] = nil
        }
    }

    private func acknowledgeAction(_ clientActionID: String?, visibility: String) {
        guard let clientActionID else { return }
        pendingActionMessages.removeValue(forKey: clientActionID)
        pendingActionRetryTasks.removeValue(forKey: clientActionID)?.cancel()
        notice = visibility == "public" ? "Shared with the table." : "Sent privately to the DM."
    }

    private func handle(_ data: Data, expectedCode: String) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { return }

        switch type {
        case "joined":
            if let token = object["resume_token"] as? String {
                UserDefaults.standard.set(token, forKey: "wayfolio.session.resume-token.\(playerID)")
                UserDefaults.standard.removeObject(forKey: "wayfolio.session.resume-token")
            }
            reconnectAttempt = 0
            notice = nil
            state = .connected(code: object["session_code"] as? String ?? expectedCode)
            resendPendingActions()
        case "session_snapshot", "scene_update":
            sceneTitle = object["scene_title"] as? String ?? sceneTitle
            sceneText = object["scene_text"] as? String ?? sceneText
            if let value = object["location_name"] as? String, !value.isEmpty { currentLocation = value }
            if object.keys.contains("time_of_day") { timeOfDay = Self.nonemptyString(object["time_of_day"]) }
            if object.keys.contains("weather") { weather = Self.nonemptyString(object["weather"]) }
            if let values = object["character_catalog"] as? [[String: Any]] {
                characterCatalog = values.compactMap(Self.parseCharacterOption)
            }
            parseSessionRuntime(object["session_runtime"] as? [String: Any])
            if type == "session_snapshot", let value = object["presentation_state"] as? [String: Any] {
                presentationStateHandler?(value)
            }
            if object.keys.contains("current_dialogue") {
                dialoguePresentation = Self.parseDialogue(object["current_dialogue"] as? [String: Any])
            }
            if object.keys.contains("current_visual") {
                visualPresentation = Self.parseVisual(object["current_visual"] as? [String: Any])
            }
            if let value = object["character"] as? [String: Any] { parseCharacter(value) }
            if let value = object["character_state"] as? [String: Any] {
                if let publishedInventory = value["inventory"] as? [Any] {
                    inventoryItems = Self.parseInventory(publishedInventory)
                    inventory = inventoryItems.map(\.name)
                }
                discoveries = value["discoveries"] as? [String] ?? discoveries
                journal = value["journal"] as? [String] ?? journal
                if let resources = value["resources"] as? [String: Any] {
                    secondaryResourceSummary = Self.resourceSummary(resources)
                }
            }
            if let value = object["campaign_knowledge"] as? [String: Any] {
                knownLocations = (value["locations"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
                knownPeople = (value["people"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
                knownCreatures = (value["creatures"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
                companions = (value["companions"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
                botanicals = (value["botanicals"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
                recipes = (value["recipes"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
                experiments = (value["experiments"] as? [[String: Any]] ?? []).compactMap(Self.parseExperiment)
                pendingThreads = value["pending_threads"] as? [String] ?? []
                completedWork = value["completed_work"] as? [String] ?? []
                knowledgeRecords = (value["records"] as? [[String: Any]] ?? []).compactMap(Self.parseKnowledgeRecord)
            }
            if let value = object["interaction_policy"] as? [String: Any],
               let policies = value["reaction_policies"] as? [String: String] {
                reactionPolicies = policies.reduce(into: [:]) { result, entry in
                    result[entry.key] = ReactionMode(rawValue: entry.value) ?? .ask
                }
            }
            narrativeMoments = (object["narrative_moments"] as? [[String: Any]] ?? []).compactMap(Self.parseNarrativeMoment)
            contextualAffordances = (object["contextual_affordances"] as? [[String: Any]] ?? []).compactMap(Self.parseAffordance)
            if let values = object["action_log"] as? [[String: Any]] {
                actions = values.compactMap(Self.parseAction)
            }
            if type == "session_snapshot" {
                if let value = object["active_encounter"] as? [String: Any] {
                    encounter = Self.parseEncounter(value)
                } else {
                    encounter = nil
                }
                if let pending = object["pending_roll"] as? [String: Any] {
                    pendingRoll = Self.parsePendingRoll(pending)
                    awaitingSharedRoll = pendingRoll?.playerID == playerID
                } else if prompt == nil {
                    pendingRoll = nil
                    awaitingSharedRoll = false
                }
            }
        case "presentation_event":
            guard let event = object["event"] as? [String: Any] else { return }
            presentationEventHandler?(event)
            if event["type"] as? String == "dialogue" {
                dialoguePresentation = Self.parseDialogue(event)
            }
        case "visual_update":
            visualPresentation = Self.parseVisual(object["visual"] as? [String: Any])
        case "turn_presentation_cleared":
            dialoguePresentation = nil
            checkResult = nil
        case "roll_requested":
            pendingRoll = Self.parsePendingRoll(object["roll"] as? [String: Any])
            awaitingSharedRoll = pendingRoll?.playerID == playerID
            notice = nil
        case "roll_ack":
            notice = "Roll received. The world is responding…"
        case "private_prompt":
            guard let id = object["prompt_id"] as? String,
                  let title = object["title"] as? String,
                  let message = object["message"] as? String,
                  let choices = object["choices"] as? [String] else { return }
            prompt = Prompt(id: id, title: title, message: message, choices: choices,
                            allowsFreeform: object["allows_freeform"] as? Bool ?? false)
            checkResult = nil
            notice = nil
            awaitingSharedRoll = false
        case "choice_received":
            awaitingSharedRoll = true
        case "private_result":
            guard let title = object["title"] as? String,
                  let detail = object["detail"] as? String,
                  let succeeded = object["succeeded"] as? Bool else { return }
            checkResult = CheckResult(title: title, detail: detail, succeeded: succeeded)
            notice = nil
            pendingRoll = nil
            awaitingSharedRoll = false
        case "action_event", "action_ack":
            guard let id = object["action_id"] as? String,
                  let text = object["text"] as? String,
                  let visibility = object["visibility"] as? String else { return }
            let action = GameAction(id: id, text: text, visibility: visibility,
                                    author: object["author"] as? String ?? playerName)
            if !actions.contains(where: { $0.id == id }) { actions.insert(action, at: 0) }
            if type == "action_ack" {
                checkResult = nil
                acknowledgeAction(object["client_action_id"] as? String, visibility: visibility)
            }
        case "item_use_ack":
            if let publishedInventory = (object["character_state"] as? [String: Any])?["inventory"] as? [Any] {
                inventoryItems = Self.parseInventory(publishedInventory)
                inventory = inventoryItems.map(\.name)
            }
            if let clientItemUseID = object["client_item_use_id"] as? String {
                pendingItemUseMessages.removeValue(forKey: clientItemUseID)
                pendingItemUseRetryTasks.removeValue(forKey: clientItemUseID)?.cancel()
            }
            notice = object["message"] as? String ?? "The host confirmed the item use."
        case "character_transfer_ready":
            transferCode = object["transfer_code"] as? String
        case "session_mode_changed":
            parseSessionRuntime(object["session_runtime"] as? [String: Any])
        case "reaction_policy_ack":
            if let behaviorClass = object["behavior_class"] as? String,
               let raw = object["mode"] as? String,
               let mode = ReactionMode(rawValue: raw) {
                reactionPolicies[behaviorClass] = mode
                notice = mode == .ask ? "Wayfolio will ask before that reaction."
                    : mode == .automatic ? "Automatic handling was explicitly authorized."
                    : "That reaction behavior is off until you change it."
            }
        case "error":
            let message = object["message"] as? String ?? "The host rejected the request."
            if let clientItemUseID = object["client_item_use_id"] as? String {
                pendingItemUseMessages.removeValue(forKey: clientItemUseID)
                pendingItemUseRetryTasks.removeValue(forKey: clientItemUseID)?.cancel()
            }
            if case .connected = state {
                notice = message
            } else {
                state = .failed(message)
            }
        default:
            break
        }
    }

    private func parseSessionRuntime(_ value: [String: Any]?) {
        guard let value else { return }
        if let raw = value["play_mode"] as? String, let mode = PlayMode(rawValue: raw) {
            playMode = mode
            preferredPlayMode = mode
            UserDefaults.standard.set(mode.rawValue, forKey: "wayfolio.session.play-mode")
        }
        sharedIPadConnected = value["shared_ipad_connected"] as? Bool ?? false
    }

    private func submitRoll(mode: String, dice: [Int]) {
        guard let pendingRoll, pendingRoll.playerID == playerID else { return }
        if isStandaloneSession {
            resolveStandaloneRoll(mode == "digital" ? [] : dice)
            return
        }
        notice = mode == "digital" ? "Rolling the dice…" : "Sending your physical roll…"
        Task {
            do {
                var message: [String: Any] = [
                    "type": "roll_submit",
                    "roll_id": pendingRoll.id,
                    "mode": mode,
                    "client_roll_submission_id": UUID().uuidString
                ]
                if mode == "physical" { message["dice"] = dice }
                try await sendAny(message)
            } catch {
                notice = "The roll could not be sent. Check the connection and try again."
            }
        }
    }

    private func sendAny(_ object: [String: Any]) async throws {
        guard let socket else { throw URLError(.notConnectedToInternet) }
        let data = try JSONSerialization.data(withJSONObject: object)
        try await socket.send(.data(data))
    }

    private static func parseInventory(_ values: [Any]) -> [InventoryItem] {
        values.enumerated().compactMap { index, raw in
            if let name = raw as? String {
                let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
                return InventoryItem(
                    id: id, name: name, quantity: 1, category: nil,
                    artAssetName: nil, artURL: nil,
                    consumable: name.localizedCaseInsensitiveContains("potion of healing"),
                    mechanicalDeltas: [], equippedSlot: nil, comparedToItemID: nil
                )
            }
            guard let value = raw as? [String: Any], let name = nonemptyString(value["name"]) else { return nil }
            let rawDeltas = value["mechanical_deltas"] as? [[String: Any]] ?? []
            let deltas = rawDeltas.compactMap { delta -> InventoryItem.MechanicalDelta? in
                guard let label = nonemptyString(delta["label"]), let amount = nonemptyString(delta["value"]) else { return nil }
                return .init(
                    id: nonemptyString(delta["id"]) ?? "\(label)-\(amount)",
                    label: label,
                    value: amount,
                    direction: nonemptyString(delta["direction"]) ?? "neutral"
                )
            }
            return InventoryItem(
                id: nonemptyString(value["id"]) ?? "inventory-\(index)-\(name)",
                name: name,
                quantity: (value["quantity"] as? NSNumber)?.intValue ?? 1,
                category: nonemptyString(value["category"]),
                artAssetName: nonemptyString(value["art_asset_name"]),
                artURL: nonemptyString(value["art_url"]),
                consumable: value["consumable"] as? Bool ?? false,
                mechanicalDeltas: deltas,
                equippedSlot: nonemptyString(value["equipped_slot"]),
                comparedToItemID: nonemptyString(value["compared_to_item_id"])
            )
        }
    }

    private func parseCharacter(_ value: [String: Any]) {
        guard let name = value["name"] as? String,
              let species = value["species"] as? String,
              let className = value["class_name"] as? String,
              let level = value["level"] as? Int,
              let background = value["background"] as? String,
              let hp = value["hp"] as? [String: Any],
              let currentHP = hp["current"] as? Int,
              let maximumHP = hp["maximum"] as? Int,
              let armorClass = value["armor_class"] as? Int,
              let initiative = value["initiative"] as? Int else { return }

        character = CharacterSummary(
            name: name,
            species: species,
            className: className,
            level: level,
            background: background,
            hp: currentHP,
            maximumHP: maximumHP,
            armorClass: armorClass,
            initiative: initiative,
            abilities: value["abilities"] as? [String: Int] ?? [:],
            skills: value["skills"] as? [String: Int] ?? [:],
            magic: value["magic"] as? [String] ?? [],
            traits: value["traits"] as? [String] ?? [],
            equipment: (value["equipment"] as? [[String: Any]] ?? []).compactMap { item in
                guard let slot = item["slot"] as? String,
                      let name = item["name"] as? String,
                      let detail = item["detail"] as? String else { return nil }
                return CharacterSummary.EquipmentItem(
                    slot: slot,
                    name: name,
                    detail: detail,
                    qualityLevel: item["quality_level"] as? Int,
                    family: Self.nonemptyString(item["equipment_family"])
                )
            },
            resources: Self.integerDictionary(value["resources"]),
            resourceLimits: Self.integerDictionary(value["resource_limits"])
        )
    }

    private static func parseAction(_ value: [String: Any]) -> GameAction? {
        guard let id = value["id"] as? String,
              let text = value["text"] as? String,
              let visibility = value["visibility"] as? String,
              let author = nonemptyString(value["author"]) else { return nil }
        return GameAction(id: id, text: text, visibility: visibility, author: author)
    }

    private static func parseDialogue(_ value: [String: Any]?) -> DialoguePresentation? {
        guard let value, let text = nonemptyString(value["text"]) else { return nil }
        let speakerID = nonemptyString(value["speaker_id"]) ?? "narrator"
        let fallbackName = speakerID == "narrator" ? "Narrator" : speakerID.capitalized
        return .init(
            id: nonemptyString(value["line_id"]) ?? UUID().uuidString,
            speakerID: speakerID,
            speakerName: nonemptyString(value["speaker_name"]) ?? fallbackName,
            text: text,
            performance: nonemptyString(value["performance"])
        )
    }

    private static func parseVisual(_ value: [String: Any]?) -> VisualPresentation? {
        guard let value, let path = nonemptyString(value["url"]) else { return nil }
        return .init(
            id: nonemptyString(value["id"]) ?? path,
            title: nonemptyString(value["title"]) ?? "Current scene",
            path: path,
            revision: nonemptyString(value["reviewed_at"]) ?? nonemptyString(value["created_at"])
        )
    }

    private static func parsePendingRoll(_ value: [String: Any]?) -> PendingRoll? {
        guard let value,
              let id = nonemptyString(value["id"]),
              let playerID = nonemptyString(value["playerID"]) else { return nil }
        return .init(
            id: id,
            playerID: playerID,
            playerName: nonemptyString(value["playerName"]) ?? playerID.capitalized,
            skill: nonemptyString(value["skill"]) ?? "Check",
            modifier: (value["modifier"] as? NSNumber)?.intValue ?? 0,
            difficulty: (value["dc"] as? NSNumber)?.intValue,
            dieType: (value["die_type"] as? NSNumber)?.intValue ?? 20,
            diceCount: (value["dice_count"] as? NSNumber)?.intValue ?? 1,
            selection: nonemptyString(value["selection"])
        )
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.lowercased() == "unknown" ? nil : trimmed
    }

    private static func integerDictionary(_ value: Any?) -> [String: Int] {
        guard let dictionary = value as? [String: Any] else { return [:] }
        return dictionary.reduce(into: [:]) { result, entry in
            if let number = entry.value as? NSNumber { result[entry.key] = number.intValue }
        }
    }

    private static func resourceSummary(_ resources: [String: Any]) -> String? {
        let preferred = resources.keys.sorted().first { key in
            key.lowercased().hasSuffix("_current") && resources[key] is NSNumber
        } ?? resources.keys.sorted().first { resources[$0] is NSNumber }
        guard let key = preferred, let number = resources[key] as? NSNumber else { return nil }
        let label = key
            .replacingOccurrences(of: "_current", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        return "\(label) \(number.intValue)"
    }

    private static func parseCharacterOption(_ value: [String: Any]) -> CharacterOption? {
        guard let id = value["id"] as? String, let name = value["name"] as? String else { return nil }
        return .init(id: id, name: name, species: value["species"] as? String ?? "Unknown ancestry",
                     className: value["class_name"] as? String ?? "Adventurer",
                     assigned: value["assigned"] as? Bool ?? false)
    }

    private static func parseKnowledgeRecord(_ value: [String: Any]) -> KnowledgeRecord? {
        guard let id = value["id"] as? String else { return nil }
        let fallbackName = id.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
        return .init(id: id, kind: value["kind"] as? String ?? "discovery",
                     name: value["name"] as? String ?? fallbackName,
                     status: value["status"] as? String ?? value["role"] as? String ?? "known",
                     notes: value["notes"] as? [String] ?? [],
                     updatedAt: nonemptyString(value["updated_at"]),
                     knowledgeScope: nonemptyString(value["knowledge_scope"]) ?? "CHARACTER",
                     ownerCharacterID: nonemptyString(value["owner_character_id"]),
                     relevance: (value["relevance"] as? NSNumber)?.intValue ?? 0)
    }

    private static func parseNarrativeMoment(_ value: [String: Any]) -> NarrativeMoment? {
        guard let id = nonemptyString(value["id"]), let presentation = nonemptyString(value["presentation"]) else { return nil }
        return .init(id: id, presentation: presentation, tone: nonemptyString(value["tone"]),
                     knowledgeScope: nonemptyString(value["knowledge_scope"]) ?? "PARTY")
    }

    private static func parseAffordance(_ value: [String: Any]) -> ContextualAffordance? {
        guard let id = nonemptyString(value["id"]), let kind = nonemptyString(value["kind"]) else { return nil }
        return .init(id: id, kind: kind, label: nonemptyString(value["label"]) ?? kind,
                     relevance: (value["relevance"] as? NSNumber)?.intValue ?? 0)
    }

    private static func parseExperiment(_ value: [String: Any]) -> ExperimentRecord? {
        guard let id = value["id"] as? String, let question = value["question"] as? String else { return nil }
        return .init(id: id, question: question, status: value["status"] as? String ?? "recorded",
                     samples: value["samples"] as? [String] ?? [])
    }

    private static func parseEncounter(_ value: [String: Any]) -> Encounter? {
        guard let name = value["name"] as? String, let status = value["status"] as? String else { return nil }
        let combatants = (value["combatants"] as? [[String: Any]] ?? []).compactMap { item -> Encounter.Combatant? in
            guard let id = item["id"] as? String, let name = item["name"] as? String,
                  let hp = item["hp"] as? Int, let maximum = item["maximum_hp"] as? Int else { return nil }
            return .init(id: id, name: name, kind: item["kind"] as? String ?? "unknown",
                         hp: hp, maximumHP: maximum,
                         hpVisible: item["hp_visibility"] as? Bool ?? true,
                         publicStatus: item["public_status"] as? String ?? "condition unknown",
                         conditions: item["conditions"] as? [String] ?? [])
        }
        return Encounter(name: name, status: status, outcome: value["outcome"] as? String,
                         round: value["round"] as? Int ?? 1, activeCombatantID: value["active_combatant_id"] as? String,
                         combatants: combatants)
    }

    private static func webSocketURL(from host: String) -> URL? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "ws://\(trimmed)"
        guard var components = URLComponents(string: candidate) else { return nil }
        if components.port == nil { components.port = 8787 }
        components.path = "/session"
        return components.url
    }


    private static func httpComponents(from host: String) -> URLComponents? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard var components = URLComponents(string: candidate) else { return nil }
        components.scheme = "http"
        if components.port == nil { components.port = 8787 }
        return components
    }
}
