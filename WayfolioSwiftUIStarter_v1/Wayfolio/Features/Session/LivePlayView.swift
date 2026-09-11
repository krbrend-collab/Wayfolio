import SwiftUI
import Speech
import AVFoundation
import Combine

// Presentation-only components. Campaign authority stays in GameSessionClient and the host.
struct WayfolioStoryCard: View {
    let eyebrow: String
    let title: String
    let text: String
    var speaker: String? = nil
    var portraitAsset: String? = nil
    var isNarration = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                portrait
                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow.uppercased()).font(WayfolioTypography.caption).tracking(1.4)
                        .foregroundStyle(WayfolioPalette.ink.opacity(0.58))
                    Text(title).font(WayfolioTypography.title)
                    if let speaker {
                        Text(speaker.uppercased()).font(WayfolioTypography.tiny).tracking(1.2)
                            .foregroundStyle(WayfolioPalette.navy.opacity(0.68))
                    }
                }
                Spacer(minLength: 0)
            }
            Text(text)
                .font(isNarration ? WayfolioTypography.body.italic() : WayfolioTypography.body)
                .lineSpacing(3).foregroundStyle(WayfolioPalette.ink.opacity(0.82))
        }
        .wayfolioLedgerCard()
    }

    @ViewBuilder private var portrait: some View {
        if let portraitAsset {
            if portraitAsset == "renn-dialogue" {
                CharacterPortraitView(characterID: "renn", characterName: speaker ?? "Renn", size: 62)
            } else {
                Image(portraitAsset).resizable().scaledToFill().frame(width: 62, height: 62)
                    .clipShape(Circle()).overlay(Circle().stroke(WayfolioPalette.brass, lineWidth: 1.5))
                    .accessibilityHidden(true)
            }
        } else {
            ZStack {
                Circle().fill(WayfolioPalette.navy)
                Image(systemName: isNarration ? "book.pages.fill" : "quote.bubble.fill")
                    .foregroundStyle(WayfolioPalette.brassBright)
            }
            .frame(width: 48, height: 48)
            .overlay(Circle().stroke(WayfolioPalette.brass.opacity(0.8), lineWidth: 1))
            .accessibilityHidden(true)
        }
    }
}

struct WayfolioWaitingCard: View {
    let title: String
    let message: String
    var symbol = "hourglass"

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 23, weight: .semibold))
                .foregroundStyle(WayfolioPalette.cyan).symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(WayfolioTypography.headline)
                Text(message).font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.68))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(WayfolioPalette.parchment).padding(15)
        .navySurface(radius: WayfolioMetrics.cardRadius)
        .accessibilityElement(children: .combine)
    }
}

struct WayfolioStateCard: View {
    enum Kind: Equatable { case loading, disconnected, error, empty }
    let kind: Kind
    let title: String
    let message: String

    private var manifestationAsset: String? {
        switch kind {
        case .loading: "wayfolio-manifest-visual-generating"
        case .disconnected: "wayfolio-manifest-warning"
        case .error: "wayfolio-manifest-warning"
        case .empty: "wayfolio-manifest-new-record"
        }
    }

    var body: some View {
        VStack(spacing: 11) {
            if let manifestationAsset {
                WayfolioApprovedIcon(assetName: manifestationAsset, size: 58)
            }
            Text(title).font(WayfolioTypography.title).multilineTextAlignment(.center)
            Text(message).font(WayfolioTypography.body).multilineTextAlignment(.center)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(WayfolioPalette.parchment)
        .frame(maxWidth: .infinity)
        .padding(22)
        .navySurface()
    }
}

struct WayfolioChoiceCard: View {
    let prompt: GameSessionClient.Prompt
    let onChoose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Your moment", systemImage: "sparkles").font(WayfolioTypography.caption).tracking(1)
            Text(prompt.title).font(WayfolioTypography.title)
            Text(prompt.message).font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.76))
            ForEach(prompt.choices, id: \.self) { choice in
                Button { onChoose(choice) } label: {
                    HStack { Text(choice).multilineTextAlignment(.leading); Spacer(); Image(systemName: "chevron.right") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(WayfolioPalette.navy)
            }
        }
        .wayfolioLedgerCard().chromaGlow(active: true, radius: 18)
    }
}

struct WayfolioResponseComposer: View {
    @EnvironmentObject private var session: GameSessionClient
    @Binding var text: String
    @Binding var isPublic: Bool
    @FocusState.Binding var isFocused: Bool
    let isListening: Bool
    let onVoice: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Declare an action", systemImage: "text.bubble.fill")
                    .font(WayfolioTypography.title)
                Spacer()
                voiceButton
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What does \(activeName) say or do?")
                        .font(WayfolioTypography.body)
                        .foregroundStyle(WayfolioPalette.ink.opacity(0.52))
                        .padding(.horizontal, 15).padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .focused($isFocused)
                    .accessibilityLabel("Declare what \(activeName) says or does")
            }
            .frame(minHeight: 118)
            .background(Color.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(WayfolioPalette.brass, lineWidth: 1.4))

            HStack(spacing: 8) {
                audienceButton("Private", symbol: "eye.slash.fill", selected: !isPublic) { isPublic = false }
                audienceButton("Public", symbol: "person.3.fill", selected: isPublic) { isPublic = true }
            }
            Text(isPublic ? "Everyone at the table will see this." : "This remains between \(activeName) and the DM.")
                .font(WayfolioTypography.caption).foregroundStyle(WayfolioPalette.ink.opacity(0.72))
            Button(action: onSubmit) {
                Label(isPublic ? "Share with the table" : "Send privately to the DM", systemImage: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent).tint(WayfolioPalette.navy)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .wayfolioLedgerCard()
    }

    private var activeName: String { session.character?.name ?? session.playerName }

    private var voiceButton: some View {
        Button(action: onVoice) {
            Label(isListening ? "Stop" : "Speak", systemImage: isListening ? "stop.circle.fill" : "mic.fill")
                .font(WayfolioTypography.caption)
                .frame(minHeight: 40)
        }
        .buttonStyle(.bordered)
        .tint(isListening ? WayfolioPalette.cyan : WayfolioPalette.navy)
        .accessibilityHint("Dictates this declaration; the same privacy and host confirmation rules still apply")
    }

    private func audienceButton(_ label: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? WayfolioPalette.parchment : WayfolioPalette.ink)
        .background(selected ? WayfolioPalette.navy : WayfolioPalette.parchmentDeep.opacity(0.38),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? WayfolioPalette.brassBright : WayfolioPalette.brass.opacity(0.55)))
        .accessibilityLabel("\(label) response")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct WayfolioRollInstructionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("The dice await", systemImage: "dice.fill").font(WayfolioTypography.title)
            Text("Roll a physical d20 and enter its face on the shared screen, or choose the shared digital die.")
                .font(WayfolioTypography.body)
            Text("Your Wayfolio will reveal the outcome when the table resolves it.")
                .font(WayfolioTypography.caption).foregroundStyle(WayfolioPalette.ink.opacity(0.62))
        }
        .wayfolioLedgerCard()
    }
}

struct WayfolioDialogueCard: View {
    let dialogue: GameSessionClient.DialoguePresentation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if dialogue.speakerID == "narrator" {
                ZStack {
                    Circle().fill(WayfolioPalette.navy)
                    Image(systemName: "book.pages.fill")
                        .foregroundStyle(WayfolioPalette.brassBright)
                }
                .frame(width: 68, height: 68)
                .overlay(Circle().stroke(WayfolioPalette.brassBright, lineWidth: 1.4))
                .accessibilityHidden(true)
            } else {
                CharacterPortraitView(
                    characterID: dialogue.speakerID,
                    characterName: dialogue.speakerName,
                    size: 68
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(dialogue.speakerName.uppercased())
                    .font(WayfolioTypography.caption)
                    .tracking(1.3)
                    .foregroundStyle(WayfolioPalette.cyan)
                Text(dialogue.text)
                    .font(dialogue.speakerID == "narrator" ? WayfolioTypography.body.italic() : WayfolioTypography.body)
                    .lineSpacing(4)
                    .foregroundStyle(WayfolioPalette.parchment)
                if let performance = dialogue.performance {
                    Text(performance)
                        .font(WayfolioTypography.tiny.italic())
                        .foregroundStyle(WayfolioPalette.parchment.opacity(0.58))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .projectionPane(.dialogue)
        .accessibilityElement(children: .combine)
    }
}

private struct WayfolioSceneBackdrop: View {
    @EnvironmentObject private var session: GameSessionClient
    let visual: GameSessionClient.VisualPresentation?

    var body: some View {
        Group {
            if let visual, let url = session.presentationAssetURL(path: visual.path) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay {
            LinearGradient(
                colors: [Color.black.opacity(0.08), .clear, WayfolioPalette.midnight.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Image("hemlock-environment").resizable().scaledToFill()
    }
}

private struct WayfolioCompactResponseComposer: View {
    @EnvironmentObject private var session: GameSessionClient
    @Binding var text: String
    @Binding var isPublic: Bool
    @Binding var isExpanded: Bool
    @FocusState.Binding var isFocused: Bool
    let isListening: Bool
    let onVoice: () -> Void
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            if isExpanded {
                TextField(prompt, text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.parchment)
                    .focused($isFocused)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(WayfolioPalette.midnight.opacity(0.44), in: RoundedRectangle(cornerRadius: 11))

                HStack(spacing: 8) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                    Button(action: onVoice) {
                        Label(isListening ? "Stop" : "Speak", systemImage: isListening ? "stop.circle.fill" : "mic.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(WayfolioPalette.cyan)
                    Spacer()
                    Button(action: onSubmit) {
                        Label(isPublic ? "Share" : "Send privately", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isPublic ? WayfolioPalette.cyan : WayfolioPalette.brassBright)
                    .foregroundStyle(WayfolioPalette.midnight)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                HStack(spacing: 8) {
                    actionButton("Say / Act", symbol: "person.3.fill", isPublic: true)
                    actionButton(session.isStandaloneSession ? "Private note" : "Message DM", symbol: "eye.slash.fill", isPublic: false)
                }
            }
        }
        .padding(11)
        .projectionPane(.dialogue, radius: 14)
        .accessibilityElement(children: .contain)
    }

    private var prompt: String {
        if isPublic { return "What does \(session.character?.name ?? session.playerName) say or do?" }
        return session.isStandaloneSession ? "Private note on this Wayfolio" : "Private message to the DM"
    }

    private func actionButton(_ title: String, symbol: String, isPublic publicValue: Bool) -> some View {
        Button {
            isPublic = publicValue
            isExpanded = true
            Task { @MainActor in isFocused = true }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .tint(publicValue ? WayfolioPalette.cyan : WayfolioPalette.brassBright)
    }
}

struct WayfolioSceneVisual: View {
    @EnvironmentObject private var session: GameSessionClient
    let visual: GameSessionClient.VisualPresentation

    var body: some View {
        Group {
            if let url = session.presentationAssetURL(path: visual.path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ZStack {
                            fallback
                            ProgressView().tint(WayfolioPalette.parchment)
                        }
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: WayfolioMetrics.cardRadius, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(visual.title)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(WayfolioPalette.navy.opacity(0.86), in: Capsule())
                .padding(12)
        }
        .overlay(RoundedRectangle(cornerRadius: WayfolioMetrics.cardRadius).stroke(WayfolioPalette.brass, lineWidth: 1.2))
        .clipped()
        .accessibilityLabel("Current scene: \(visual.title)")
    }

    private var fallback: some View {
        Image("hemlock-environment").resizable().scaledToFill()
    }
}

struct WayfolioResultCard: View {
    let result: GameSessionClient.CheckResult
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(result.title, systemImage: result.succeeded ? "sparkles" : "moon.stars.fill")
                .font(WayfolioTypography.title)
            Text(result.detail).font(WayfolioTypography.body)
        }
        .wayfolioLedgerCard().chromaGlow(active: result.succeeded, radius: 16)
        .accessibilityElement(children: .combine)
    }
}

struct WayfolioNoticeCard: View {
    let message: String
    let onDismiss: () -> Void

    private var manifestationAsset: String {
        let value = message.lowercased()
        if value.contains("sending") || value.contains("waiting") { return "wayfolio-manifest-visual-generating" }
        if value.contains("confirmed") || value.contains("shared") || value.contains("sent privately") { return "wayfolio-manifest-new-record" }
        return "wayfolio-manifest-warning"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WayfolioApprovedIcon(assetName: manifestationAsset, size: 34)
            Text(message)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", action: onDismiss)
                .font(WayfolioTypography.caption)
                .buttonStyle(.bordered)
                .tint(WayfolioPalette.navy)
        }
        .wayfolioLedgerCard()
        .accessibilityElement(children: .contain)
    }
}

struct WayfolioEquipmentList: View {
    let items: [GameSessionClient.CharacterSummary.EquipmentItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Equipped gear", systemImage: "shield.checkered").font(WayfolioTypography.headline)
            if items.isEmpty {
                Text("No equipped gear is recorded.").font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: equipmentSymbol(for: item.slot)).foregroundStyle(WayfolioPalette.navy).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(equipmentHeading(item)).font(WayfolioTypography.tiny).tracking(0.9)
                            Text(item.name).font(WayfolioTypography.headline)
                            Text(item.detail).font(WayfolioTypography.body).foregroundStyle(WayfolioPalette.ink.opacity(0.68))
                        }
                    }
                    if index < items.count - 1 { Divider().opacity(0.32) }
                }
            }
        }
        .wayfolioLedgerCard()
    }

    private func equipmentSymbol(for slot: String) -> String {
        let value = slot.lowercased()
        if value.contains("weapon") || value.contains("hand") { return "bolt.fill" }
        if value.contains("armor") || value.contains("body") { return "shield.fill" }
        return "diamond.fill"
    }

    private func equipmentHeading(_ item: GameSessionClient.CharacterSummary.EquipmentItem) -> String {
        guard let qualityLevel = item.qualityLevel else { return item.slot.uppercased() }
        return "\(item.slot.uppercased()) · QUALITY \(qualityLevel)"
    }
}

struct LivePlayView: View {
    @EnvironmentObject private var session: GameSessionClient
    @StateObject private var voiceInput = WayfolioVoiceInput()
    @State private var actionText = ""
    @State private var actionInputMode = "typed"
    @State private var isPublic = false
    @State private var firstPhysicalDie = ""
    @State private var secondPhysicalDie = ""
    @State private var composerExpanded = false
    @FocusState private var composerFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        Group {
            if case .connected = session.state, session.playMode == .iPhoneOnly {
                cinematicPhoneBody
            } else {
                standardPhoneBody
            }
        }
        .padding(.bottom, keyboardContentOverlap)
        .overlay {
            if session.awaitingSharedRoll { diceOverlay }
        }
        .animation(.snappy(duration: 0.28), value: session.prompt?.id)
        .animation(.snappy(duration: 0.28), value: session.awaitingSharedRoll)
        .onChange(of: session.pendingRoll?.id) { _, _ in
            firstPhysicalDie = ""
            secondPhysicalDie = ""
        }
        .onChange(of: voiceInput.transcript) { _, transcript in
            guard !transcript.isEmpty else { return }
            actionText = transcript
            actionInputMode = "voice"
            composerExpanded = true
        }
        .onChange(of: voiceInput.isListening) { wasListening, isListening in
            if wasListening, !isListening, !voiceInput.transcript.isEmpty {
                composerExpanded = true
                composerFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            updateKeyboard(from: $0)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {
            updateKeyboard(from: $0, forceHidden: true)
        }
        .onDisappear { voiceInput.stop() }
    }

    private var standardPhoneBody: some View {
        VStack(spacing: 10) {
            liveHeading
            if case .connected = session.state { statusStrip }
            ScrollView {
                LazyVStack(spacing: WayfolioMetrics.sectionGap) { connectionContent }
                    .padding(.horizontal, WayfolioMetrics.contentInset)
                    .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            if case .connected = session.state {
                recentTurnLog
                WayfolioResponseComposer(
                    text: $actionText,
                    isPublic: $isPublic,
                    isFocused: $composerFocused,
                    isListening: voiceInput.isListening,
                    onVoice: toggleVoiceInput,
                    onSubmit: submitAction
                )
                    .padding(.horizontal, WayfolioMetrics.contentInset)
                    .padding(.bottom, 6)
                voiceStatus
            }
        }
    }

    private var cinematicPhoneBody: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                WayfolioSceneBackdrop(visual: session.visualPresentation)

                VStack(spacing: 8) {
                    liveHeading
                    statusStrip
                    Spacer(minLength: 0)

                    if let prompt = session.prompt, !prompt.choices.isEmpty {
                        WayfolioChoiceCard(prompt: prompt, onChoose: session.submitChoice)
                            .frame(maxHeight: geometry.size.height * 0.30)
                    } else if let dialogue = session.dialoguePresentation {
                        ScrollView {
                            WayfolioDialogueCard(dialogue: dialogue)
                        }
                        .scrollIndicators(.hidden)
                        .frame(maxHeight: geometry.size.height * 0.28)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.sceneTitle).font(WayfolioTypography.title)
                            Text(session.sceneText).font(WayfolioTypography.body).lineLimit(5)
                        }
                        .foregroundStyle(WayfolioPalette.parchment)
                        .padding(14)
                        .projectionPane(.dialogue)
                        .frame(maxHeight: geometry.size.height * 0.25)
                    }

                    if let latest = session.actions.first {
                        Label(latest.text, systemImage: latest.visibility == "public" ? "person.3.fill" : "eye.slash.fill")
                            .font(WayfolioTypography.caption)
                            .foregroundStyle(WayfolioPalette.parchment.opacity(0.82))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    WayfolioCompactResponseComposer(
                        text: $actionText,
                        isPublic: $isPublic,
                        isExpanded: $composerExpanded,
                        isFocused: $composerFocused,
                        isListening: voiceInput.isListening,
                        onVoice: toggleVoiceInput,
                        onCancel: cancelComposer,
                        onSubmit: submitAction
                    )
                    voiceStatus
                }
                .padding(.horizontal, WayfolioMetrics.contentInset)
                .padding(.vertical, 8)
            }
        }
    }

    private var liveHeading: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE").font(WayfolioTypography.caption).tracking(1.5)
                    .foregroundStyle(WayfolioPalette.cyan)
                Text("The journey now").font(WayfolioTypography.title)
                    .foregroundStyle(WayfolioPalette.parchment)
            }
            Spacer()
            Text(session.currentLocation)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.72))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, WayfolioMetrics.contentInset)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusStrip: some View {
        HStack(spacing: 0) {
            liveStatus("HP", value: session.character.map { "\($0.hp)/\($0.maximumHP)" } ?? "—")
            if let resource = session.secondaryResourceSummary {
                Divider().overlay(WayfolioPalette.brass.opacity(0.45))
                liveStatus("RESOURCE", value: resource)
            }
            if let companion = session.companions.first {
                Divider().overlay(WayfolioPalette.brass.opacity(0.45))
                liveStatus("COMPANION", value: companion.name)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 8)
        .projectionPane(.compact, radius: 14)
        .padding(.horizontal, WayfolioMetrics.contentInset)
    }

    private func liveStatus(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(WayfolioTypography.tiny).tracking(0.8)
                .foregroundStyle(WayfolioPalette.cyan.opacity(0.82))
            Text(value).font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var connectionContent: some View {
        switch session.state {
        case .connected:
            if session.playMode == .iPhoneOnly, let visual = session.visualPresentation {
                WayfolioSceneVisual(visual: visual)
            }
            if session.playMode == .iPhoneOnly, let dialogue = session.dialoguePresentation {
                WayfolioDialogueCard(dialogue: dialogue)
            }
            WayfolioStoryCard(eyebrow: "Current scene", title: session.sceneTitle, text: session.sceneText)
            if let notice = session.notice {
                WayfolioNoticeCard(message: notice, onDismiss: session.dismissNotice)
            }
            if let encounter = session.encounter { encounterCard(encounter) }
            if let prompt = session.prompt { WayfolioChoiceCard(prompt: prompt, onChoose: session.submitChoice) }
            if let result = session.checkResult { WayfolioResultCard(result: result) }
        case .connecting:
            WayfolioStateCard(kind: .loading, title: "Opening the Wayfolio", message: "Finding the shared table…")
        case .failed(let message):
            WayfolioStateCard(kind: .error, title: "The path went quiet", message: message)
        case .disconnected:
            WayfolioStateCard(kind: .disconnected, title: "The Wayfolio is resting", message: "Open the rabbit profile button, choose Session, and join the table. Then return to the central LIVE medallion.")
        }
    }

    private var recentTurnLog: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("RECENT TURNS").font(WayfolioTypography.tiny).tracking(1)
                .foregroundStyle(WayfolioPalette.cyan)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if session.actions.isEmpty {
                        Text("Your words and actions will appear here.")
                            .font(WayfolioTypography.caption)
                            .foregroundStyle(WayfolioPalette.parchment.opacity(0.58))
                    } else {
                        ForEach(session.actions.prefix(3)) { action in
                            Label(action.text, systemImage: action.visibility == "public" ? "person.3.fill" : "eye.slash.fill")
                                .font(WayfolioTypography.caption)
                                .foregroundStyle(WayfolioPalette.parchment.opacity(0.86))
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 62)
        }
        .padding(10)
        .projectionPane(.compact, radius: 14)
        .padding(.horizontal, WayfolioMetrics.contentInset)
    }

    private var diceOverlay: some View {
        ZStack {
            Color.black.opacity(0.56).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(WayfolioPalette.brassBright)
                Text("The dice await").font(WayfolioTypography.title)

                if let roll = session.pendingRoll {
                    Text(rollSummary(roll))
                        .font(WayfolioTypography.body)
                        .multilineTextAlignment(.center)

                    if session.playMode == .iPhoneOnly {
                        Button { session.submitDigitalRoll() } label: {
                            Label("Roll d\(roll.dieType) digitally", systemImage: "die.face.5.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(WayfolioPalette.brassBright)
                        .foregroundStyle(WayfolioPalette.navy)

                        physicalRollEntry(roll)
                    } else {
                        Text("Complete this roll on the shared iPad. Your Wayfolio will reveal the result.")
                            .font(WayfolioTypography.body)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ProgressView().tint(WayfolioPalette.cyan)
                    Text("Preparing the roll…")
                        .font(WayfolioTypography.body)
                }
            }
            .foregroundStyle(WayfolioPalette.parchment)
            .padding(24)
            .frame(maxWidth: 340)
            .projectionPane(.alert)
            .shadow(color: .black.opacity(0.6), radius: 30)
        }
    }

    private func rollSummary(_ roll: GameSessionClient.PendingRoll) -> String {
        let modifier = roll.modifier >= 0 ? "+\(roll.modifier)" : "\(roll.modifier)"
        let target = roll.difficulty.map { " against DC \($0)" } ?? ""
        let method = roll.selection.map { " · \($0.capitalized)" } ?? ""
        return "\(roll.skill) \(modifier)\(target)\(method)"
    }

    private func physicalRollEntry(_ roll: GameSessionClient.PendingRoll) -> some View {
        VStack(spacing: 10) {
            Text("Or enter your physical roll")
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.76))
            HStack(spacing: 9) {
                physicalDieField("Die 1", text: $firstPhysicalDie, dieType: roll.dieType)
                if roll.requiredDiceCount == 2 {
                    physicalDieField("Die 2", text: $secondPhysicalDie, dieType: roll.dieType)
                }
            }
            Button {
                var dice = [Int(firstPhysicalDie) ?? 0]
                if roll.requiredDiceCount == 2 { dice.append(Int(secondPhysicalDie) ?? 0) }
                session.submitPhysicalRoll(dice)
            } label: {
                Label("Submit physical roll", systemImage: "hand.raised.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(WayfolioPalette.brassBright)
            .disabled(!physicalDiceAreValid(for: roll))
        }
    }

    private func physicalDieField(_ label: String, text: Binding<String>, dieType: Int) -> some View {
        TextField(label, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(WayfolioTypography.headline)
            .foregroundStyle(WayfolioPalette.parchment)
            .padding(.vertical, 10)
            .background(WayfolioPalette.navy.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(WayfolioPalette.brass.opacity(0.8)))
            .accessibilityHint("Enter a number from 1 through \(dieType)")
    }

    private func physicalDiceAreValid(for roll: GameSessionClient.PendingRoll) -> Bool {
        guard let first = Int(firstPhysicalDie), (1...roll.dieType).contains(first) else { return false }
        guard roll.requiredDiceCount == 2 else { return true }
        guard let second = Int(secondPhysicalDie), (1...roll.dieType).contains(second) else { return false }
        return true
    }

    private var actionHistory: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("RECENT WORDS & DEEDS").font(WayfolioTypography.caption).tracking(1)
            ForEach(session.actions) { action in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: action.visibility == "public" ? "person.3.fill" : "eye.slash.fill")
                        .foregroundStyle(WayfolioPalette.navy).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.text).font(WayfolioTypography.body)
                        Text(action.visibility == "public" ? "Shared with the table" : "Private to the DM")
                            .font(WayfolioTypography.tiny).foregroundStyle(WayfolioPalette.ink.opacity(0.55))
                    }
                }
            }
        }
        .wayfolioLedgerCard()
    }

    private func encounterCard(_ encounter: GameSessionClient.Encounter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(encounter.name, systemImage: "shield.lefthalf.filled").font(WayfolioTypography.title)
            Text(encounter.status == "resolved" ? "Resolved · \(encounter.outcome ?? "complete")" : "Round \(encounter.round)")
                .font(WayfolioTypography.caption)
            ForEach(encounter.combatants) { combatant in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(combatant.name).font(WayfolioTypography.headline)
                        Spacer()
                        Text(combatant.hpVisible ? "\(combatant.hp)/\(combatant.maximumHP) HP" : combatant.publicStatus.capitalized)
                    }
                    if combatant.hpVisible {
                        ProgressView(value: Double(combatant.hp), total: Double(max(1, combatant.maximumHP))).tint(WayfolioPalette.navy)
                    }
                    if !combatant.conditions.isEmpty { Text(combatant.conditions.joined(separator: " · ")).font(WayfolioTypography.tiny) }
                }
            }
            if encounter.activeCombatantID == session.playerID && encounter.status == "active" {
                Text("Your turn. Describe any attack, spell, aid, negotiation, retreat, or other action below.")
                    .font(WayfolioTypography.body)
            }
        }.wayfolioLedgerCard()
    }

    private func submitAction() {
        voiceInput.stop()
        session.submitAction(actionText, isPublic: isPublic, inputMode: actionInputMode)
        actionText = ""
        actionInputMode = "typed"
        composerExpanded = false
        composerFocused = false
    }

    private func toggleVoiceInput() {
        if voiceInput.isListening {
            voiceInput.stop()
        } else {
            composerExpanded = true
            composerFocused = false
            voiceInput.start(with: actionText)
        }
    }

    private func cancelComposer() {
        voiceInput.stop()
        actionText = ""
        actionInputMode = "typed"
        composerExpanded = false
        composerFocused = false
    }

    private var keyboardContentOverlap: CGFloat {
        max(0, keyboardHeight - WayfolioMetrics.dockHeight - windowBottomInset)
    }

    private var windowBottomInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
    }

    private func updateKeyboard(from notification: Notification, forceHidden: Bool = false) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let nextHeight: CGFloat
        if forceHidden {
            nextHeight = 0
        } else if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap(\.windows)
                    .first(where: \.isKeyWindow) {
            nextHeight = max(0, window.bounds.intersection(window.convert(frame, from: nil)).height)
        } else {
            nextHeight = 0
        }
        withAnimation(.easeOut(duration: duration)) { keyboardHeight = nextHeight }
    }

    @ViewBuilder private var voiceStatus: some View {
        if let message = voiceInput.statusMessage {
            Label(message, systemImage: voiceStatusSymbol)
                .font(WayfolioTypography.tiny)
                .foregroundStyle(voiceInput.isListening ? WayfolioPalette.cyan : WayfolioPalette.parchment.opacity(0.78))
                .padding(.horizontal, WayfolioMetrics.contentInset)
                .accessibilityLabel(message)
        }
    }

    private var voiceStatusSymbol: String {
        if voiceInput.isListening { return "waveform" }
        return voiceInput.transcript.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }
}

@MainActor
private final class WayfolioVoiceInput: NSObject, ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var statusMessage: String?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasInputTap = false
    private var draftPrefix = ""

    func start(with existingDraft: String) {
        guard !isListening else { return }
        transcript = ""
        draftPrefix = existingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        statusMessage = "Requesting speech access…"
        guard let recognizer else {
            statusMessage = "Speech recognition is not available on this device. You can continue typing."
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                let message: String
                switch status {
                case .denied: message = "Speech Recognition is denied. Enable it in Settings to use Speak."
                case .restricted: message = "Speech Recognition is restricted on this iPhone. You can continue typing."
                case .notDetermined: message = "Speech Recognition permission was not granted. You can try Speak again."
                case .authorized: return
                @unknown default: message = "Speech Recognition is unavailable. You can continue typing."
                }
                Task { @MainActor in self?.statusMessage = message }
                return
            }
            AVAudioApplication.requestRecordPermission { allowed in
                guard allowed else {
                    Task { @MainActor in
                        self?.statusMessage = "Microphone access is denied. Enable it in Settings to use Speak."
                    }
                    return
                }
                Task { @MainActor in
                    guard recognizer.isAvailable else {
                        self?.statusMessage = "Speech recognition is temporarily unavailable. You can continue typing."
                        return
                    }
                    self?.beginRecognition(using: recognizer)
                }
            }
        }
    }

    func stop() {
        stop(deactivateSession: true)
    }

    private func beginRecognition(using recognizer: SFSpeechRecognizer) {
        stop(preservingStatus: true, deactivateSession: false)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw VoiceInputError.invalidMicrophoneFormat
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            hasInputTap = true
            engine.prepare()
            try engine.start()
            isListening = true
            statusMessage = "Listening… speak naturally."
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result, let self {
                        let spoken = result.bestTranscription.formattedString
                        self.transcript = [self.draftPrefix, spoken]
                            .filter { !$0.isEmpty }
                            .joined(separator: self.draftPrefix.isEmpty ? "" : " ")
                    }
                    if let error {
                        self?.statusMessage = "Speech input stopped: \(error.localizedDescription)"
                        self?.stop(preservingStatus: true)
                    } else if result?.isFinal == true {
                        self?.stop(preservingStatus: true)
                        self?.statusMessage = "Speech added. Review or edit it before sending."
                    }
                }
            }
        } catch {
            statusMessage = "Speech input could not start: \(error.localizedDescription)"
            stop(preservingStatus: true)
        }
    }

    private func stop(preservingStatus: Bool, deactivateSession: Bool = true) {
        let priorStatus = statusMessage
        stop(deactivateSession: deactivateSession)
        if preservingStatus { statusMessage = priorStatus }
    }

    private func stop(deactivateSession: Bool) {
        if engine.isRunning { engine.stop() }
        if hasInputTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        statusMessage = nil
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

private enum VoiceInputError: LocalizedError {
    case invalidMicrophoneFormat

    var errorDescription: String? {
        "The microphone did not provide a usable audio format. Try Speak again or continue typing."
    }
}

private extension View {
    func wayfolioLedgerCard() -> some View {
        foregroundStyle(WayfolioPalette.ink).frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).parchmentSurface()
    }
}
