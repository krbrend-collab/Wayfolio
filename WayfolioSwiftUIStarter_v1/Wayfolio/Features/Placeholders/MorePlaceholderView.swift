import SwiftUI

struct MorePlaceholderView: View {
    var body: some View {
        WayfolioCharacterView(onOpenItem: { _ in })
    }
}

struct WayfolioCharacterView: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @State private var selectedPage: WayfolioCharacterPage = .overview
    @State private var selectedItem: WayfolioItemPresentation?
    let onOpenItem: (String) -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                WayfolioRootTitle(title: "Character", subtitle: "Active Wayfinder")
                pagePicker
                pageContent
            }

            if let selectedItem {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .onTapGesture { closeItem() }
                WayfolioFloatingItemDetail(
                    item: selectedItem,
                    canUse: false,
                    onUse: {},
                    onClose: closeItem
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy(duration: 0.24), value: selectedItem?.id)
    }

    private var pagePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WayfolioCharacterPage.allCases) { page in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedPage = page
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(selectedPage == page ? WayfolioPalette.brassBright : WayfolioPalette.brass.opacity(0.38))
                                .frame(width: 5, height: 5)
                            WayfolioApprovedIcon(page.featureIcon, size: 24)
                            Text(page.title)
                        }
                            .font(WayfolioTypography.caption)
                            .foregroundStyle(selectedPage == page ? WayfolioPalette.cyan : WayfolioPalette.parchment.opacity(0.82))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 42)
                            .background(.ultraThinMaterial, in: Capsule())
                            .background(Capsule().fill(WayfolioPalette.navy.opacity(selectedPage == page ? 0.44 : 0.25)))
                            .overlay(Capsule().stroke(selectedPage == page ? WayfolioPalette.cyan : WayfolioPalette.brass.opacity(0.58), lineWidth: selectedPage == page ? 1.4 : 1))
                            .shadow(color: selectedPage == page ? WayfolioPalette.cyan.opacity(0.28) : .clear, radius: 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(page.title)
                    .accessibilityValue(selectedPage == page ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selectedPage == page ? .isSelected : [])
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.leading)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .overview:
            WayfolioCharacterOverviewView()
        case .abilities:
            WayfolioAbilitiesView()
        case .equipment:
            WayfolioEquipmentLoadoutView(onOpenItem: openEquipmentItem)
        case .bonds:
            WayfolioBondsView()
        case .notesTraits:
            WayfolioNotesTraitsView()
        }
    }

    private func openEquipmentItem(_ name: String) {
        audio.playUISound("navigation_select")
        selectedItem = WayfolioItemCatalog.equipmentRecord(for: name) ?? WayfolioItemCatalog.record(for: name)
    }

    private func closeItem() {
        audio.playUISound("navigation_back")
        selectedItem = nil
    }
}

private enum WayfolioCharacterPage: String, CaseIterable, Identifiable {
    case overview
    case abilities
    case equipment
    case bonds
    case notesTraits

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .abilities: "Abilities"
        case .equipment: "Equipment"
        case .bonds: "Bonds"
        case .notesTraits: "Notes & Traits"
        }
    }

    var featureIcon: WayfolioFeatureIcon {
        switch self {
        case .overview: .character
        case .abilities: .abilities
        case .equipment: .inventory
        case .bonds: .companion
        case .notesTraits: .abilities
        }
    }
}

private struct WayfolioAbilitiesView: View {
    @EnvironmentObject private var session: GameSessionClient

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                if let character = session.character {
                    abilityScores(character)
                    skillList(character)
                } else {
                    WayfolioStateCard(
                        kind: .empty,
                        title: "Abilities await the live record",
                        message: "Open the rabbit profile button, choose Session, and join the table to receive the selected character's current abilities and skill modifiers."
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func abilityScores(_ character: GameSessionClient.CharacterSummary) -> some View {
        let order = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                WayfolioApprovedIcon(.abilities, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ability Scores").font(WayfolioTypography.title)
                    Text("Host-published character values").font(WayfolioTypography.caption)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(order, id: \.self) { key in
                    let score = character.abilities[key] ?? 10
                    VStack(spacing: 3) {
                        Text(String(key.prefix(3)).uppercased()).font(WayfolioTypography.caption).tracking(0.7)
                        Text("\(score)  \(signed((score - 10) / 2))").font(WayfolioTypography.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(WayfolioPalette.brass.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func skillList(_ character: GameSessionClient.CharacterSummary) -> some View {
        let skills = character.skills.keys.sorted()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Field Skills").font(WayfolioTypography.title)
            ForEach(skills, id: \.self) { skill in
                HStack {
                    Text(skill.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(WayfolioTypography.body)
                    Spacer()
                    Text(signed(character.skills[skill] ?? 0)).font(WayfolioTypography.headline)
                }
                if skill != skills.last { Divider().opacity(0.32) }
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }

    private func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }
}

private struct WayfolioCharacterOverviewView: View {
    @EnvironmentObject private var session: GameSessionClient
    @State private var showingImageEditor = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                identityCard
                if let character = session.character {
                    vitalsCard(character)
                    abilityCard(character)
                    WayfolioNamedCollectionCard(title: "Traits", symbol: "hare.fill", values: character.traits)
                } else {
                    WayfolioStateCard(
                        kind: .empty,
                        title: "\(displayName)'s ledger is ready",
                        message: "Open the rabbit profile button, choose Session, and join the table to receive live character values."
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
    }

    private var displayName: String {
        session.character?.name ?? session.playerName
    }

    private var identityCard: some View {
        VStack(spacing: 4) {
            CharacterManifestationView(
                characterID: session.selectedCharacterID,
                characterName: session.character?.name ?? session.playerName
            )
            .frame(height: 248)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(WayfolioTypography.display)
                Text(characterSubtitle)
                    .font(WayfolioTypography.caption)
                    .tracking(0.8)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.64))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.top, 2)

            Button {
                showingImageEditor = true
            } label: {
                Label("Edit portrait", systemImage: "photo.badge.plus")
                    .font(WayfolioTypography.caption)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .foregroundStyle(WayfolioPalette.cyan)
                    .background(WayfolioPalette.navy.opacity(0.86), in: Capsule())
                    .overlay(Capsule().stroke(WayfolioPalette.brass, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(session.character?.name ?? session.playerName) image")
        }
        .foregroundStyle(WayfolioPalette.parchment)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .sheet(isPresented: $showingImageEditor) {
            CharacterImageEditor(
                characterID: session.selectedCharacterID,
                characterName: session.character?.name ?? session.playerName
            )
        }
    }

    private var characterSubtitle: String {
        guard let character = session.character else { return "AWAITING LIVE CHARACTER RECORD" }
        return "\(character.species.uppercased()) · \(character.className.uppercased()) \(character.level)"
    }

    private func vitalsCard(_ character: GameSessionClient.CharacterSummary) -> some View {
        HStack(spacing: 8) {
            statTile("HP", "\(character.hp)/\(character.maximumHP)")
            statTile("AC", "\(character.armorClass)")
            statTile("INIT", signed(character.initiative))
        }
        .padding(14)
        .parchmentSurface()
    }

    private func abilityCard(_ character: GameSessionClient.CharacterSummary) -> some View {
        let order = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
            ForEach(order, id: \.self) { key in
                let score = character.abilities[key] ?? 10
                statTile(String(key.prefix(3)).uppercased(), "\(score)  \(signed((score - 10) / 2))")
            }
        }
        .padding(14)
        .parchmentSurface()
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(WayfolioTypography.caption).tracking(0.7)
            Text(value).font(WayfolioTypography.body.weight(.semibold))
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(WayfolioPalette.brass.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
    }

    private func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }
}

private struct WayfolioActiveSlot: Identifiable {
    enum Occupancy {
        case occupied(title: String, detail: String)
        case open(message: String)
    }

    let id: String
    let label: String
    let symbol: String
    let occupancy: Occupancy

    var isOccupied: Bool {
        if case .occupied = occupancy { return true }
        return false
    }

    var displayTitle: String {
        switch occupancy {
        case .occupied(let title, _): title
        case .open: "Open slot"
        }
    }

    var displayDetail: String {
        switch occupancy {
        case .occupied(_, let detail): detail
        case .open(let message): message
        }
    }
}

/// Presentation slots for the host-published active equipment record.
private enum WayfolioEquipmentLayout {
    static let equipmentLayout: [(id: String, label: String, symbol: String)] = [
        ("protective-gear", "Protective Gear", "shield.fill"),
        ("primary-tool", "Primary tool", "wand.and.stars"),
        ("weapons", "Weapons", "bolt.fill"),
        ("spellcasting-focus", "Focus", "sparkles"),
        ("accessory", "Accessory", "diamond.fill"),
        ("field-utility", "Field utility", "backpack.fill")
    ]

    static func equipmentSlots(from items: [GameSessionClient.CharacterSummary.EquipmentItem]) -> [WayfolioActiveSlot] {
        equipmentLayout.map { layout in
            if let item = items.first(where: { normalized($0.slot) == normalized(layout.label) || normalized($0.slot) == layout.id }) {
                WayfolioActiveSlot(
                    id: layout.id,
                    label: layout.label,
                    symbol: layout.symbol,
                    occupancy: .occupied(title: item.name, detail: "\(item.detail) · Quality \(item.qualityLevel)")
                )
            } else {
                WayfolioActiveSlot(
                    id: layout.id,
                    label: layout.label,
                    symbol: layout.symbol,
                    occupancy: .open(message: "Available when the character record permits an assignment.")
                )
            }
        }
    }

    private static func normalized(_ value: String) -> String {
        let normalized = value.lowercased().replacingOccurrences(of: " ", with: "-")
        return normalized == "armor" ? "protective-gear" : normalized
    }
}

private struct WayfolioEquipmentLoadoutView: View {
    @EnvironmentObject private var session: GameSessionClient
    @State private var selectedSlotID = "protective-gear"
    let onOpenItem: (String) -> Void

    private var equipment: [GameSessionClient.CharacterSummary.EquipmentItem] {
        session.character?.equipment ?? []
    }

    private var slots: [WayfolioActiveSlot] {
        WayfolioEquipmentLayout.equipmentSlots(from: equipment)
    }

    private var selectedSlot: WayfolioActiveSlot {
        slots.first(where: { $0.id == selectedSlotID }) ?? slots[0]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                WayfolioLoadoutHeading(
                    eyebrow: "ACTIVE LOADOUT",
                    title: session.character?.name ?? "Renn Hazel",
                    summary: "A quick view of worn, carried, and available equipment positions.",
                    used: slots.filter(\.isOccupied).count,
                    capacity: slots.count
                )

                equipmentFigure
                WayfolioSlotDetailCard(slot: selectedSlot, onOpenItem: onOpenItem)
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var equipmentFigure: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 8
            let sideWidth = max(66, proxy.size.width * 0.27)
            let figureWidth = max(80, proxy.size.width - (sideWidth * 2) - (gap * 2))

            HStack(spacing: gap) {
                slotColumn(Array(slots.prefix(3)), width: sideWidth)
                WayfinderAppearanceReference(
                    characterID: session.selectedCharacterID,
                    characterName: session.character?.name ?? session.playerName
                )
                    .frame(width: figureWidth)
                slotColumn(Array(slots.suffix(3)), width: sideWidth)
            }
        }
        .frame(height: 430)
        .padding(10)
        .navySurface()
    }

    private func slotColumn(_ columnSlots: [WayfolioActiveSlot], width: CGFloat) -> some View {
        VStack(spacing: 9) {
            ForEach(columnSlots) { slot in
                WayfolioSlotTile(slot: slot, isSelected: selectedSlotID == slot.id) {
                    withAnimation(.snappy(duration: 0.2)) { selectedSlotID = slot.id }
                }
                .frame(width: width)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct WayfinderAppearanceReference: View {
    let characterID: String
    let characterName: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                WayfolioPalette.midnight

                if characterID == "renn" {
                    Image("renn_hazel_login_official")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                } else {
                    CharacterPortraitView(characterID: characterID, characterName: characterName, size: min(proxy.size.width * 0.84, 150))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }

                LinearGradient(
                    colors: [.clear, WayfolioPalette.midnight.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(spacing: 2) {
                    Text(characterName.uppercased())
                        .font(WayfolioTypography.headline)
                    Text("CURRENT APPEARANCE")
                        .font(WayfolioTypography.tiny)
                        .tracking(0.8)
                }
                .foregroundStyle(WayfolioPalette.parchment)
                .padding(.bottom, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(WayfolioPalette.brass.opacity(0.8), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current appearance reference for \(characterName)")
    }
}

private struct WayfolioSlotTile: View {
    let slot: WayfolioActiveSlot
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(slot.isOccupied ? WayfolioPalette.brass.opacity(0.15) : WayfolioPalette.midnight.opacity(0.7))
                    Image(systemName: slot.isOccupied ? slot.symbol : "plus")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(slot.isOccupied ? WayfolioPalette.brassBright : WayfolioPalette.cyan)
                }
                .frame(width: 43, height: 43)

                Text(slot.label.uppercased())
                    .font(WayfolioTypography.tiny)
                    .tracking(0.4)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(slot.isOccupied ? slot.displayTitle : "OPEN")
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(slot.isOccupied ? WayfolioPalette.parchment.opacity(0.75) : WayfolioPalette.cyan)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(WayfolioPalette.parchment)
            .frame(maxWidth: .infinity, minHeight: 116)
            .padding(6)
            .navySurface(radius: 13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? WayfolioPalette.cyan : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(slot.label), \(slot.displayTitle)")
        .accessibilityHint("Shows slot details")
    }
}

private struct WayfolioSlotDetailCard: View {
    let slot: WayfolioActiveSlot
    let onOpenItem: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(slot.label, systemImage: slot.isOccupied ? slot.symbol : "plus.circle")
                    .font(WayfolioTypography.headline)
                Spacer()
                Text(slot.isOccupied ? "ACTIVE" : "OPEN")
                    .font(WayfolioTypography.tiny)
                    .tracking(0.8)
                    .foregroundStyle(slot.isOccupied ? WayfolioPalette.ink.opacity(0.58) : WayfolioPalette.navy)
            }
            Text(slot.displayTitle)
                .font(WayfolioTypography.title)
            Text(slot.displayDetail)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
            if slot.isOccupied {
                Button {
                    onOpenItem(slot.displayTitle)
                } label: {
                    HStack {
                        Text("View item record")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WayfolioPalette.navy)
                .padding(.top, 4)
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .parchmentSurface()
    }
}

private struct WayfolioMagicLoadoutView: View {
    @EnvironmentObject private var session: GameSessionClient

    private var magic: [String] {
        session.character?.magic ?? []
    }

    private var availableSlots: Int {
        session.character?.resources["level_1_slots_current"] ?? 0
    }

    private var maximumSlots: Int {
        session.character?.resourceLimits["level_1_slots_max"] ?? availableSlots
    }

    private var spellSlots: [WayfolioActiveSlot] {
        guard maximumSlots > 0 else { return [] }
        return (0..<maximumSlots).map { index in
            WayfolioActiveSlot(
                id: "spell-\(index + 1)",
                label: "Slot \(index + 1)",
                symbol: "sparkle",
                occupancy: index < availableSlots
                    ? .occupied(title: "Ready", detail: "Available in the host-published character state.")
                    : .open(message: "Spent in the host-published character state.")
            )
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                WayfolioLoadoutHeading(
                    eyebrow: "MAGIC LOADOUT",
                    title: "Spell Capacity",
                    summary: "Known magic and current capacity from the connected character record.",
                    used: availableSlots,
                    capacity: maximumSlots
                )

                if spellSlots.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No spell capacity published", message: "Spell slots appear only when the connected character record supplies them.")
                } else {
                    WayfolioCapacitySlots(
                        title: "First-Circle Spell Slots",
                        slots: spellSlots,
                        note: "Ready and spent states follow the authoritative host resource record."
                    )
                }

                WayfolioNamedCollectionCard(title: "Known Magic", symbol: "sparkles", values: magic)
                WayfolioNamedCollectionCard(title: "Traits", symbol: "hare.fill", values: session.character?.traits ?? [])
                if magic.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No magic published", message: "Known spells and abilities will appear when the connected character record supplies them.")
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WayfolioNotesTraitsView: View {
    @EnvironmentObject private var session: GameSessionClient

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                WayfolioNamedCollectionCard(title: "Traits", symbol: "hare.fill", values: session.character?.traits ?? [])
                WayfolioNamedCollectionCard(title: "Known Magic", symbol: "sparkles", values: session.character?.magic ?? [])
                WayfolioNamedCollectionCard(title: "Character Notes", symbol: "note.text", values: session.completedWork)
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WayfolioBondsView: View {
    @EnvironmentObject private var session: GameSessionClient

    private var bonds: [GameSessionClient.KnowledgeRecord] {
        var seen = Set<String>()
        return (session.companions + session.knownPeople).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                WayfolioLoadoutHeading(
                    eyebrow: "PEOPLE & COMPANIONS",
                    title: "Bonds",
                    summary: "Relationships and traveling companions known to this character.",
                    used: bonds.count,
                    capacity: max(1, bonds.count)
                )
                if bonds.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No bonds published", message: "Relationships appear only as the active journey confirms them.")
                } else {
                    ForEach(bonds) { bond in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bond.status.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(WayfolioTypography.tiny).tracking(0.8)
                            Text(bond.name).font(WayfolioTypography.title)
                            Text(bond.notes.joined(separator: " ")).font(WayfolioTypography.body)
                                .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
                        }
                        .foregroundStyle(WayfolioPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .parchmentSurface()
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WayfolioCraftingLoadoutView: View {
    @EnvironmentObject private var session: GameSessionClient

    private var tools: [String] {
        let source = session.inventory
        let matches = source.filter {
            let value = $0.lowercased()
            return value.contains("kit") || value.contains("utensil") || value.contains("tool")
        }
        return matches
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                WayfolioLoadoutHeading(
                    eyebrow: "CRAFTING LOADOUT",
                    title: "Active Work",
                    summary: "Current projects and tools published by the connected journey.",
                    used: nil,
                    capacity: tools.count,
                    metricText: "Awaiting host-published projects"
                )

                WayfolioStateCard(kind: .empty, title: "No active project published", message: "Project capacity and assignments remain absent until the host supplies an authoritative crafting record.")

                WayfolioNamedCollectionCard(title: "Available Tools", symbol: "wrench.and.screwdriver.fill", values: tools)
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WayfolioCompanionLoadoutView: View {
    @EnvironmentObject private var session: GameSessionClient

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                WayfolioLoadoutHeading(
                    eyebrow: "TRAVELING COMPANIONS",
                    title: "Bonded Company",
                    summary: "Only creatures actively assigned to travel with the character belong in these places.",
                    used: session.companions.count,
                    capacity: max(2, session.companions.count)
                )

                WayfolioCapacitySlots(
                    title: "Taming Capacity",
                    slots: companionSlots,
                    note: "Only companions confirmed by the active journey are shown."
                )

                if session.companions.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No confirmed companion", message: "A creature appears here only after the journey confirms it is traveling with this character.")
                } else {
                    ForEach(session.companions) { companion in companionCard(companion) }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var companionSlots: [WayfolioActiveSlot] {
        let occupied = session.companions.enumerated().map { index, companion in
            WayfolioActiveSlot(id: companion.id, label: "Companion \(index + 1)", symbol: "drop.fill",
                               occupancy: .occupied(title: companion.name, detail: companion.notes.first ?? "Confirmed traveling companion."))
        }
        let openCount = max(0, 2 - occupied.count)
        return occupied + (0..<openCount).map { index in
            WayfolioActiveSlot(id: "open-companion-\(index)", label: "Open", symbol: "pawprint.fill",
                               occupancy: .open(message: "No companion assigned."))
        }
    }

    private func companionCard(_ companion: GameSessionClient.KnowledgeRecord) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "drop.fill")
                .font(.system(size: 38))
                .foregroundStyle(WayfolioPalette.cyan)
                .frame(width: 92, height: 92)
                .background(WayfolioPalette.navy, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(WayfolioPalette.brass, lineWidth: 1))
            VStack(alignment: .leading, spacing: 5) {
                Text(companion.name.uppercased())
                    .font(WayfolioTypography.caption)
                    .tracking(0.8)
                Text("Journey-confirmed companion")
                    .font(WayfolioTypography.headline)
                Text(companion.notes.joined(separator: " "))
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.68))
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .parchmentSurface()
    }
}

private struct WayfolioLoadoutHeading: View {
    let eyebrow: String
    let title: String
    let summary: String
    let used: Int?
    let capacity: Int
    var metricText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow)
                    .font(WayfolioTypography.caption)
                    .tracking(1)
                Spacer()
            }
            Text(title)
                .font(WayfolioTypography.title)
            Text(summary)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.68))
            HStack(spacing: 6) {
                if let metricText {
                    Text(metricText)
                } else if let used {
                    Text("\(used) of \(capacity) active")
                } else {
                    Text("\(capacity) recorded places")
                }
                Spacer()
                ForEach(0..<capacity, id: \.self) { index in
                    Circle()
                        .fill(used.map { index < $0 } == true ? WayfolioPalette.navy : WayfolioPalette.navy.opacity(0.14))
                        .overlay(Circle().stroke(WayfolioPalette.navy.opacity(0.42), lineWidth: 1))
                        .frame(width: 10, height: 10)
                }
            }
            .font(WayfolioTypography.caption)
        }
        .foregroundStyle(WayfolioPalette.ink)
        .padding(14)
        .parchmentSurface()
    }
}

private struct WayfolioCapacitySlots: View {
    let title: String
    let slots: [WayfolioActiveSlot]
    let note: String

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(WayfolioTypography.headline)
                .foregroundStyle(WayfolioPalette.parchment)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(slots) { slot in
                    VStack(spacing: 8) {
                        Image(systemName: slot.isOccupied ? slot.symbol : "plus")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(slot.isOccupied ? WayfolioPalette.brassBright : WayfolioPalette.cyan)
                            .frame(height: 30)
                        Text(slot.label.uppercased())
                            .font(WayfolioTypography.tiny)
                            .tracking(0.7)
                        Text(slot.displayTitle)
                            .font(WayfolioTypography.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .foregroundStyle(WayfolioPalette.parchment)
                    .frame(maxWidth: .infinity, minHeight: 112)
                    .padding(10)
                    .background(WayfolioPalette.midnight.opacity(0.72), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(slot.isOccupied ? WayfolioPalette.brass : WayfolioPalette.cyan.opacity(0.7), lineWidth: 1))
                    .accessibilityElement(children: .combine)
                }
            }

            Text(note)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.mutedText)
        }
        .padding(14)
        .navySurface()
    }
}

private struct WayfolioNamedCollectionCard: View {
    let title: String
    let symbol: String
    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(WayfolioTypography.headline)
            ForEach(values, id: \.self) { value in
                HStack(spacing: 9) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7))
                    Text(value)
                        .font(WayfolioTypography.body)
                    Spacer()
                }
                if value != values.last { Divider().opacity(0.32) }
            }
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .parchmentSurface()
    }
}

struct WayfolioPackView: View {
    @EnvironmentObject private var session: GameSessionClient
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @State private var selectedPage: WayfolioPackPage = .carried
    @State private var selectedCategory: WayfolioItemCategory?
    @State private var selectedItem: WayfolioItemPresentation?
    let onOpenItem: (String) -> Void

    private var records: [WayfolioItemPresentation] {
        if !session.inventoryItems.isEmpty {
            return session.inventoryItems.map(WayfolioItemCatalog.record(for:))
        }
        return session.inventory.map(WayfolioItemCatalog.record(for:))
    }

    private var visibleRecords: [WayfolioItemPresentation] {
        switch selectedPage {
        case .carried:
            return records
        case .quickAccess:
            return records.filter { [.gear, .remedy, .equipment].contains($0.category) }
        case .materials:
            return records.filter { $0.category == .ingredient }
        }
    }

    private var filteredRecords: [WayfolioItemPresentation] {
        guard let selectedCategory else { return visibleRecords }
        return visibleRecords.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                WayfolioRootTitle(title: "Pack", subtitle: "Carried Goods & Craft")
                packTabs
                inventoryContent
            }

            if let selectedItem {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closeItem() }

                WayfolioFloatingItemDetail(
                    item: selectedItem,
                    canUse: selectedItem.consumable,
                    onUse: { use(selectedItem) },
                    onClose: closeItem
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.snappy(duration: 0.24), value: selectedItem?.id)
    }

    private var packTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WayfolioPackPage.allCases) { page in
                    WayfolioFilterChip(title: page.title, selected: selectedPage == page) {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedPage = page
                            selectedCategory = nil
                        }
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var inventoryContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                WayfolioLoadoutHeading(
                    eyebrow: selectedPage.eyebrow,
                    title: selectedPage.heading,
                    summary: selectedPage.summary,
                    used: records.count,
                    capacity: max(records.count, 1)
                )

                if selectedPage == .materials {
                    categoryControls
                }

                if filteredRecords.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No recorded items", message: "Nothing in this category has been published to this Wayfolio.")
                } else if selectedCategory == nil {
                    inventoryGrid
                } else {
                    inventoryRows
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var categoryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BROWSE")
                .font(WayfolioTypography.tiny)
                .tracking(1)
                .foregroundStyle(WayfolioPalette.cyan)
            Menu {
                Button("All Materials") { selectedCategory = nil }
                ForEach(WayfolioItemCategory.materialCategories, id: \.self) { category in
                    Button(category.rawValue) { selectedCategory = category }
                }
            } label: {
                HStack {
                    Text(selectedCategory?.rawValue ?? "All Materials")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .projectionPane(.compact, radius: 12)
            }
            Text("CURRENT CATEGORY · \(selectedCategory?.rawValue.uppercased() ?? "ALL MATERIALS")")
                .font(WayfolioTypography.tiny)
                .tracking(0.7)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inventoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
            ForEach(filteredRecords) { item in
                Button { open(item) } label: {
                    WayfolioItemGridCard(item: item)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(item.name), \(item.category.rawValue)")
            }
        }
    }

    private var inventoryRows: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredRecords) { item in
                Button { open(item) } label: { WayfolioItemRow(item: item) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(item.name), \(item.category.rawValue)")
            }
        }
    }

    private func open(_ item: WayfolioItemPresentation) {
        audio.playUISound("navigation_select")
        selectedItem = item
    }

    private func closeItem() {
        audio.playUISound("navigation_back")
        selectedItem = nil
    }

    private func use(_ item: WayfolioItemPresentation) {
        guard let source = item.sourceItem else { return }
        session.useItem(source)
        selectedItem = nil
    }
}

private enum WayfolioPackPage: String, CaseIterable, Identifiable {
    case carried
    case quickAccess
    case materials

    var id: Self { self }

    var title: String {
        switch self {
        case .carried: "Carried"
        case .quickAccess: "Quick Access"
        case .materials: "Materials"
        }
    }

    var eyebrow: String {
        switch self {
        case .carried: "CURRENT CARRY"
        case .quickAccess: "QUICK ACCESS"
        case .materials: "MATERIALS"
        }
    }

    var heading: String {
        switch self {
        case .carried: "Field Loadout"
        case .quickAccess: "Within Reach"
        case .materials: "Gathered Materials"
        }
    }

    var summary: String {
        switch self {
        case .carried: "The carried inventory published by the active journey."
        case .quickAccess: "A smaller set of useful items that can be reached quickly during play."
        case .materials: "Browse all known materials or select a category for a detailed list."
        }
    }
}

private enum WayfolioItemCategory: String, Hashable, CaseIterable {
    case gear = "Gear"
    case remedy = "Remedy"
    case ingredient = "Ingredient"
    case quest = "Quest Item"
    case equipment = "Equipment"

    static var materialCategories: [Self] { [.ingredient] }
}

private struct WayfolioItemArtwork: View {
    let item: WayfolioItemPresentation
    let size: CGFloat

    var body: some View {
        Group {
            if let assetName = item.artAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else if let rawURL = item.artURL, let url = URL(string: rawURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        missingArt
                    }
                }
            } else {
                missingArt
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay(RoundedRectangle(cornerRadius: size * 0.22).stroke(WayfolioPalette.cyan.opacity(0.34), lineWidth: 1))
    }

    private var missingArt: some View {
        ZStack {
            WayfolioPalette.navy.opacity(0.56)
            Image(systemName: item.symbol)
                .font(.system(size: max(18, size * 0.44), weight: .semibold))
                .foregroundStyle(WayfolioPalette.cyan)
                .shadow(color: WayfolioPalette.cyan.opacity(0.34), radius: 5)
        }
        .accessibilityLabel("Symbol for \(item.name)")
    }
}

private struct WayfolioItemPresentation: Identifiable, Equatable {
    let id: String
    let name: String
    let category: WayfolioItemCategory
    let symbol: String
    let summary: String
    let knownUse: String
    let fieldNote: String
    let statChanges: [WayfolioStatChange]
    let quantity: Int
    let artAssetName: String?
    let artURL: String?
    let consumable: Bool
    let sourceItem: GameSessionClient.InventoryItem?
}

private struct WayfolioStatChange: Identifiable, Equatable {
    enum Direction { case increase, decrease }

    let label: String
    let direction: Direction
    var id: String { label }
}

private struct WayfolioItemGridCard: View {
    let item: WayfolioItemPresentation

    var body: some View {
        VStack(spacing: 7) {
            WayfolioItemArtwork(item: item, size: 48)
            Text(item.name)
                .font(WayfolioTypography.tiny)
                .foregroundStyle(WayfolioPalette.parchment)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if !item.statChanges.isEmpty {
                WayfolioStatChangeChips(changes: item.statChanges)
            }
            if item.quantity > 1 {
                Text("×\(item.quantity)").font(WayfolioTypography.tiny).foregroundStyle(WayfolioPalette.brass)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .top)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .projectionPane(.list, radius: 13)
    }
}

private struct WayfolioFloatingItemDetail: View {
    let item: WayfolioItemPresentation
    let canUse: Bool
    let onUse: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                WayfolioItemArtwork(item: item, size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.category.rawValue.uppercased())
                        .font(WayfolioTypography.tiny)
                        .tracking(1)
                        .foregroundStyle(WayfolioPalette.cyan)
                    Text(item.name)
                        .font(WayfolioTypography.title)
                        .foregroundStyle(WayfolioPalette.parchment)
                }
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(WayfolioPalette.parchment)
                .accessibilityLabel("Close item details")
            }

            Text(item.summary)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.90))
            if !item.statChanges.isEmpty {
                WayfolioStatChangeChips(changes: item.statChanges)
            }
            Divider().overlay(WayfolioPalette.cyan.opacity(0.30))
            detail("KNOWN USE", item.knownUse)
            detail("FIELD NOTE", item.fieldNote)

            if canUse {
                Button(action: onUse) {
                    Label("Use Item", systemImage: "sparkles")
                        .font(WayfolioTypography.caption)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(WayfolioPalette.brass)
                .accessibilityHint("Sends this item use to the game host for resolution")
            }
        }
        .padding(18)
        .projectionPane(.detail, radius: 20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(WayfolioPalette.cyan.opacity(0.52), lineWidth: 1))
        .shadow(color: WayfolioPalette.cyan.opacity(0.38), radius: 24)
        .accessibilityElement(children: .contain)
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(WayfolioTypography.tiny)
                .tracking(1)
                .foregroundStyle(WayfolioPalette.cyan)
            Text(value)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.78))
        }
    }
}

private enum WayfolioItemCatalog {
    static func record(for source: GameSessionClient.InventoryItem) -> WayfolioItemPresentation {
        let base = record(for: source.name)
        let authoritativeCategory = source.category.flatMap { raw in
            WayfolioItemCategory.allCases.first { $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame }
        } ?? base.category
        let changes = source.mechanicalDeltas.map { delta in
            WayfolioStatChange(
                label: "\(delta.label) \(delta.value)",
                direction: delta.direction.lowercased() == "decrease" ? .decrease : .increase
            )
        }
        return .init(
            id: source.id,
            name: source.name,
            category: authoritativeCategory,
            symbol: base.symbol,
            summary: base.summary,
            knownUse: base.knownUse,
            fieldNote: base.fieldNote,
            statChanges: changes,
            quantity: source.quantity,
            artAssetName: source.artAssetName,
            artURL: source.artURL,
            consumable: source.consumable,
            sourceItem: source
        )
    }

    static func record(for name: String) -> WayfolioItemPresentation {
        let value = name.lowercased()
        if value.contains("potion of healing") {
            return item(name, .remedy, "cross.vial.fill", "A healing potion brewed by Renn.", "Restorative use is governed by the active game rules.", "Prepared and carried as part of Renn's field practice.")
        }
        if value.contains("healer's kit") {
            return item(name, .remedy, "cross.case.fill", "A field kit for practical care.", "Its available uses and outcomes come from the campaign state.", "Carried with Renn's other herbalist tools.")
        }
        if value.contains("ingredient") || value.contains("remedy containers") {
            return item(name, .ingredient, "leaf.fill", "Containers for gathered ingredients and prepared remedies.", "Supports organized fieldwork and crafting when gameplay permits.", "Contents are shown only when published by the host.")
        }
        if value.contains("field journal") {
            return item(name, .quest, "book.closed.fill", "Renn's field journal and recipe collection.", "Records observations and known recipes.", "Player notes remain separate from host-published campaign facts.")
        }
        if value == "wayfolio" {
            return item(name, .quest, "sparkles.rectangle.stack.fill", "Renn's personal luminous ledger.", "Carries private player information and sends player intent.", "The Wayfolio does not decide story outcomes or campaign state.")
        }
        if value.contains("herbalism kit") {
            return item(name, .gear, "leaf.circle.fill", "Renn's herbalism tools.", "Available for herbal fieldwork when gameplay exposes an action.", "Part of Renn's established herbalist equipment.")
        }
        if value.contains("cook") || value.contains("utensil") {
            return item(name, .gear, "fork.knife", "Compact cook's utensils and wooden spoon.", "Available as carried field equipment.", "Packed for practical camp use.")
        }
        if value.contains("fire") {
            return item(name, .gear, "flame.fill", "Practical fire-starting gear.", "Available as carried field equipment.", "No use is resolved by this record screen.")
        }
        if value.contains("pack") {
            return item(name, .gear, "backpack.fill", "Renn's herbalist field pack.", "Carries published inventory.", "Capacity and encumbrance are not currently published.")
        }
        return item(name, .gear, "shippingbox.fill", "A carried item recorded by the campaign host.", "Known uses appear when published.", "No additional information has been recorded.")
    }

    static func equipmentRecord(for name: String) -> WayfolioItemPresentation? {
        switch name {
        case "Hemlock movement armor":
            return item(name, .equipment, "shield.fill", "Studded-leather equivalent; AC 15 with DEX 16; no shield.", "Worn armor.", "Built for movement through Hemlock terrain.")
        case "Retractable ring-headed staff":
            return item(name, .equipment, "wand.and.stars", "Quarterstaff; Topple mastery; field tool and defensive control.", "Primary tool and ordinary quarterstaff.", "The staff is not Renn's spellcasting focus.")
        case "Four kunai-style daggers":
            return item(name, .equipment, "bolt.fill", "Ordinary daggers; finesse, light and thrown.", "Carried weapons.", "Four kunai-style daggers are recorded in the active loadout.")
        case "Hemlock-sprig belt locket":
            return item(name, .equipment, "sparkles", "Preserved sprig from the great Hemlock.", "Renn's spellcasting focus.", "The staff is not the focus.")
        default:
            return nil
        }
    }

    private static func item(
        _ name: String,
        _ category: WayfolioItemCategory,
        _ symbol: String,
        _ summary: String,
        _ knownUse: String,
        _ fieldNote: String,
        statChanges: [WayfolioStatChange] = []
    ) -> WayfolioItemPresentation {
        .init(
            id: name.lowercased(),
            name: name,
            category: category,
            symbol: symbol,
            summary: summary,
            knownUse: knownUse,
            fieldNote: fieldNote,
            statChanges: statChanges,
            quantity: 1,
            artAssetName: nil,
            artURL: nil,
            consumable: false,
            sourceItem: nil
        )
    }
}

private struct WayfolioStatChangeChips: View {
    let changes: [WayfolioStatChange]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(changes) { change in
                Text(change.label)
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(change.direction == .increase ? WayfolioPalette.emerald : WayfolioPalette.danger)
                    .padding(.horizontal, 7)
                    .frame(minHeight: 24)
                    .background(
                        (change.direction == .increase ? WayfolioPalette.emerald : WayfolioPalette.danger)
                            .opacity(0.13),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                (change.direction == .increase ? WayfolioPalette.emerald : WayfolioPalette.danger)
                                    .opacity(0.62),
                                lineWidth: 1
                            )
                    }
            }
        }
    }
}

private struct WayfolioItemRow: View {
    let item: WayfolioItemPresentation

    var body: some View {
        HStack(spacing: 12) {
            WayfolioItemArtwork(item: item, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.category.rawValue.uppercased())
                    .font(WayfolioTypography.tiny)
                    .tracking(0.8)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.56))
                Text(item.name)
                    .font(WayfolioTypography.headline)
                    .foregroundStyle(WayfolioPalette.ink)
                    .multilineTextAlignment(.leading)
                Text(item.summary)
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.66))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .foregroundStyle(WayfolioPalette.ink.opacity(0.48))
        }
        .padding(13)
        .parchmentSurface(radius: WayfolioMetrics.cardRadius)
    }
}

struct WayfolioItemDetailView: View {
    let itemName: String

    private var item: WayfolioItemPresentation {
        WayfolioItemCatalog.equipmentRecord(for: itemName) ?? WayfolioItemCatalog.record(for: itemName)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: WayfolioMetrics.sectionGap) {
                VStack(spacing: 12) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(WayfolioPalette.brassBright)
                        .frame(width: 116, height: 116)
                        .background(Circle().fill(WayfolioPalette.navy))
                        .overlay(Circle().stroke(WayfolioPalette.brass, lineWidth: 1.4))
                    Text(item.name)
                        .font(WayfolioTypography.display)
                        .multilineTextAlignment(.center)
                    Text(item.category.rawValue.uppercased())
                        .font(WayfolioTypography.caption)
                        .tracking(1)
                        .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
                }
                .foregroundStyle(WayfolioPalette.ink)
                .frame(maxWidth: .infinity)
                .padding(18)
                .parchmentSurface()

                recordSection("Known Record", item.summary, symbol: "text.book.closed.fill")
                recordSection("Known Use", item.knownUse, symbol: "sparkles")
                recordSection("Field Note", item.fieldNote, symbol: "pencil.and.scribble")
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func recordSection(_ title: String, _ text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(WayfolioTypography.headline)
            Text(text)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.74))
        }
        .foregroundStyle(WayfolioPalette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .parchmentSurface()
    }
}

struct WayfolioWorldView: View {
    @State private var selectedPage: WayfolioWorldPage = .places
    let onOpenCreature: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            WayfolioRootTitle(title: "World", subtitle: "Places, People & Discovery")
            worldTabs
            pageContent
        }
    }

    private var worldTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WayfolioWorldPage.allCases) { page in
                    WayfolioFilterChip(title: page.title, selected: selectedPage == page) {
                        withAnimation(.snappy(duration: 0.2)) { selectedPage = page }
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .places:
            HemlockPlacesView()
        case .people:
            WayfolioPeopleView()
        case .creatures:
            EntriesView(onOpenCreature: onOpenCreature)
        case .botanicals:
            WayfolioBotanicalResearchView()
        }
    }
}

private struct WayfolioRootTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(WayfolioTypography.title)
            Spacer()
            Text(subtitle.uppercased()).font(WayfolioTypography.tiny).tracking(0.8)
                .foregroundStyle(WayfolioPalette.cyan.opacity(0.82))
        }
        .foregroundStyle(WayfolioPalette.parchment)
        .padding(.horizontal, WayfolioMetrics.contentInset)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private enum WayfolioWorldPage: String, CaseIterable, Identifiable {
    case places
    case creatures
    case botanicals
    case people

    var id: Self { self }
    var title: String {
        switch self {
        case .places: "Places"
        case .people: "People & Bonds"
        case .creatures: "Creatures"
        case .botanicals: "Botanicals"
        }
    }
}

private struct WayfolioPeopleView: View {
    @EnvironmentObject private var session: GameSessionClient

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if session.knownPeople.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No people recorded", message: "Named people appear here when the active journey confirms the selected character knows them.")
                } else {
                    ForEach(session.knownPeople) { person in
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 38))
                                .foregroundStyle(WayfolioPalette.cyan)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(person.status.replacingOccurrences(of: "_", with: " ").uppercased())
                                    .font(WayfolioTypography.tiny).tracking(0.8)
                                Text(person.name).font(WayfolioTypography.title)
                                Text(person.notes.joined(separator: " ")).font(WayfolioTypography.body)
                                    .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
                            }
                        }
                        .foregroundStyle(WayfolioPalette.ink).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).parchmentSurface()
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct HemlockPlacesView: View {
    @EnvironmentObject private var session: GameSessionClient
    @State private var selectedLocation: GameSessionClient.KnowledgeRecord?
    @State private var displayMode: PlaceDisplayMode = .map
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Picker("Place view", selection: $displayMode) {
                    ForEach(PlaceDisplayMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Label {
                    TextField("Search discovered places", text: $searchText)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
                .font(WayfolioTypography.body)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(WayfolioPalette.navy.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))

                if displayMode == .map {
                    Image("hemlock-map")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WayfolioPalette.cyan.opacity(0.68), lineWidth: 1))
                        .accessibilityLabel("Map of discovered places")
                }

                if filteredLocations.isEmpty && session.knownLocations.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No places recorded",
                                      message: "Places appear only when the active journey publishes them to this Wayfolio.")
                } else if filteredLocations.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No matching places",
                                      message: "Try another search term within the places this character knows.")
                } else {
                    ForEach(filteredLocations) { location in
                        Button {
                            selectedLocation = location
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(location.status.replacingOccurrences(of: "_", with: " ").uppercased()).font(WayfolioTypography.tiny).tracking(0.8)
                                Text(location.name).font(WayfolioTypography.title)
                                Text(location.notes.joined(separator: " ")).font(WayfolioTypography.body).foregroundStyle(WayfolioPalette.ink.opacity(0.72))
                                Label("Open place record", systemImage: "arrow.up.right.square")
                                    .font(WayfolioTypography.caption)
                                    .foregroundStyle(WayfolioPalette.ink.opacity(0.68))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(WayfolioPalette.brass.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens a separate reading view with the approved landscape artwork")
                    }
                }
            }
            .foregroundStyle(WayfolioPalette.ink)
            .padding(14)
            .parchmentSurface()
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedLocation) { location in
            PlaceRecordDetail(location: location)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var filteredLocations: [GameSessionClient.KnowledgeRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return session.knownLocations }
        return session.knownLocations.filter {
            ($0.name + " " + $0.notes.joined(separator: " ")).localizedCaseInsensitiveContains(query)
        }
    }
}

private enum PlaceDisplayMode: String, CaseIterable, Identifiable {
    case map, list
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String { self == .map ? "map.fill" : "list.bullet" }
}

private struct PlaceRecordDetail: View {
    @Environment(\.dismiss) private var dismiss
    let location: GameSessionClient.KnowledgeRecord

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image("hemlock-environment")
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(WayfolioPalette.brass, lineWidth: 1)
                        }
                        .accessibilityLabel("Landscape view of \(location.name)")

                    Text(location.status.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(WayfolioTypography.tiny)
                        .tracking(0.8)
                        .foregroundStyle(WayfolioPalette.cyan)

                    Text(location.name)
                        .font(WayfolioTypography.display)
                        .foregroundStyle(WayfolioPalette.parchment)

                    ForEach(location.notes, id: \.self) { note in
                        Text(note)
                            .font(WayfolioTypography.body)
                            .foregroundStyle(WayfolioPalette.parchment.opacity(0.84))
                    }
                }
                .padding(18)
            }
            .background(WayfolioPalette.midnight.ignoresSafeArea())
            .navigationTitle("Place Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct WayfolioBotanicalResearchView: View {
    @EnvironmentObject private var session: GameSessionClient

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if session.botanicals.isEmpty && session.experiments.isEmpty {
                    WayfolioStateCard(kind: .empty, title: "No botanical research published", message: "Confirmed plants, preparations, and experiments will appear here as the selected character records them.")
                } else {
                    ForEach(session.botanicals) { botanical in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(botanical.status.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(WayfolioTypography.tiny).tracking(0.8)
                            Text(botanical.name).font(WayfolioTypography.title)
                            ForEach(botanical.notes, id: \.self) { note in
                                Label(note, systemImage: "leaf.fill").font(WayfolioTypography.body)
                            }
                        }
                        .foregroundStyle(WayfolioPalette.ink).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).parchmentSurface()
                    }
                    ForEach(session.experiments) { experiment in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(experiment.status.replacingOccurrences(of: "_", with: " ").uppercased()).font(WayfolioTypography.tiny).tracking(0.8)
                            Text(experiment.question).font(WayfolioTypography.title)
                            ForEach(experiment.samples, id: \.self) { sample in
                                Label(sample, systemImage: "flask.fill").font(WayfolioTypography.body)
                            }
                        }
                        .foregroundStyle(WayfolioPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .parchmentSurface()
                    }
                }
            }
            .padding(.horizontal, WayfolioMetrics.contentInset)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

struct PlaceholderFeatureView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(WayfolioPalette.cyan)
            Text(title)
                .font(WayfolioTypography.title)
                .foregroundStyle(WayfolioPalette.ink)
            Text(message)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .parchmentSurface()
        .padding(WayfolioMetrics.contentInset)
    }
}
