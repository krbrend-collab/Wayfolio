import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct WayfolioRootView: View {
    var body: some View {
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            SharedIPadEntryView()
        } else {
            PhoneWayfolioRootView()
        }
#else
        PhoneWayfolioRootView()
#endif
    }
}

// MARK: - Shared iPad entry / login bridge

private struct SharedIPadEntryView: View {
    @State private var loginNotice: String?

    // Production note:
    // The Mac/DM host must provide an audience-filtered SharedLoginCampaignContext.
    // Unrevealed characters must be removed before delivery. The client repeats the
    // reveal guard defensively, but client-side hiding is not the privacy boundary.
    private let context = SharedLoginCampaignContext(
        backgroundAssetName: nil,
        publicParty: []
    )

    var body: some View {
        SharedIPadLoginView(
            context: context,
            notice: loginNotice,
            onLogin: { credentials in
                guard !credentials.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !credentials.password.isEmpty else {
                    loginNotice = "Enter your username or email and password."
                    return
                }

                // Authentication must be supplied by the campaign/account service.
                // Never treat local field validation as successful authentication.
                loginNotice = "Login is ready for the campaign authentication service."
            },
            onForgotPassword: {
                loginNotice = "Password recovery is ready for the account service."
            },
            onCreateAccount: { _ in
                loginNotice = "Account setup is ready for the player account service."
            }
        )
        .preferredColorScheme(.dark)
    }
}

private struct SharedIPadLoginView: View {
    let context: SharedLoginCampaignContext
    let notice: String?
    let onLogin: (SharedLoginCredentials) -> Void
    let onForgotPassword: () -> Void
    let onCreateAccount: (SharedNewPlayerDraft) -> Void

    @State private var identifier = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var showsPassword = false
    @State private var showsCreateAccount = false
    @State private var chosenSpriteByMemberID: [String: SharedLoginSprite] = [:]
    @FocusState private var focusedField: LoginField?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SharedLoginBackgroundView(assetName: context.backgroundAssetName)

                SharedLoginPartyStage(
                    members: context.loginVisibleParty,
                    chosenSpriteByMemberID: chosenSpriteByMemberID
                )

                // The global screen remains readable and luminous. Only a very light
                // contrast veil is used; local panel diffusion does the real work.
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                SharedLoginProjectionPanel {
                    loginForm
                }
                .frame(
                    width: min(proxy.size.width * 0.58, 710),
                    height: min(proxy.size.height * 0.76, 760)
                )
                .position(x: proxy.size.width * 0.50, y: proxy.size.height * 0.50)
            }
            .ignoresSafeArea()
        }
        .task(id: context.rosterSignature) {
            chooseSessionSprites()
        }
        .sheet(isPresented: $showsCreateAccount) {
            SharedCreateAccountView(onSubmit: { draft in
                showsCreateAccount = false
                onCreateAccount(draft)
            })
        }
    }

    private var loginForm: some View {
        VStack(spacing: 18) {
            VStack(spacing: 5) {
                Text("WAYFOLIO")
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .tracking(1.5)
                    .foregroundStyle(WayfolioPalette.parchment)
                    .shadow(color: WayfolioPalette.brassBright.opacity(0.45), radius: 8)

                HStack(spacing: 10) {
                    Rectangle().frame(height: 1)
                    Image(systemName: "sparkle")
                    Text("SIGN IN")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .tracking(5)
                    Image(systemName: "sparkle")
                    Rectangle().frame(height: 1)
                }
                .foregroundStyle(WayfolioPalette.cyan.opacity(0.82))
            }
            .padding(.bottom, 2)

            LoginFieldChrome(systemImage: "person") {
                TextField("Username or Email", text: $identifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .focused($focusedField, equals: .identifier)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            }

            LoginFieldChrome(systemImage: "lock") {
                HStack(spacing: 8) {
                    Group {
                        if showsPassword {
                            TextField("Password", text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                        }
                    }
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submitLogin)

                    Button {
                        showsPassword.toggle()
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(WayfolioPalette.cyan)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
                }
            }

            HStack {
                Button {
                    rememberMe.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundStyle(rememberMe ? WayfolioPalette.cyan : WayfolioPalette.mutedText)
                        Text("Remember Me")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityValue(rememberMe ? "On" : "Off")

                Spacer()

                Button("Forgot Password?", action: onForgotPassword)
                    .buttonStyle(.plain)
                    .foregroundStyle(WayfolioPalette.cyan)
                    .font(.subheadline.weight(.medium))
            }

            Button(action: submitLogin) {
                HStack(spacing: 16) {
                    Image(systemName: "sparkles")
                    Text("LOGIN")
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .tracking(7)
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(ProjectionPrimaryButtonStyle())
            .disabled(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            .opacity(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty ? 0.55 : 1)

            Button {
                showsCreateAccount = true
            } label: {
                Label("CREATE ACCOUNT", systemImage: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .tracking(2.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(ProjectionSecondaryButtonStyle())

            if let notice, !notice.isEmpty {
                Text(notice)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WayfolioPalette.mutedText)
                    .padding(.horizontal, 10)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 36)
    }

    private func submitLogin() {
        focusedField = nil
        onLogin(
            SharedLoginCredentials(
                identifier: identifier,
                password: password,
                rememberMe: rememberMe
            )
        )
    }

    private func chooseSessionSprites() {
        var choices: [String: SharedLoginSprite] = [:]

        for member in context.loginVisibleParty {
            let eligible = member.loginSprites.filter(\.isRuntimeEligible)
            if let sprite = eligible.randomElement() {
                choices[member.id] = sprite
            }
        }

        // One selection per roster/session signature. Incidental SwiftUI redraws do
        // not reroll poses.
        chosenSpriteByMemberID = choices
    }

    private enum LoginField: Hashable {
        case identifier
        case password
    }
}

// MARK: - Floating login projection

private struct SharedLoginProjectionPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WayfolioPalette.navy.opacity(0.94),
                            WayfolioPalette.navyRaised.opacity(0.83),
                            WayfolioPalette.midnight.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(WayfolioPalette.cyan.opacity(0.88), lineWidth: 2)
                .shadow(color: WayfolioPalette.cyan.opacity(0.65), radius: 17)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .inset(by: 10)
                .stroke(WayfolioPalette.brassBright.opacity(0.70), lineWidth: 1.4)

            ProjectionCornerMarks()
                .padding(16)

            content
        }
        .background {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(WayfolioPalette.midnight.opacity(0.30))
                .blur(radius: 26)
                .padding(-20)
        }
        .overlay(alignment: .top) {
            ZStack {
                Circle()
                    .fill(WayfolioPalette.navy)
                    .frame(width: 68, height: 68)
                    .overlay(Circle().stroke(WayfolioPalette.brassBright, lineWidth: 2))
                    .shadow(color: WayfolioPalette.cyan.opacity(0.7), radius: 12)

                Image(systemName: "sparkle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(WayfolioPalette.brassBright)
            }
            .offset(y: -34)
        }
        .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
    }
}

private struct ProjectionCornerMarks: View {
    var body: some View {
        GeometryReader { proxy in
            let length = min(proxy.size.width, proxy.size.height) * 0.10
            Path { path in
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))
                path.move(to: CGPoint(x: proxy.size.width - length, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width, y: length))
                path.move(to: CGPoint(x: 0, y: proxy.size.height - length))
                path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                path.addLine(to: CGPoint(x: length, y: proxy.size.height))
                path.move(to: CGPoint(x: proxy.size.width - length, y: proxy.size.height))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height - length))
            }
            .stroke(
                WayfolioPalette.brassBright.opacity(0.85),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
    }
}

private struct LoginFieldChrome<Content: View>: View {
    let systemImage: String
    let content: Content

    init(systemImage: String, @ViewBuilder content: () -> Content) {
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WayfolioPalette.cyan)
                .frame(width: 24)

            content
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .frame(height: 55)
        .background(
            WayfolioPalette.midnight.opacity(0.70),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WayfolioPalette.cyan.opacity(0.85), lineWidth: 1.5)
        }
        .shadow(color: WayfolioPalette.cyan.opacity(0.22), radius: 9)
    }
}

private struct ProjectionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(WayfolioPalette.parchment)
            .background(
                LinearGradient(
                    colors: [WayfolioPalette.cyan.opacity(0.38), Color.blue.opacity(0.42)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(WayfolioPalette.brassBright, lineWidth: 2))
            .shadow(
                color: WayfolioPalette.cyan.opacity(configuration.isPressed ? 0.25 : 0.55),
                radius: configuration.isPressed ? 5 : 13
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct ProjectionSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(WayfolioPalette.parchment)
            .background(
                WayfolioPalette.midnight.opacity(configuration.isPressed ? 0.88 : 0.58),
                in: Capsule()
            )
            .overlay(Capsule().stroke(WayfolioPalette.brassBright.opacity(0.90), lineWidth: 1.4))
    }
}

// MARK: - Party presentation

private struct SharedLoginPartyStage: View {
    let members: [SharedLoginPartyMember]
    let chosenSpriteByMemberID: [String: SharedLoginSprite]

    var body: some View {
        GeometryReader { proxy in
            let visibleMembers = Array(members.prefix(6))
            let slots = LoginPartySlot.slots(for: visibleMembers.count)

            ZStack {
                ForEach(Array(visibleMembers.enumerated()), id: \.element.id) { index, member in
                    if index < slots.count,
                       let sprite = chosenSpriteByMemberID[member.id] {
                        let slot = slots[index]
                        let shouldMirror = slot.prefersMirroring && sprite.mirrorAllowed

                        Image(sprite.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: proxy.size.width * slot.widthFraction,
                                height: proxy.size.height * slot.heightFraction
                            )
                            .scaleEffect(x: shouldMirror ? -1 : 1, y: 1)
                            .position(
                                x: proxy.size.width * slot.x,
                                y: proxy.size.height * slot.y
                            )
                            .zIndex(slot.z)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LoginPartySlot {
    let x: CGFloat
    let y: CGFloat
    let widthFraction: CGFloat
    let heightFraction: CGFloat
    let prefersMirroring: Bool
    let z: Double

    static func slots(for count: Int) -> [LoginPartySlot] {
        let leftFront = LoginPartySlot(
            x: 0.13, y: 0.61, widthFraction: 0.34, heightFraction: 0.86,
            prefersMirroring: false, z: 3
        )
        let rightFront = LoginPartySlot(
            x: 0.87, y: 0.61, widthFraction: 0.34, heightFraction: 0.86,
            prefersMirroring: true, z: 3
        )
        let leftRear = LoginPartySlot(
            x: 0.08, y: 0.49, widthFraction: 0.27, heightFraction: 0.68,
            prefersMirroring: false, z: 2
        )
        let rightRear = LoginPartySlot(
            x: 0.92, y: 0.49, widthFraction: 0.27, heightFraction: 0.68,
            prefersMirroring: true, z: 2
        )
        let leftUpper = LoginPartySlot(
            x: 0.19, y: 0.36, widthFraction: 0.23, heightFraction: 0.56,
            prefersMirroring: false, z: 1
        )
        let rightUpper = LoginPartySlot(
            x: 0.81, y: 0.36, widthFraction: 0.23, heightFraction: 0.56,
            prefersMirroring: true, z: 1
        )

        switch count {
        case 0: return []
        case 1: return [leftFront]
        case 2: return [leftFront, rightFront]
        case 3: return [leftFront, rightFront, leftRear]
        case 4: return [leftFront, rightFront, leftRear, rightRear]
        case 5: return [leftFront, rightFront, leftRear, rightRear, leftUpper]
        default: return [leftFront, rightFront, leftRear, rightRear, leftUpper, rightUpper]
        }
    }
}

private struct SharedLoginBackgroundView: View {
    let assetName: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x10264A),
                    Color(hex: 0x171D42),
                    WayfolioPalette.midnight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

#if canImport(UIKit)
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
#endif
        }
    }
}

// MARK: - New player / character setup

private struct SharedCreateAccountView: View {
    let onSubmit: (SharedNewPlayerDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var joinMode: SharedCharacterJoinMode = .bringCharacter
    @State private var characterSheetFileName: String?
    @State private var backgroundFileName: String?
    @State private var importTarget: ImportTarget?
    @State private var showsImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Account") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                }

                Section("Character Setup") {
                    Picker("Joining as", selection: $joinMode) {
                        ForEach(SharedCharacterJoinMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Text(joinMode.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if joinMode == .bringCharacter {
                    Section("Import Existing Character") {
                        Button {
                            importTarget = .characterSheet
                            showsImporter = true
                        } label: {
                            Label(
                                characterSheetFileName ?? "Upload Character Sheet",
                                systemImage: "doc.badge.plus"
                            )
                        }

                        Button {
                            importTarget = .background
                            showsImporter = true
                        } label: {
                            Label(
                                backgroundFileName ?? "Upload Background / Backstory",
                                systemImage: "text.document"
                            )
                        }

                        Text("Imported data remains provisional until DM review. The campaign service must retain the original source files before marking an import complete.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if joinMode == .existingCampaignCharacter {
                    Section("Campaign Character") {
                        Text("The campaign service will list only canonical characters the DM has marked Available to Play. Claiming one never creates a duplicate character record.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("New Character") {
                        Text("Character creation continues through Wayfolio onboarding after the player account is paired.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Create Player Account") {
                        onSubmit(
                            SharedNewPlayerDraft(
                                displayName: displayName,
                                email: email,
                                password: password,
                                joinMode: joinMode,
                                characterSheetFileName: characterSheetFileName,
                                backgroundFileName: backgroundFileName
                            )
                        )
                    }
                    .disabled(!canSubmit)
                } footer: {
                    Text("Creating an account adds a human player only. NPC recruitment and party membership remain story-driven campaign state.")
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [.pdf, .image, .plainText, .rtf, .json],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result,
                      let url = urls.first,
                      let importTarget else { return }

                switch importTarget {
                case .characterSheet:
                    characterSheetFileName = url.lastPathComponent
                case .background:
                    backgroundFileName = url.lastPathComponent
                }
                self.importTarget = nil
            }
        }
    }

    private var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        (joinMode != .bringCharacter || characterSheetFileName != nil)
    }

    private enum ImportTarget {
        case characterSheet
        case background
    }
}

// MARK: - Shared login / runtime data contracts

private struct SharedLoginCredentials {
    let identifier: String
    let password: String
    let rememberMe: Bool
}

private struct SharedNewPlayerDraft {
    let displayName: String
    let email: String
    let password: String
    let joinMode: SharedCharacterJoinMode
    let characterSheetFileName: String?
    let backgroundFileName: String?
}

private enum SharedCharacterJoinMode: String, CaseIterable, Identifiable {
    case bringCharacter
    case createCharacter
    case existingCampaignCharacter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bringCharacter: "Bring My Character"
        case .createCharacter: "Create a Character"
        case .existingCampaignCharacter: "Play an Existing Campaign Character"
        }
    }

    var explanation: String {
        switch self {
        case .bringCharacter:
            "Upload an existing sheet and optional background/backstory for DM review."
        case .createCharacter:
            "Create a new playable character and pair it to this player's Wayfolio."
        case .existingCampaignCharacter:
            "Claim a canonical campaign character the DM has made Available to Play."
        }
    }
}

// The seven fields below intentionally remain independent. Do not collapse them
// into a single character status. This mirrors the WF-049 state authority and
// allows legal combinations such as joined + pendingIntroduction or
// playable + assigned + pairingPending.
private enum SharedRecruitmentState: String, Hashable {
    case notEligible
    case opportunityAvailable
    case discussing
    case accepted
    case declined
    case conditional
}

private enum SharedPartyMembership: String, Hashable {
    case notMember
    case joined
    case temporarilySeparated
    case left
}

private enum SharedRevealState: String, Hashable {
    case unrevealed
    case pendingIntroduction
    case introduced
}

private enum SharedPlayability: String, Hashable {
    case npcOnly
    case availableToPlay
    case playable
}

private enum SharedWayfolioBinding: String, Hashable {
    case unpaired
    case pairingPending
    case paired
}

private enum SharedScenePresence: String, Hashable {
    case absent
    case present
}

private enum SharedAssetApprovalStatus: String, Hashable {
    case inReview
    case approved
    case superseded
}

private enum SharedFacingDirection: String, Hashable {
    case left
    case right
    case center
    case neutral
}

private struct SharedLoginCampaignContext {
    let backgroundAssetName: String?

    // This array is already audience-filtered by the authoritative host. It must
    // never contain DM-private/unrevealed records in production.
    let publicParty: [SharedLoginPartyMember]

    var loginVisibleParty: [SharedLoginPartyMember] {
        Array(publicParty.filter(\.isLoginVisible).prefix(6))
    }

    var rosterSignature: String {
        let memberSignature = loginVisibleParty.map { member in
            let sprites = member.loginSprites
                .filter(\.isRuntimeEligible)
                .map { "\($0.spriteSetVersion):\($0.spriteID)" }
                .sorted()
                .joined(separator: ",")

            return [
                member.id,
                member.partyMembership.rawValue,
                member.revealState.rawValue,
                sprites
            ].joined(separator: ":")
        }
        .joined(separator: "|")

        return memberSignature + "|" + (backgroundAssetName ?? "none")
    }
}

private struct SharedLoginPartyMember: Identifiable, Hashable {
    let id: String                    // canonicalCharacterID
    let displayName: String
    let portraitAssetName: String?
    let loginSprites: [SharedLoginSprite]

    let recruitmentState: SharedRecruitmentState
    let partyMembership: SharedPartyMembership
    let revealState: SharedRevealState
    let playability: SharedPlayability
    let assignedPlayerID: String?
    let wayfolioBinding: SharedWayfolioBinding
    let scenePresence: SharedScenePresence

    var isLoginVisible: Bool {
        // The shared login is a public surface. A joined character is eligible only
        // after the DM has introduced them in-story. scenePresence is intentionally
        // NOT part of this rule: an introduced active party member may remain in the
        // general login composition while absent from the current scene.
        partyMembership == .joined &&
        revealState == .introduced &&
        loginSprites.contains(where: \.isRuntimeEligible)
    }
}

private struct SharedLoginSprite: Hashable {
    let spriteID: String
    let assetName: String
    let spriteSetVersion: Int
    let approvalStatus: SharedAssetApprovalStatus
    let loginEligible: Bool

    // Normalized 0...1 metadata supplied by the asset manifest/runtime resolver.
    let faceBounds: CGRect?
    let eyeLine: CGFloat?
    let silhouetteBounds: CGRect?
    let baseline: CGFloat?
    let preferredFacing: SharedFacingDirection
    let mirrorAllowed: Bool
    let minDisplayScale: CGFloat
    let maxDisplayScale: CGFloat
    let foregroundEligible: Bool
    let rearSlotEligible: Bool

    var isRuntimeEligible: Bool {
        approvalStatus == .approved && loginEligible
    }
}

// Approved login environment asset names. Campaign state chooses one; the login
// screen never invents or randomizes the party's current location.
private enum SharedLoginBackgroundAsset: String, CaseIterable {
    case treetopVillage = "wayfolio_login_bg_01_treetop_village"
    case marketSquare = "wayfolio_login_bg_02_market_square"
    case mountainShrine = "wayfolio_login_bg_03_mountain_shrine"
    case harborVillage = "wayfolio_login_bg_04_harbor_village"
    case desertOasis = "wayfolio_login_bg_05_desert_oasis"
    case overgrownRuins = "wayfolio_login_bg_06_overgrown_ruins"
    case crystalSanctuary = "wayfolio_login_bg_07_crystal_sanctuary"
    case yokaiShrineVillage = "wayfolio_login_bg_08_yokai_shrine_village"
    case yokaiOnsen = "wayfolio_login_bg_09_yokai_onsen"
    case bambooForest = "wayfolio_login_bg_10_bamboo_forest"
    case redwoodForest = "wayfolio_login_bg_11_redwood_forest"
    case autumnForest = "wayfolio_login_bg_12_autumn_forest"
    case dungeonTempleHall = "wayfolio_login_bg_13_dungeon_temple_hall"
    case dungeonCrystalTemple = "wayfolio_login_bg_14_dungeon_crystal_temple"
    case dungeonCrypt = "wayfolio_login_bg_15_dungeon_crypt"
    case crystalCave = "wayfolio_login_bg_16_crystal_cave"
}

// MARK: - Existing iPhone starter shell

private struct PhoneWayfolioRootView: View {
    @State private var selectedSection: WayfolioSection = .entries
    @State private var guidePath: [WayfolioRoute] = []
    @State private var entriesPath: [WayfolioRoute] = []
    @State private var mapPath: [WayfolioRoute] = []
    @State private var notesPath: [WayfolioRoute] = []
    @State private var morePath: [WayfolioRoute] = []

    var body: some View {
        WayfolioShell(
            section: selectedSection,
            title: currentTitle,
            subtitle: currentSubtitle,
            canGoBack: currentPathIsNotEmpty,
            onBack: popCurrentPath,
            onSelectSection: switchSection
        ) {
            currentNavigationStack
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var currentNavigationStack: some View {
        switch selectedSection {
        case .guide:
            NavigationStack(path: $guidePath) {
                GuideHomeView(onOpenCreature: { guidePath.append(.creature($0)) })
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .entries:
            NavigationStack(path: $entriesPath) {
                EntriesView(onOpenCreature: { entriesPath.append(.creature($0)) })
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .map:
            NavigationStack(path: $mapPath) {
                MapPlaceholderView()
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .notes:
            NavigationStack(path: $notesPath) {
                NotesPlaceholderView()
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .more:
            NavigationStack(path: $morePath) {
                MorePlaceholderView()
                    .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: WayfolioRoute) -> some View {
        switch route {
        case .creature(let id):
            FieldGuideView(creatureID: id)
        }
    }

    private var currentTitle: String {
        currentPathIsNotEmpty ? "Field Guide" : selectedSection.title
    }

    private var currentSubtitle: String {
        if currentPathIsNotEmpty { return "Living Specimen Record" }
        switch selectedSection {
        case .guide: return "Field Reference"
        case .entries: return "Collection Ledger"
        case .map: return "World Exploration"
        case .notes: return "Research & Lore"
        case .more: return "Wayfolio Systems"
        }
    }

    private var currentPathIsNotEmpty: Bool {
        switch selectedSection {
        case .guide: !guidePath.isEmpty
        case .entries: !entriesPath.isEmpty
        case .map: !mapPath.isEmpty
        case .notes: !notesPath.isEmpty
        case .more: !morePath.isEmpty
        }
    }

    private func popCurrentPath() {
        switch selectedSection {
        case .guide:
            if !guidePath.isEmpty { guidePath.removeLast() }
        case .entries:
            if !entriesPath.isEmpty { entriesPath.removeLast() }
        case .map:
            if !mapPath.isEmpty { mapPath.removeLast() }
        case .notes:
            if !notesPath.isEmpty { notesPath.removeLast() }
        case .more:
            if !morePath.isEmpty { morePath.removeLast() }
        }
    }

    private func switchSection(_ section: WayfolioSection) {
        withAnimation(.snappy(duration: 0.28)) {
            selectedSection = section
        }
    }
}
