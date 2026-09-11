import SwiftUI
import UniformTypeIdentifiers

struct WayfinderSessionView: View {
    let showsHostPages: Bool

    @EnvironmentObject private var session: GameSessionClient
    @Environment(\.openURL) private var openURL
    @State private var host = "localhost"
    @State private var code = "HEMLOCK"
    @State private var storyAction = ""
    @State private var storyActionIsPublic = false
    @State private var incomingTransferCode = ""
    @State private var showingInstructionExporter = false
    @State private var showingCharacterImporter = false
    @State private var pendingCharacterPackage: Data?
    @State private var pendingCharacterPreview: CharacterPackagePreview?
    @State private var pendingVisualReferences: [GameSessionClient.CharacterVisualReference] = []
    @State private var pendingSupportingDocuments: [GameSessionClient.CharacterSupportingDocument] = []
    @State private var characterImportMessage = ""
    @State private var isImportingCharacter = false

    init(showsHostPages: Bool = false) {
        self.showsHostPages = showsHostPages
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                characterCard
                if showsHostPages {
                    gameScreensCard
                }
                characterImportCard
                if let character = session.character {
                    vitalsCard(character)
                    abilitiesCard(character)
                    skillsCard(character)
                    collectionCard(title: "Magic", symbol: "sparkles", values: character.magic)
                    collectionCard(title: "Traits", symbol: "hare.fill", values: character.traits)
                    WayfolioEquipmentList(items: character.equipment)
                    collectionCard(title: "Carried Inventory", symbol: "backpack.fill", values: session.inventory)
                    collectionCard(title: "Discoveries", symbol: "eye.fill", values: session.discoveries,
                                   emptyMessage: "The road has not yielded its secrets yet.")
                    collectionCard(title: "Journal", symbol: "book.closed.fill", values: session.journal,
                                   emptyMessage: "Renn's field notes will appear here as the story unfolds.")
                }
                connectionCard
                sceneCard
                if let prompt = session.prompt { promptCard(prompt) }
                if session.awaitingSharedRoll { waitingForRollCard }
                if let result = session.checkResult { resultCard(result) }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .fileExporter(isPresented: $showingInstructionExporter,
                      document: CharacterInstructionsDocument(),
                      contentType: .plainText,
                      defaultFilename: "Wayfolio Character Import Instructions") { result in
            if case .failure(let error) = result { characterImportMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $showingCharacterImporter,
                      allowedContentTypes: [.json, .image, .pdf, .plainText, .rtf],
                      allowsMultipleSelection: true) { result in
            receiveCharacterPackage(result)
        }
    }

    private var characterCard: some View {
        HStack(spacing: 14) {
            CharacterPortraitView(
                characterID: session.selectedCharacterID,
                characterName: session.character?.name ?? session.playerName,
                size: 58
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(session.character?.name ?? "Renn")
                    .font(WayfolioTypography.title)
                Text(characterSubtitle)
                    .font(WayfolioTypography.caption)
                    .tracking(1)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
            }
            Spacer()
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private var gameScreensCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Game Session", systemImage: "rectangle.3.group.fill")
                .font(WayfolioTypography.headline)
            Text("Open or recover each part of the table from here.")
                .font(WayfolioTypography.body)

            gamePageButton("Start or Continue Story", detail: "DM story review and campaign decisions", symbol: "book.pages.fill", path: "/review.html")
            gamePageButton("Shared Table Screen", detail: "The public display everyone watches", symbol: "tv.fill", path: "/")
            gamePageButton("Private DM Controls", detail: "Scenes, checks, encounters, and audio", symbol: "person.crop.circle.badge.key.fill", path: "/dm")
            gamePageButton("All Game Screens", detail: "Launcher for reopening any game window", symbol: "square.grid.2x2.fill", path: "/launcher")

            Text("DM controls and story review are private. Do not mirror those pages to the table display.")
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.65))
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func gamePageButton(_ title: String, detail: String, symbol: String, path: String) -> some View {
        Button {
            if let url = session.gamePageURL(path: path) { openURL(url) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(WayfolioTypography.headline)
                    Text(detail).font(WayfolioTypography.caption).opacity(0.72)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
        }
        .buttonStyle(.plain)
        .foregroundStyle(WayfolioPalette.parchment)
        .background(WayfolioPalette.navy, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(WayfolioPalette.brass.opacity(0.8)))
    }

    private var characterImportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bring Your Character", systemImage: "person.text.rectangle.fill")
                .font(WayfolioTypography.headline)
            Text("Take the instruction file to ChatGPT, then select the completed character JSON, approved images, and supporting notes together.")
                .font(WayfolioTypography.body)

            Button { showingInstructionExporter = true } label: {
                Label("Save ChatGPT Instruction File", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(WayfolioPalette.navy)

            Button { showingCharacterImporter = true } label: {
                Label("Choose Complete Character Package", systemImage: "doc.on.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(WayfolioPalette.navy)

            if let preview = pendingCharacterPreview {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review before adding").font(WayfolioTypography.headline)
                    Text(preview.name).font(WayfolioTypography.title)
                    Text("\(preview.species) • \(preview.className) • Level \(preview.level)")
                        .font(WayfolioTypography.body)
                    HStack(spacing: 8) {
                        statTile("HP", preview.maximumHP.map(String.init) ?? "—")
                        statTile("AC", preview.armorClass.map(String.init) ?? "—")
                        statTile("ITEMS", "\(preview.itemCount)")
                    }
                    HStack(spacing: 8) {
                        statTile("LORE", "\(preview.loreFieldCount)")
                        statTile("EXTRA", "\(preview.extraSectionCount)")
                        statTile("FILES", "\(pendingVisualReferences.count + pendingSupportingDocuments.count)")
                    }
                    if !preview.warnings.isEmpty {
                        Text(preview.warnings.joined(separator: " "))
                            .font(WayfolioTypography.caption)
                            .foregroundStyle(.orange)
                    }
                    Button { showingCharacterImporter = true } label: {
                        Label("Choose a Different Complete Package", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(WayfolioPalette.navy)
                    if !pendingVisualReferences.isEmpty {
                        Text("Approved images").font(WayfolioTypography.headline)
                        ForEach(pendingVisualReferences) { reference in
                            HStack {
                                Image(systemName: "photo.fill")
                                VStack(alignment: .leading) {
                                    Text(reference.filename).lineLimit(1)
                                    Text(reference.role.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(WayfolioTypography.caption).opacity(0.65)
                                }
                                Spacer()
                                Button { pendingVisualReferences.removeAll { $0.id == reference.id } } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }.buttonStyle(.plain)
                            }.font(WayfolioTypography.body)
                        }
                    }
                    if !pendingSupportingDocuments.isEmpty {
                        Text("Preserved source material").font(WayfolioTypography.headline)
                        ForEach(pendingSupportingDocuments) { document in
                            HStack {
                                Image(systemName: "doc.text.fill")
                                VStack(alignment: .leading) {
                                    Text(document.filename).lineLimit(1)
                                    Text(document.visibility.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(WayfolioTypography.caption).opacity(0.65)
                                }
                                Spacer()
                                Menu {
                                    Button("Public") { setVisibility("public", for: document.id) }
                                    Button("Player Only") { setVisibility("player_only", for: document.id) }
                                    Button("DM Only") { setVisibility("dm_only", for: document.id) }
                                } label: {
                                    Image(systemName: "lock.shield.fill")
                                }
                            }.font(WayfolioTypography.body)
                        }
                    }
                    Text("Recognized rules become playable fields. All additional JSON sections and source documents are retained without becoming authoritative game rules.")
                        .font(WayfolioTypography.caption)
                    Button { confirmCharacterImport() } label: {
                        Label(isImportingCharacter ? "Adding Character…" : "Confirm and Add Character",
                              systemImage: "checkmark.seal.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(WayfolioPalette.navy)
                    .disabled(isImportingCharacter)
                }
                .padding(12)
                .background(Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(WayfolioPalette.brass.opacity(0.75)))
            }

            if !characterImportMessage.isEmpty {
                Text(characterImportMessage).font(WayfolioTypography.caption)
                    .foregroundStyle(characterImportMessage.hasPrefix("Added") ? .green : .red)
            }
            Text("Only the public profile is shown to other players. DM-only information remains on the private host.")
                .font(WayfolioTypography.caption).foregroundStyle(WayfolioPalette.ink.opacity(0.65))
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func receiveCharacterPackage(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }
            var jsonPackages: [(URL, Data)] = []
            var visuals: [GameSessionClient.CharacterVisualReference] = []
            var documents: [GameSessionClient.CharacterSupportingDocument] = []
            for (index, url) in urls.enumerated() {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                if type?.conforms(to: .json) == true || url.pathExtension.lowercased() == "json" {
                    jsonPackages.append((url, data))
                } else if type?.conforms(to: .image) == true {
                    guard data.count <= 8_000_000 else {
                        throw characterImportError(4, "Each reference image must be smaller than 8 MB.")
                    }
                    let lower = url.lastPathComponent.lowercased()
                    let role: String
                    if lower.contains("portrait") || visuals.isEmpty { role = "primary_portrait" }
                    else if lower.contains("expression") { role = "expression_sheet" }
                    else if lower.contains("body") || lower.contains("turnaround") { role = "full_body" }
                    else { role = "approved_reference" }
                    visuals.append(.init(filename: url.lastPathComponent,
                                         mimeType: type?.preferredMIMEType ?? "image/jpeg",
                                         role: role, data: data))
                } else {
                    guard data.count <= 2_000_000 else {
                        throw characterImportError(6, "Each supporting document must be smaller than 2 MB.")
                    }
                    documents.append(.init(filename: url.lastPathComponent,
                                           mimeType: type?.preferredMIMEType ?? "application/octet-stream",
                                           visibility: inferredVisibility(for: url.lastPathComponent), data: data))
                }
                if index >= 20 { break }
            }
            guard jsonPackages.count == 1 else {
                throw characterImportError(7, jsonPackages.isEmpty
                    ? "Select the completed Wayfolio JSON file along with any images and notes."
                    : "Choose one character JSON file at a time.")
            }
            guard visuals.count <= 8 else { throw characterImportError(8, "Choose no more than eight approved images.") }
            guard documents.count <= 12 else { throw characterImportError(9, "Choose no more than twelve supporting documents.") }
            guard visuals.reduce(0, { $0 + $1.data.count }) <= 20_000_000 else {
                throw characterImportError(5, "Choose fewer or smaller images; approved images must be under 20 MB combined.")
            }
            guard documents.reduce(0, { $0 + $1.data.count }) <= 8_000_000 else {
                throw characterImportError(10, "Choose fewer or smaller notes; supporting documents must be under 8 MB combined.")
            }
            let data = jsonPackages[0].1
            pendingCharacterPreview = try CharacterPackagePreview(data: data)
            pendingCharacterPackage = data
            pendingVisualReferences = visuals
            pendingSupportingDocuments = documents
            characterImportMessage = ""
        } catch {
            pendingCharacterPreview = nil
            pendingCharacterPackage = nil
            pendingVisualReferences = []
            pendingSupportingDocuments = []
            characterImportMessage = error.localizedDescription
        }
    }

    private func characterImportError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "WayfolioCharacterImport", code: code,
                userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func inferredVisibility(for filename: String) -> String {
        let lower = filename.lowercased()
        if lower.contains("dm-only") || lower.contains("dm_only") || lower.contains("secret") { return "dm_only" }
        if lower.contains("public") { return "public" }
        return "player_only"
    }

    private func setVisibility(_ visibility: String, for id: UUID) {
        guard let index = pendingSupportingDocuments.firstIndex(where: { $0.id == id }) else { return }
        pendingSupportingDocuments[index].visibility = visibility
    }

    private func confirmCharacterImport() {
        guard let data = pendingCharacterPackage else { return }
        isImportingCharacter = true
        characterImportMessage = ""
        Task {
            do {
                let imported = try await session.importCharacterPackage(
                    data,
                    visualReferences: pendingVisualReferences,
                    supportingDocuments: pendingSupportingDocuments,
                    host: host
                )
                characterImportMessage = "Added \(imported.name). It is selected and ready to join."
                pendingCharacterPackage = nil
                pendingCharacterPreview = nil
                pendingVisualReferences = []
                pendingSupportingDocuments = []
            } catch {
                characterImportMessage = error.localizedDescription
            }
            isImportingCharacter = false
        }
    }

    private func vitalsCard(_ character: GameSessionClient.CharacterSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(character.background.uppercased())
                .font(WayfolioTypography.caption)
                .tracking(1)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
            HStack(spacing: 8) {
                statTile("HP", "\(character.hp)/\(character.maximumHP)")
                statTile("AC", "\(character.armorClass)")
                statTile("INIT", signed(character.initiative))
            }
        }
        .padding(14)
        .parchmentSurface()
    }

    private func abilitiesCard(_ character: GameSessionClient.CharacterSummary) -> some View {
        let order = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
        return VStack(alignment: .leading, spacing: 10) {
            Label("Abilities", systemImage: "shield.lefthalf.filled")
                .font(WayfolioTypography.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(order, id: \.self) { key in
                    let score = character.abilities[key] ?? 10
                    statTile(String(key.prefix(3)).uppercased(), "\(score)  \(signed((score - 10) / 2))")
                }
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func skillsCard(_ character: GameSessionClient.CharacterSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Field Skills", systemImage: "leaf.fill")
                .font(WayfolioTypography.headline)
            ForEach(character.skills.keys.sorted(), id: \.self) { skill in
                HStack {
                    Text(skill).font(WayfolioTypography.body)
                    Spacer()
                    Text(signed(character.skills[skill] ?? 0))
                        .font(WayfolioTypography.headline)
                }
                if skill != character.skills.keys.sorted().last { Divider().opacity(0.35) }
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func collectionCard(title: String, symbol: String, values: [String], emptyMessage: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(WayfolioTypography.headline)
            if values.isEmpty, let emptyMessage {
                Text(emptyMessage)
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
            } else {
                ForEach(values, id: \.self) { value in
                    Label(value, systemImage: "diamond.fill")
                        .font(WayfolioTypography.body)
                        .symbolRenderingMode(.monochrome)
                }
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .parchmentSurface()
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(WayfolioTypography.caption).tracking(0.7)
            Text(value).font(WayfolioTypography.headline)
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(WayfolioPalette.brass.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
    }

    private var characterSubtitle: String {
        guard let character = session.character else { return "WAYFINDER • PLAYER ONE" }
        return "\(character.species.uppercased()) • \(character.className.uppercased()) \(character.level)"
    }

    private func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(statusTitle, systemImage: statusSymbol)
                .font(WayfolioTypography.headline)
                .foregroundStyle(WayfolioPalette.ink)

            if case .connected = session.state {
                Button("Create Character Transfer Code") { session.requestCharacterTransfer() }
                    .buttonStyle(.borderedProminent).tint(WayfolioPalette.navy)
                if let transferCode = session.transferCode {
                    Text("Transfer code: \(transferCode)")
                        .font(WayfolioTypography.title).textSelection(.enabled)
                    Text("Enter this on the new Wayfolio within five minutes. The old device will disconnect when the transfer completes.")
                        .font(WayfolioTypography.caption)
                }
                Button("Leave Session") { session.disconnect() }
                    .buttonStyle(.bordered)
                    .tint(WayfolioPalette.brass)
            } else {
                Picker("Character", selection: $session.selectedCharacterID) {
                    ForEach(session.characterCatalog) { character in
                        Text(character.name).tag(character.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(WayfolioPalette.navy)
                .foregroundStyle(WayfolioPalette.ink)
                TextField("Host address", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                TextField("Session code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                TextField("Transfer code (optional)", text: $incomingTransferCode)
                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                Button("Join Central Game") { session.connect(host: host, code: code, transferCode: incomingTransferCode) }
                    .buttonStyle(.borderedProminent)
                    .tint(WayfolioPalette.navy)
                    .disabled(session.state == .connecting)
            }

            if case .failed(let message) = session.state {
                Text(message)
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(.red)
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private var sceneCard: some View {
        WayfolioStoryCard(eyebrow: "Current scene", title: session.sceneTitle, text: session.sceneText)
    }

    private func promptCard(_ prompt: GameSessionClient.Prompt) -> some View {
        if prompt.allowsFreeform {
            AnyView(freeformPromptCard(prompt))
        } else {
            AnyView(WayfolioChoiceCard(prompt: prompt, onChoose: session.submitChoice))
        }
    }

    private func freeformPromptCard(_ prompt: GameSessionClient.Prompt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt.title).font(WayfolioTypography.headline)
            Text(prompt.message).font(WayfolioTypography.body)
            TextEditor(text: $storyAction)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .foregroundStyle(WayfolioPalette.ink)
                .background(Color.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(WayfolioPalette.brass, lineWidth: 1.4))
            HStack {
                Button { storyActionIsPublic = false } label: { Label("Private", systemImage: "eye.slash.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(storyActionIsPublic ? WayfolioPalette.parchmentDeep : WayfolioPalette.navy)
                Button { storyActionIsPublic = true } label: { Label("Public", systemImage: "person.3.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(storyActionIsPublic ? WayfolioPalette.navy : WayfolioPalette.parchmentDeep)
            }
            Button { submitStoryAction(isPublic: storyActionIsPublic) } label: {
                Label(storyActionIsPublic ? "Share with the table" : "Send privately to the DM", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(WayfolioPalette.navy)
            .disabled(storyAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func submitStoryAction(isPublic: Bool) {
        session.submitAction(storyAction, isPublic: isPublic)
        storyAction = ""
    }

    private func resultCard(_ result: GameSessionClient.CheckResult) -> some View {
        WayfolioResultCard(result: result)
    }

    private var waitingForRollCard: some View {
        WayfolioRollInstructionCard()
    }

    private var statusTitle: String {
        switch session.state {
        case .disconnected: "Not connected"
        case .connecting: "Joining the game…"
        case .connected(let code): "Connected • \(code)"
        case .failed: "Connection needs attention"
        }
    }

    private var statusSymbol: String {
        if case .connected = session.state { return "checkmark.circle.fill" }
        return "network"
    }
}

private struct CharacterInstructionsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    init() {}
    init(configuration: ReadConfiguration) throws {}
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(Self.instructions.utf8))
    }

    static let instructions = """
    WAYFOLIO CHARACTER IMPORT — CHATGPT INSTRUCTIONS

    Help me prepare my tabletop RPG character for the Wayfolio game system. Read the character sheets, notes, images, and background information I attach. Ask me to correct uncertain or conflicting information before creating the final file. Do not invent missing facts; use null. Preserve house rules and list them in house_rules. Separate public, DM-only, and player-only narrative information.

    Return the completed character as a downloadable JSON file named wayfolio-character.json. Never omit information because it does not fit a listed field. Put unusual or additional material in additional_material, retain its original wording, identify its source when known, and mark whether it is public, player_only, or dm_only. The JSON must use this structure:
    {
      "format": "wayfolio-character",
      "version": "1.0",
      "identity": {"name": null, "player_name": null, "pronouns": null, "species": null, "class": null, "subclass": null, "level": null, "background": null, "alignment": null, "age": null},
      "appearance": {"description": null, "portrait_description": null, "immutable_features": [], "palette": [], "never_change": []},
      "statistics": {"abilities": {"strength": null, "dexterity": null, "constitution": null, "intelligence": null, "wisdom": null, "charisma": null}, "proficiency_bonus": null, "armor_class": null, "initiative": null, "speed": null, "maximum_hp": null, "current_hp": null, "temporary_hp": null, "passive_perception": null},
      "saving_throws": [], "skills": [],
      "combat": {"armor_class": null, "initiative": null, "maximum_hp": null, "current_hp": null},
      "attacks": [], "abilities": [], "spellcasting": {"ability": null, "save_dc": null, "attack_bonus": null, "cantrips": [], "spells": [], "slots": {}},
      "inventory": [], "equipment": [], "currency": {},
      "background": {"history": null, "personality": null, "ideals": null, "bonds": null, "flaws": null, "goals": null, "fears": null, "speech_style": null, "voice_guidance": null},
      "relationships": [],
      "campaign_knowledge": {"locations": [], "people": [], "creatures": [], "discoveries": [], "quests": [], "journal": []},
      "companions": [],
      "privacy": {"public": {}, "dm_only": {}, "player_only": {}},
      "media": [], "house_rules": [], "import_notes": [], "source_files": [],
      "additional_material": [{"title": null, "content": null, "visibility": "player_only", "source": null}]
    }

    In appearance.immutable_features, record the identity traits that must remain stable in every generated image: face, hair, eyes, skin/fur, ears, tail, markings, body proportions, age presentation, and other species traits. Put approved colors in appearance.palette. Put common generation errors and forbidden alterations in appearance.never_change.

    Use numbers for numeric values and booleans for yes/no values. Skills should be objects with name and modifier. Inventory and equipment entries should have a name, quantity, description, equipped, and slot when known. Unknown and custom sections are allowed and must be preserved; do not turn them into game mechanics unless the supplied rules explicitly support them.

    After I approve your review, provide the downloadable JSON file and return any approved portrait, full-body, turnaround, or expression images as separate downloadable files. I will save the JSON, images, and any supporting PDF, text, or RTF notes together. In Wayfolio I will choose Profile → Session → Bring Your Character → Choose Complete Character Package and select all of those files in one action. Supporting filenames containing "public", "player-only", or "dm-only" will receive that privacy classification; otherwise Wayfolio keeps them player-only.
    """
}

private struct CharacterPackagePreview {
    let name: String
    let species: String
    let className: String
    let level: Int
    let maximumHP: Int?
    let armorClass: Int?
    let itemCount: Int
    let loreFieldCount: Int
    let extraSectionCount: Int
    let warnings: [String]

    init(data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WayfolioCharacterImport", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "This is not a readable JSON character file."])
        }
        if let format = root["format"] as? String, format != "wayfolio-character" {
            throw NSError(domain: "WayfolioCharacterImport", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "This file was not created as a Wayfolio character package."])
        }
        let identity = root["identity"] as? [String: Any] ?? [:]
        let statistics = root["statistics"] as? [String: Any] ?? [:]
        let combat = root["combat"] as? [String: Any] ?? [:]
        guard let value = (identity["name"] ?? root["name"]) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "WayfolioCharacterImport", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "The character file does not contain a name."])
        }
        name = value
        species = identity["species"] as? String ?? identity["ancestry"] as? String ?? "Unknown ancestry"
        className = identity["class"] as? String ?? identity["class_name"] as? String ?? "Adventurer"
        level = Self.integer(identity["level"]) ?? 1
        maximumHP = Self.integer(statistics["maximum_hp"] ?? combat["maximum_hp"])
        armorClass = Self.integer(statistics["armor_class"] ?? combat["armor_class"])
        itemCount = (root["inventory"] as? [Any] ?? []).count + (root["equipment"] as? [Any] ?? []).count
        loreFieldCount = Self.populatedValueCount(root["background"])
        let knownKeys: Set<String> = ["format", "version", "identity", "appearance", "statistics", "saving_throws",
            "skills", "combat", "attacks", "abilities", "spellcasting", "inventory", "equipment", "currency",
            "background", "relationships", "campaign_knowledge", "companions", "privacy", "media", "house_rules",
            "import_notes", "source_files", "additional_material", "visual_references", "source_documents"]
        extraSectionCount = root.keys.filter { !knownKeys.contains($0) }.count
            + ((root["additional_material"] as? [Any])?.count ?? 0)
        var values: [String] = []
        if maximumHP == nil { values.append("Maximum HP is missing.") }
        if armorClass == nil { values.append("Armor Class is missing.") }
        if root["skills"] == nil { values.append("Skills are missing.") }
        warnings = values
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func populatedValueCount(_ value: Any?) -> Int {
        if let dictionary = value as? [String: Any] {
            return dictionary.values.reduce(0) { $0 + populatedValueCount($1) }
        }
        if let array = value as? [Any] {
            return array.reduce(0) { $0 + populatedValueCount($1) }
        }
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1 }
        return value is NSNull || value == nil ? 0 : 1
    }
}
