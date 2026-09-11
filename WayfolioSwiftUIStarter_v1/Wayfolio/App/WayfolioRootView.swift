import SwiftUI
import WebKit
import CoreHaptics
import UIKit

struct WayfolioRootView: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @EnvironmentObject private var session: GameSessionClient
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var navigation: WayfolioNavigationState
    @State private var showingProfile = false
    @State private var phoneEntryPhase = WayfolioPhoneEntryPhase.login
    @State private var phoneEntryTask: Task<Void, Never>?
    @State private var phoneShellReady = false
    @State private var startupMessage: String?
    @StateObject private var sessionStartHaptics = WayfolioSessionStartHaptics()
    @AppStorage("wayfolio.session.active") private var phoneSessionActive = false
    @AppStorage("wayfolio.session.host") private var savedPhoneHost = ""
    @AppStorage("wayfolio.session.code") private var savedPhoneCode = "HEMLOCK"

    init() {
        var initialSection = WayfolioSection.character
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let marker = arguments.firstIndex(of: "-WayfolioReviewSection"),
           arguments.indices.contains(marker + 1),
           let reviewSection = WayfolioSection(rawValue: arguments[marker + 1]) {
            initialSection = reviewSection
        }
#endif
        _navigation = State(initialValue: WayfolioNavigationState(selectedSection: initialSection))
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                WayfolioIPadSharedRoot()
            } else {
                phoneRoot
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottomTrailing) {
#if DEBUG && targetEnvironment(simulator)
            WayfolioDevelopmentStamp(
                role: UIDevice.current.userInterfaceIdiom == .pad ? "iPad shared table" : "iPhone Wayfolio",
                route: UIDevice.current.userInterfaceIdiom == .pad ? "shared" : effectivePhoneEntryPhase.diagnosticName,
                connection: session.state.diagnosticName
            )
            .padding(8)
            .allowsHitTesting(false)
#endif
        }
        .onAppear {
            print("[Wayfolio boot] root mounted; role=\(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
            restorePhoneConnectionIfNeeded()
        }
        .onDisappear { phoneEntryTask?.cancel() }
        .onChange(of: phoneSessionActive) { _, isActive in
            if !isActive {
                phoneEntryTask?.cancel()
                phoneEntryPhase = .login
            }
        }
    }

    private var effectivePhoneEntryPhase: WayfolioPhoneEntryPhase {
        phoneSessionActive && phoneEntryPhase == .login ? .complete : phoneEntryPhase
    }

    private var phoneRoot: some View {
        let phase = effectivePhoneEntryPhase
        return ZStack {
            if phase.keepsLoginVisible {
                WayfolioPhoneLoginRoot(onBeginSession: beginPhoneSessionTransition)
                    .accessibilityHidden(phase != .login)
            }

            if phoneSessionActive || phase.mountsShell {
                WayfolioShell(
                    section: navigation.selectedSection,
                    title: currentTitle,
                    subtitle: currentSubtitle,
                    canGoBack: navigation.canGoBack,
                    entryPresentation: phase.shellPresentation,
                    onReady: markPhoneShellReady,
                    onBack: popCurrentPath,
                    onOpenProfile: openProfile,
                    onSelectSection: switchSection
                ) {
                    currentNavigationStack
                        .id(navigation.selectedSection)
                        .transition(sectionTransition)
                }
                // Physical iOS can otherwise retain the original shell and dock
                // closure after the navigation state changes.
                .id(navigation.selectedSection)
                .accessibilityHidden(phase != .complete)
                .sheet(isPresented: $showingProfile) {
                    WayfolioProfileSheet()
                }
            }

            Color.black
                .opacity(phase.blackOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(phase.isTransitioning)
                .accessibilityHidden(true)

            if let startupMessage {
                VStack {
                    Spacer()
                    Label(startupMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(WayfolioTypography.caption)
                        .foregroundStyle(WayfolioPalette.parchment)
                        .padding(14)
                        .background(WayfolioPalette.danger.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)
                }
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func beginPhoneSessionTransition() {
        guard phoneEntryPhase == .login else { return }
        phoneEntryTask?.cancel()
        phoneEntryTask = Task { @MainActor in
            startupMessage = nil
            phoneShellReady = false
            phoneEntryPhase = .preparingShell
            phoneSessionActive = true

            for _ in 0..<40 where !phoneShellReady && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled else { return }
            guard phoneShellReady else {
                phoneSessionActive = false
                phoneEntryPhase = .login
                startupMessage = "Wayfolio could not open its local interface. Try Begin Session again."
                print("[Wayfolio boot] phone shell readiness timed out")
                return
            }

            sessionStartHaptics.play(enabled: !reduceMotion)

            await setPhoneEntryPhase(.fadeToBlack, duration: reduceMotion ? 0.12 : 0.24)
            phoneEntryPhase = .blackHold
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }

            await setPhoneEntryPhase(.dock, duration: reduceMotion ? 0.10 : 0.30)
            await setPhoneEntryPhase(.header, duration: reduceMotion ? 0.10 : 0.28)
            await setPhoneEntryPhase(.panes, duration: reduceMotion ? 0.10 : 0.30)
            await setPhoneEntryPhase(.liveContent, duration: reduceMotion ? 0.12 : 0.34)
            await setPhoneEntryPhase(.background, duration: reduceMotion ? 0.16 : 0.58)
            phoneEntryPhase = .complete
            print("[Wayfolio boot] phone shell interactive")
            UIAccessibility.post(notification: .screenChanged, argument: "Wayfolio session ready")
        }
    }

    private func markPhoneShellReady() {
        guard !phoneShellReady else { return }
        phoneShellReady = true
        print("[Wayfolio boot] phone shell mounted with visible geometry")
    }

    private func restorePhoneConnectionIfNeeded() {
        guard UIDevice.current.userInterfaceIdiom != .pad, phoneSessionActive else { return }
        if session.preferredPlayMode == .iPhoneOnly {
            print("[Wayfolio boot] restoring standalone iPhone session")
            session.startStandaloneSession()
            return
        }
        let host = savedPhoneHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = savedPhoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !host.isEmpty, !code.isEmpty else {
            phoneSessionActive = false
            phoneEntryPhase = .login
            startupMessage = "Reconnect this Wayfolio to the Mac game host."
            print("[Wayfolio boot] saved phone session missing connection details; returning to login")
            return
        }
        print("[Wayfolio boot] restoring saved phone session; code=\(code)")
        session.connect(host: host, code: code)
    }

    @MainActor
    private func setPhoneEntryPhase(_ phase: WayfolioPhoneEntryPhase, duration: Double) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: duration)) { phoneEntryPhase = phase }
        try? await Task.sleep(for: .seconds(duration))
    }

private enum WayfolioPhoneEntryPhase: Equatable {
    case login
    case preparingShell
    case fadeToBlack
    case blackHold
    case dock
    case header
    case panes
    case liveContent
    case background
    case complete

    var isTransitioning: Bool { self != .login && self != .preparingShell && self != .complete }

    var mountsShell: Bool { self != .login }

    var keepsLoginVisible: Bool {
        self == .login || self == .preparingShell || self == .fadeToBlack || self == .blackHold
    }

    var blackOpacity: Double {
        self == .fadeToBlack || self == .blackHold ? 1 : 0
    }

    var shellPresentation: WayfolioShellEntryPresentation {
        switch self {
        case .login, .preparingShell, .fadeToBlack, .blackHold:
            return .hidden
        case .dock:
            return .init(dockOpacity: 1, dockOffset: 0)
        case .header:
            return .init(headerOpacity: 1, headerOffset: 0, dockOpacity: 1, dockOffset: 0)
        case .panes:
            return .init(headerOpacity: 1, headerOffset: 0, dockOpacity: 1, dockOffset: 0,
                         paneOpacity: 1, frameOpacity: 1)
        case .liveContent:
            return .init(headerOpacity: 1, headerOffset: 0, dockOpacity: 1, dockOffset: 0,
                         paneOpacity: 0, contentOpacity: 1, frameOpacity: 1)
        case .background, .complete:
            return .complete
        }
    }

    var diagnosticName: String {
        switch self {
        case .login: return "login"
        case .preparingShell: return "preparing shell"
        case .fadeToBlack, .blackHold: return "transition"
        case .dock, .header, .panes, .liveContent, .background: return "shell staging"
        case .complete: return "active shell"
        }
    }
}

@MainActor
private final class WayfolioSessionStartHaptics: ObservableObject {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    func play(enabled: Bool) {
        guard enabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            self.engine = engine
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.player = nil
                    self?.engine = nil
                }
            }
            try engine.start()

            let timings: [(time: Double, duration: Double, intensity: Float, sharpness: Float)] = [
                (0.00, 0.030, 0.22, 0.38),
                (0.74, 0.050, 0.32, 0.42),
                (1.04, 0.075, 0.45, 0.46),
                (1.32, 0.110, 0.62, 0.50),
                (1.96, 0.155, 0.85, 0.56)
            ]
            let events = timings.map { pulse in
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: pulse.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: pulse.sharpness)
                    ],
                    relativeTime: pulse.time,
                    duration: pulse.duration
                )
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            self.player = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            player = nil
            engine = nil
        }
    }
}

@ViewBuilder
private var currentNavigationStack: some View {
        switch navigation.selectedSection {
        case .character:
            NavigationStack(path: pathBinding(for: .character)) {
                WayfolioCharacterView(onOpenItem: { push(.item($0), in: .character) })
                .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .pack:
            NavigationStack(path: pathBinding(for: .pack)) {
                WayfolioPackView(onOpenItem: { push(.item($0), in: .pack) })
                .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .live:
            LivePlayView()
        case .journal:
            NavigationStack(path: pathBinding(for: .journal)) {
                NotesPlaceholderView()
                .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        case .world:
            NavigationStack(path: pathBinding(for: .world)) {
                WayfolioWorldView(onOpenCreature: { push(.creature($0), in: .world) })
                .navigationDestination(for: WayfolioRoute.self, destination: destination)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: WayfolioRoute) -> some View {
        switch route {
        case .creature(let id):
            FieldGuideView(creatureID: id)
        case .item(let itemName):
            WayfolioItemDetailView(itemName: itemName)
        }
    }

    private var currentTitle: String {
        navigation.currentRoute?.title ?? navigation.selectedSection.title
    }

    private var currentSubtitle: String {
        guard let route = navigation.currentRoute else {
            switch navigation.selectedSection {
            case .character: return "Active Wayfinder"
            case .pack: return "Carried Goods & Craft"
            case .live: return "Story, Actions & Responses"
            case .journal: return "Notes, Quests & Sessions"
            case .world: return "Places, Creatures & Lore"
            }
        }
        return route.subtitle
    }

    private var sectionTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .opacity.combined(with: .scale(scale: 0.985))
    }

    private func pathBinding(for section: WayfolioSection) -> Binding<[WayfolioRoute]> {
        Binding(
            get: { navigation.path(for: section) },
            set: { navigation.setPath($0, for: section) }
        )
    }

    private func push(_ route: WayfolioRoute, in section: WayfolioSection) {
        audio.playUISound("navigation_select")
        navigation.push(route, in: section)
    }

    private func openProfile() {
        guard !showingProfile else { return }
        audio.playUISound("navigation_select")
        showingProfile = true
    }

    private func popCurrentPath() {
        guard navigation.canGoBack else { return }
        audio.playUISound("navigation_back")
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            navigation.pop()
        }
    }

    private func switchSection(_ section: WayfolioSection) {
        audio.playUISound("navigation_select")
        // Assign the complete value back to State so the root invalidates reliably.
        var updatedNavigation = navigation
        updatedNavigation.select(section)
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            navigation = updatedNavigation
        }
    }
}

private extension GameSessionClient.ConnectionState {
    var diagnosticName: String {
        switch self {
        case .disconnected: return "offline"
        case .connecting: return "connecting"
        case .connected(let code): return "connected \(code)"
        case .failed: return "degraded"
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
private struct WayfolioDevelopmentStamp: View {
    let role: String
    let route: String
    let connection: String

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(short) (\(build))"
    }

    var body: some View {
        Text("DEV • \(version) • \(role) • \(route) • \(connection)")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(WayfolioPalette.parchment)
            .lineLimit(2)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(WayfolioPalette.cyan.opacity(0.75), lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityLabel("Development build \(version), \(role), route \(route), \(connection)")
    }
}
#endif

/// WF-099 personal-device entry. The approved artwork supplies the visual
/// language; every state and control remains live SwiftUI backed by the Host.
private struct WayfolioPhoneLoginRoot: View {
    @EnvironmentObject private var session: GameSessionClient
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("wayfolio.session.host") private var savedHost = ""
    @AppStorage("wayfolio.session.code") private var savedCode = "HEMLOCK"
    @State private var host = ""
    @State private var code = "HEMLOCK"
    @State private var context: SharedLoginCampaignContext?
    @State private var selectedCharacterID = "renn"
    @State private var isLoading = false
    @State private var errorMessage: String?
    let onBeginSession: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let menuWidth = min(geometry.size.width - 16, 430)
            let menuHeight = menuWidth * (640.0 / 360.0)

            ZStack {
                Image("wayfolio-login-treetop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [.black.opacity(0.08), WayfolioPalette.midnight.opacity(0.20), .black.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        ZStack(alignment: .top) {
                            Image("wayfolio-start-menu-approved")
                                .resizable()
                                .scaledToFit()
                                .frame(width: menuWidth, height: menuHeight)
                                .accessibilityHidden(true)

                            approvedMenuContent
                                .frame(width: menuWidth * 0.76)
                                .padding(.top, menuWidth * 0.205)
                        }
                        .frame(width: menuWidth, height: menuHeight)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, max(geometry.safeAreaInsets.top - 2, 4))
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 14))
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            host = savedHost
            code = savedCode.isEmpty ? "HEMLOCK" : savedCode
            selectedCharacterID = session.selectedCharacterID
        }
        .onChange(of: host) { invalidateContext() }
        .onChange(of: code) { invalidateContext() }
    }

    private var approvedMenuContent: some View {
        VStack(spacing: 8) {
            Text(context?.journeyTitle ?? "SPIRITBLOOM: AWAKENING")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(WayfolioPalette.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(height: 35)

            if let context {
                compactProfileSelector(context)
                compactStatusBlock(context)
                beginButton(context)
                    .frame(height: 50)
                compactActionRow(
                    title: "Story Checkpoint",
                    value: context.storyCheckpoint,
                    symbol: "sparkles"
                )
                compactActionRow(
                    title: "Current Location",
                    value: context.currentLocation,
                    symbol: "location.fill"
                )
                Button("Use a different table") { self.context = nil }
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(WayfolioPalette.cyan)
                    .frame(minHeight: 32)
            } else {
                connectionSetup
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(Color(red: 1, green: 0.52, blue: 0.61))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var connectionSetup: some View {
        VStack(spacing: 10) {
            Text("Begin your adventure")
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundStyle(WayfolioPalette.parchment)
                .frame(height: 48)

            Button { beginStandaloneSession() } label: {
                Label("PLAY ON THIS IPHONE", systemImage: "iphone")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .font(WayfolioTypography.body.weight(.bold))
            .foregroundStyle(WayfolioPalette.parchment)
            .background(WayfolioPalette.violet.opacity(0.44), in: Capsule())
            .overlay(Capsule().stroke(WayfolioPalette.cyan.opacity(0.78), lineWidth: 1))
            .accessibilityHint("Starts or resumes Renn's journey without a Mac or iPad")

            Text("OR CONNECT TO A SHARED TABLE")
                .font(WayfolioTypography.tiny)
                .tracking(1.1)
                .foregroundStyle(WayfolioPalette.cyan)

            loginField("MAC HOST", placeholder: "192.168.4.28", text: $host, capitalization: .never)
            loginField("JOURNEY CODE", placeholder: "HEMLOCK", text: $code, capitalization: .characters)

            Button { Task { await findTable() } } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().tint(WayfolioPalette.parchment) }
                    Text("FIND MY WAYFOLIO")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .font(WayfolioTypography.body.weight(.semibold))
            .foregroundStyle(WayfolioPalette.parchment)
            .background(WayfolioPalette.violet.opacity(0.34), in: Capsule())
            .disabled(isLoading || host.trimmingCharacters(in: .whitespaces).isEmpty)

            Text("Independent play works on this iPhone. A Mac or shared iPad is optional.")
                .font(WayfolioTypography.tiny)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.76))
                .multilineTextAlignment(.center)
        }
    }

    private func compactProfileSelector(_ context: SharedLoginCampaignContext) -> some View {
        Menu {
            ForEach(selectableMembers(in: context)) { member in
                Button(member.name) { selectedCharacterID = member.id }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(WayfolioPalette.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text("PLAYER / CHARACTER")
                        .font(WayfolioTypography.tiny)
                        .foregroundStyle(WayfolioPalette.cyan)
                    Text(selectableMembers(in: context).first(where: { $0.id == selectedCharacterID })?.name ?? "Choose Wayfinder")
                        .font(WayfolioTypography.body)
                        .foregroundStyle(WayfolioPalette.parchment)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(WayfolioPalette.brassBright)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Player and character")
    }

    private func compactStatusBlock(_ context: SharedLoginCampaignContext) -> some View {
        VStack(spacing: 0) {
            compactMenuPicker(
                label: "PLAY MODE",
                value: session.preferredPlayMode == .iPhoneOnly ? "iPhone Only" : "iPhone + Shared iPad"
            ) {
                Button("iPhone Only") { session.selectPlayMode(.iPhoneOnly) }
                Button("iPhone + Shared iPad") { session.selectPlayMode(.iPhoneSharedIPad) }
            }
            Divider().overlay(WayfolioPalette.cyan.opacity(0.28))
            compactValueRow(
                label: "SHARED IPAD",
                value: session.preferredPlayMode == .iPhoneOnly ? "Enhancement Off" : "Ready to pair",
                symbol: "ipad"
            )
            Divider().overlay(WayfolioPalette.cyan.opacity(0.28))
            compactValueRow(
                label: "CAMPAIGN SYNC",
                value: context.readyToBegin ? "Up to Date" : "Gathering State",
                symbol: "arrow.triangle.2.circlepath"
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 148)
    }

    private func compactMenuPicker<Items: View>(label: String, value: String, @ViewBuilder items: () -> Items) -> some View {
        Menu(content: items) {
            compactValueRow(label: label, value: value, symbol: "iphone")
        }
    }

    private func compactValueRow(label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WayfolioPalette.cyan)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(WayfolioPalette.cyan)
                Text(value)
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func compactActionRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(WayfolioPalette.cyan)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(WayfolioPalette.cyan)
                Text(value)
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(WayfolioPalette.brassBright)
        }
        .frame(minHeight: 45)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var brand: some View {
        VStack(spacing: 8) {
            WayfolioApprovedIcon(assetName: "wayfolio-nav-live", size: 72)
                .accessibilityHidden(true)
            Text("SPIRITBLOOM: AWAKENING")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(WayfolioPalette.parchment)
                .multilineTextAlignment(.center)
            Text("WAYFOLIO DEVICE LOGIN")
                .font(WayfolioTypography.caption)
                .tracking(2.1)
                .foregroundStyle(WayfolioPalette.cyan)
        }
        .accessibilityElement(children: .combine)
    }

    private var loginWindow: some View {
        VStack(alignment: .leading, spacing: 17) {
            if let context {
                profileSelection(context)
                Divider().overlay(WayfolioPalette.brass.opacity(0.65))
                playModeSelection
                Divider().overlay(WayfolioPalette.brass.opacity(0.65))
                liveStatus(context)
                beginButton(context)
                Button("Use a different table") { self.context = nil }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(WayfolioPalette.cyan)
            } else {
                Text("Find your adventure")
                    .font(WayfolioTypography.display)
                    .foregroundStyle(WayfolioPalette.parchment)
                Text("Connect this personal Wayfolio to the Mac game host. No account password is needed.")
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.82))
                loginField("MAC HOST", placeholder: "192.168.4.28", text: $host, capitalization: .never)
                loginField("JOURNEY CODE", placeholder: "HEMLOCK", text: $code, capitalization: .characters)
                Button { Task { await findTable() } } label: {
                    HStack {
                        if isLoading { ProgressView().tint(WayfolioPalette.midnight) }
                        Text("FIND MY WAYFOLIO")
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.plain)
                .font(WayfolioTypography.title)
                .foregroundStyle(WayfolioPalette.midnight)
                .background(WayfolioPalette.brassBright, in: RoundedRectangle(cornerRadius: 13))
                .disabled(isLoading || host.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.danger)
                    .accessibilityLabel("Connection error. \(errorMessage)")
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .background(WayfolioPalette.midnight.opacity(0.91), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(WayfolioPalette.brassBright.opacity(0.84), lineWidth: 1.2))
        .shadow(color: WayfolioPalette.cyan.opacity(0.22), radius: 28)
    }

    private func profileSelection(_ context: SharedLoginCampaignContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHOSE WAYFOLIO IS THIS?")
                .font(WayfolioTypography.caption).tracking(1.2)
                .foregroundStyle(WayfolioPalette.cyan)
            ForEach(selectableMembers(in: context)) { member in
                Button {
                    selectedCharacterID = member.id
                } label: {
                    HStack(spacing: 14) {
                        SharedLoginPartyMemberView(member: member, hostBaseURL: httpBaseURL, presentation: .portrait)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.name).font(WayfolioTypography.title)
                            Text("\(member.species) · \(member.className)")
                                .font(WayfolioTypography.caption)
                            Text(member.connected ? "Currently connected" : "Available on this table")
                                .font(WayfolioTypography.tiny)
                                .foregroundStyle(member.connected ? WayfolioPalette.brassBright : WayfolioPalette.cyan)
                        }
                        Spacer()
                        Image(systemName: selectedCharacterID == member.id ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                    }
                    .foregroundStyle(WayfolioPalette.parchment)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                    .background(selectedCharacterID == member.id ? WayfolioPalette.cyan.opacity(0.14) : WayfolioPalette.navy.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(selectedCharacterID == member.id ? WayfolioPalette.cyan : WayfolioPalette.brass.opacity(0.64), lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(member.name), \(member.species), \(member.className)")
                .accessibilityValue(selectedCharacterID == member.id ? "Selected" : (member.connected ? "Connected to another device" : "Available"))
            }
        }
    }

    private func liveStatus(_ context: SharedLoginCampaignContext) -> some View {
        VStack(spacing: 10) {
            statusRow("DEVICE", "Recognized", ready: true)
            statusRow("DM CONNECTION", context.sessionCode, ready: true)
            statusRow("WAYFOLIO SYNC", context.readyToBegin ? "Ready" : "Gathering campaign state", ready: context.readyToBegin)
            statusRow("STORY CHECKPOINT", context.storyCheckpoint, ready: true)
            statusRow("CURRENT LOCATION", context.currentLocation, ready: true)
        }
        .accessibilityElement(children: .contain)
    }

    private var playModeSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW ARE YOU PLAYING?")
                .font(WayfolioTypography.caption)
                .tracking(1.2)
                .foregroundStyle(WayfolioPalette.cyan)
            playModeButton(
                .iPhoneOnly,
                title: "iPhone Only",
                detail: "Play privately from this Wayfolio. Add the shared iPad later without restarting."
            )
            playModeButton(
                .iPhoneSharedIPad,
                title: "iPhone + Shared iPad",
                detail: "Use the iPad for the public scene, voices, rolls, and table presentation."
            )
        }
    }

    private func playModeButton(
        _ mode: GameSessionClient.PlayMode,
        title: String,
        detail: String
    ) -> some View {
        Button {
            session.selectPlayMode(mode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: session.preferredPlayMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(WayfolioTypography.body)
                    Text(detail)
                        .font(WayfolioTypography.tiny)
                        .foregroundStyle(WayfolioPalette.parchment.opacity(0.72))
                }
                Spacer()
            }
            .foregroundStyle(WayfolioPalette.parchment)
            .padding(12)
            .background(
                session.preferredPlayMode == mode
                    ? WayfolioPalette.cyan.opacity(0.14)
                    : WayfolioPalette.navy.opacity(0.7),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        session.preferredPlayMode == mode
                            ? WayfolioPalette.cyan
                            : WayfolioPalette.brass.opacity(0.55),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityValue(session.preferredPlayMode == mode ? "Selected" : "Not selected")
    }
    private func statusRow(_ label: String, _ value: String, ready: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(ready ? WayfolioPalette.cyan : WayfolioPalette.brass).frame(width: 9, height: 9)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(WayfolioTypography.tiny).tracking(0.9).foregroundStyle(WayfolioPalette.cyan)
                Text(value).font(WayfolioTypography.caption).foregroundStyle(WayfolioPalette.parchment).lineLimit(3)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func beginButton(_ context: SharedLoginCampaignContext) -> some View {
        Button {
            savedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            savedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            session.chooseCharacter(selectedCharacterID)
            onBeginSession()
            if session.preferredPlayMode == .iPhoneOnly {
                session.startStandaloneSession()
            } else {
                session.connect(host: savedHost, code: savedCode)
            }
        } label: {
            Text("BEGIN SESSION AS \(selectableMembers(in: context).first(where: { $0.id == selectedCharacterID })?.name.uppercased() ?? "WAYFINDER")")
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.plain)
        .font(WayfolioTypography.body.weight(.bold))
        .foregroundStyle(WayfolioPalette.parchment)
        .background(context.readyToBegin ? WayfolioPalette.violet.opacity(0.42) : WayfolioPalette.navy.opacity(0.54), in: Capsule())
        .overlay(Capsule().stroke(WayfolioPalette.cyan.opacity(context.readyToBegin ? 0.76 : 0.24), lineWidth: 1))
        .disabled(!context.readyToBegin || selectableMembers(in: context).isEmpty)
        .accessibilityHint("Connects this phone as the selected character")
    }

    private func beginStandaloneSession() {
        selectedCharacterID = "renn"
        session.selectPlayMode(.iPhoneOnly)
        session.chooseCharacter(selectedCharacterID)
        session.startStandaloneSession()
        onBeginSession()
    }

    private func loginField(_ label: String, placeholder: String, text: Binding<String>, capitalization: TextInputAutocapitalization) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(WayfolioTypography.tiny).tracking(1.1).foregroundStyle(WayfolioPalette.cyan)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.parchment)
                .padding(.horizontal, 14)
                .frame(minHeight: 45)
                .background(WayfolioPalette.midnight.opacity(0.62), in: Capsule())
        }
    }

    @MainActor private func findTable() async {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanHost.isEmpty, !cleanCode.isEmpty else { return }
        guard var components = URLComponents(url: httpBaseURL, resolvingAgainstBaseURL: false) else { return }
        components.path = "/api/shared-login-context"
        components.queryItems = [URLQueryItem(name: "code", value: cleanCode)]
        guard let url = components.url else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let message = (try? JSONDecoder().decode(SharedLoginError.self, from: data).error) ?? "The Mac host did not accept that journey code."
                throw NSError(domain: "WayfolioPhoneLogin", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            let decoded = try JSONDecoder().decode(SharedLoginCampaignContext.self, from: data)
            context = decoded
            let available = selectableMembers(in: decoded)
            if !available.contains(where: { $0.id == selectedCharacterID }) { selectedCharacterID = available.first?.id ?? "renn" }
        } catch { context = nil; errorMessage = error.localizedDescription }
    }

    private func selectableMembers(in context: SharedLoginCampaignContext) -> [SharedLoginPartyMember] {
        context.party.filter { $0.id != "hinosuke" && ($0.playerControlled || ["renn", "yugen"].contains($0.id)) }
    }

    private var httpBaseURL: URL {
        let candidate = host.contains("://") ? host : "http://\(host)"
        var components = URLComponents(string: candidate) ?? URLComponents()
        components.scheme = "http"
        if components.port == nil { components.port = 8787 }
        components.path = ""; components.query = nil
        return components.url ?? URL(string: "http://localhost:8787")!
    }

    private func invalidateContext() { context = nil; errorMessage = nil }
}

private struct WayfolioIPadSharedRoot: View {
    @EnvironmentObject private var audio: WayfolioAudioEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("wayfolio.shared.host") private var host = ""
    @AppStorage("wayfolio.shared.journey") private var journeyCode = "HEMLOCK"
    @AppStorage("wayfolio.shared.remember") private var rememberTable = true
    @State private var draftHost = ""
    @State private var draftJourney = "HEMLOCK"
    @State private var revealsJourney = false
    @State private var isEditingConnection = false
    @State private var showingNewPlayerHelp = false
    @State private var loginContext: SharedLoginCampaignContext?
    @State private var connectionError: String?
    @State private var isCheckingTable = false
    @State private var sharedWebViewID = UUID()
    @State private var webLoadState = WayfolioWebLoadState.loading
    @State private var entryPhase = WayfolioSharedEntryPhase.start
    @State private var entryTask: Task<Void, Never>?
    @StateObject private var entryHaptics = WayfolioSharedEntryHaptics()

    var body: some View {
        ZStack {
            WayfolioPalette.midnight.ignoresSafeArea()
            if entryPhase == .gameplay, let sharedURL, !isEditingConnection {
                WayfolioSharedWebView(url: sharedURL, onStateChange: handleWebLoadState)
                    .id(sharedWebViewID)
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            draftHost = host
                            isEditingConnection = true
                        } label: {
                            Label("Shared Table Connection", systemImage: "wifi")
                                .font(WayfolioTypography.caption)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(WayfolioPalette.parchment)
                        .background(WayfolioPalette.midnight.opacity(0.9), in: Capsule())
                        .overlay(Capsule().stroke(WayfolioPalette.brass, lineWidth: 1))
                        .padding(16)
                    }

                if webLoadState != .ready {
                    sharedRecoverySurface
                }
            } else {
                connectionSetup
            }

            sharedEntryTransition
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onAppear {
            if draftHost.isEmpty { draftHost = host }
            if draftJourney.isEmpty { draftJourney = journeyCode }
            if host.isEmpty {
                isEditingConnection = true
            } else if loginContext == nil {
                Task { await fetchLoginContext(host: host, code: journeyCode) }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                entryTask?.cancel()
                entryPhase = .start
                if !host.isEmpty, loginContext == nil {
                    draftHost = host
                    draftJourney = journeyCode
                    Task { await fetchLoginContext(host: host, code: journeyCode) }
                }
            }
        }
        .onDisappear { entryTask?.cancel() }
        .sheet(isPresented: $showingNewPlayerHelp) {
            newPlayerHelp
        }
    }

    private var sharedRecoverySurface: some View {
        VStack(spacing: 18) {
            Image(systemName: webLoadState.isFailure ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(webLoadState.isFailure ? WayfolioPalette.danger : WayfolioPalette.cyan)
            Text(webLoadState.isFailure ? "The shared table needs attention" : "Opening the shared adventure")
                .font(WayfolioTypography.display)
                .foregroundStyle(WayfolioPalette.parchment)
            Text(webLoadState.message)
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            if webLoadState.isFailure {
                HStack(spacing: 14) {
                    Button("CHANGE CONNECTION") {
                        draftHost = host
                        isEditingConnection = true
                    }
                    .buttonStyle(.bordered)
                    Button("TRY AGAIN") {
                        webLoadState = .loading
                        sharedWebViewID = UUID()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WayfolioPalette.brassBright)
                    .foregroundStyle(WayfolioPalette.midnight)
                }
            } else {
                ProgressView().tint(WayfolioPalette.cyan)
            }
        }
        .padding(42)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SpiritbloomBootstrapBackground().ignoresSafeArea())
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(WayfolioPalette.brass.opacity(0.6), lineWidth: 1).padding(30))
        .accessibilityElement(children: .contain)
    }

    private func handleWebLoadState(_ state: WayfolioWebLoadState) {
        webLoadState = state
        print("[Wayfolio boot] iPad shared route \(state.diagnosticName)")
    }

    private var connectionSetup: some View {
        GeometryReader { geometry in
            ZStack {
                // Production login art is resolved by the Host manifest. Keep
                // the native layer neutral instead of treating superseded v01
                // artwork as the current shared-iPad composition.
                SpiritbloomBootstrapBackground()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [WayfolioPalette.midnight.opacity(0.22), Color.black.opacity(0.08), WayfolioPalette.midnight.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if let loginContext {
                    spiritbloomPreSession(loginContext, geometry: geometry)
                } else {
                    connectionCard
                        .frame(width: min(geometry.size.width * 0.38, 490))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .background(RoundedRectangle(cornerRadius: 24).fill(WayfolioPalette.midnight.opacity(0.76)))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(WayfolioPalette.brassBright.opacity(0.88), lineWidth: 1.2))
                        .shadow(color: WayfolioPalette.cyan.opacity(0.25), radius: 26)
                        .offset(y: geometry.size.height * 0.02)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: draftHost) { invalidatePreview() }
        .onChange(of: draftJourney) { invalidatePreview() }
    }

    private var connectionCard: some View {
        VStack(spacing: 15) {
            VStack(spacing: 2) {
                Text("ENTER THE SHARED ADVENTURE")
                    .font(WayfolioTypography.caption)
                    .tracking(1.6)
                    .foregroundStyle(WayfolioPalette.brassBright)
                Text("Connect this iPad to the Mac game host")
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.82))
            }
            connectionField(title: "MAC HOST", placeholder: "192.168.4.28", text: $draftHost)
            VStack(alignment: .leading, spacing: 6) {
                Text("JOURNEY CODE")
                    .font(WayfolioTypography.tiny)
                    .tracking(1.1)
                    .foregroundStyle(WayfolioPalette.cyan)
                HStack {
                    Group {
                        if revealsJourney { TextField("HEMLOCK", text: $draftJourney) }
                        else { SecureField("HEMLOCK", text: $draftJourney) }
                    }
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(WayfolioPalette.parchment)
                    Button { revealsJourney.toggle() } label: {
                        Image(systemName: revealsJourney ? "eye.slash" : "eye")
                            .foregroundStyle(WayfolioPalette.brassBright)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealsJourney ? "Hide journey code" : "Show journey code")
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(WayfolioPalette.midnight.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(WayfolioPalette.brass.opacity(0.82), lineWidth: 1))
            }
            if let connectionError {
                Label(connectionError, systemImage: "exclamationmark.triangle.fill")
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Find the table first. Wayfolio will confirm the active journey and show only party members the Mac host has made public.")
                    .font(WayfolioTypography.tiny)
                    .foregroundStyle(WayfolioPalette.parchment.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle("Remember this table", isOn: $rememberTable)
                .toggleStyle(.switch)
                .tint(WayfolioPalette.cyan)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment)
            Button { Task { await connect() } } label: {
                HStack(spacing: 9) {
                    if isCheckingTable { ProgressView().tint(WayfolioPalette.midnight) }
                    Text("FIND SHARED TABLE")
                }
            }
            .font(WayfolioTypography.title)
            .foregroundStyle(WayfolioPalette.midnight)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(WayfolioPalette.brassBright, in: RoundedRectangle(cornerRadius: 12))
            .buttonStyle(.plain)
            .disabled(isCheckingTable)
            HStack {
                Button("New player setup") { showingNewPlayerHelp = true }
                Spacer()
                if !host.isEmpty { Button("Cancel") { isEditingConnection = false } }
            }
            .font(WayfolioTypography.caption)
            .foregroundStyle(WayfolioPalette.cyan)
        }
        .padding(24)
    }

    private func spiritbloomPreSession(_ context: SharedLoginCampaignContext, geometry: GeometryProxy) -> some View {
        ZStack {
            Ellipse()
                .fill(WayfolioPalette.cyan.opacity(0.12))
                .frame(width: geometry.size.width * 0.72, height: geometry.size.height * 0.13)
                .blur(radius: 34)
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.66)

            ForEach(Array(layeredParty(context.party).enumerated()), id: \.element.member.id) { _, placement in
                let scale = placement.member.sprite?.scaleMultiplier ?? 1
                SharedLoginPartyMemberView(
                    member: placement.member,
                    hostBaseURL: httpBaseURL(for: draftHost),
                    presentation: .sprite
                )
                .frame(
                    width: geometry.size.width * 0.20 * scale,
                    height: geometry.size.height * 0.46 * scale,
                    alignment: .bottom
                )
                .position(
                    x: geometry.size.width * placement.x,
                    y: geometry.size.height * placement.y
                )
                .zIndex(1 + placement.depth * 0.01)
            }

            VStack(spacing: 12) {
                Text("WAYFOLIO")
                    .font(.system(size: min(geometry.size.width * 0.065, 66), weight: .semibold, design: .serif))
                    .tracking(5)
                    .foregroundStyle(WayfolioPalette.parchment)
                Text(context.journeyTitle.uppercased())
                    .font(WayfolioTypography.title)
                    .tracking(2.4)
                    .foregroundStyle(WayfolioPalette.cyan)
                Text("THE SHARED ADVENTURE IS GATHERING")
                    .font(WayfolioTypography.caption)
                    .tracking(1.7)
                    .foregroundStyle(WayfolioPalette.brassBright)
                HStack(spacing: 14) {
                    ForEach(Array(context.syncIndicators.enumerated()), id: \.element.id) { index, indicator in
                        Circle()
                            .fill(indicator.ready ? WayfolioPalette.cyan : WayfolioPalette.navy)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(WayfolioPalette.brassBright, lineWidth: 1))
                            .shadow(color: indicator.ready ? WayfolioPalette.cyan : .clear, radius: 7)
                            .animation(.easeOut(duration: 0.25).delay(Double(index) * 0.12), value: indicator.ready)
                            .accessibilityLabel("Readiness check \(index + 1)")
                            .accessibilityValue(indicator.ready ? "Ready" : "Waiting")
                    }
                }
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 34)
            .frame(width: geometry.size.width * 0.52)
            .background(WayfolioPalette.midnight.opacity(0.91), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(WayfolioPalette.cyan.opacity(0.82), lineWidth: 1.4))
            .shadow(color: WayfolioPalette.cyan.opacity(0.28), radius: 28)
            .position(x: geometry.size.width * 0.50, y: geometry.size.height * 0.48)
            .zIndex(20)

            VStack(spacing: 12) {
                HStack(spacing: 1) {
                    contextField("CURRENT STORY CHECKPOINT", context.storyCheckpoint)
                    contextField("SESSION INFORMATION", context.sessionInformation)
                    contextField("CURRENT LOCATION", context.currentLocation)
                }
                .background(WayfolioPalette.midnight.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(WayfolioPalette.brass.opacity(0.78), lineWidth: 1))

                HStack(spacing: 12) {
                    Button("CHANGE TABLE") { loginContext = nil }
                        .buttonStyle(.plain)
                        .font(WayfolioTypography.caption)
                        .foregroundStyle(WayfolioPalette.cyan)
                        .frame(minWidth: 150, minHeight: 52)
                        .background(WayfolioPalette.midnight.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(WayfolioPalette.cyan.opacity(0.7), lineWidth: 1))
                    Button("BEGIN SESSION") { beginSharedSession(context) }
                        .buttonStyle(.plain)
                        .font(WayfolioTypography.title)
                        .foregroundStyle(WayfolioPalette.midnight)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(context.readyToBegin ? WayfolioPalette.brassBright : WayfolioPalette.brass.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        .disabled(!context.readyToBegin)
                }
            }
            .padding(.horizontal, geometry.size.width * 0.055)
            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 18))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .zIndex(30)
        }
    }

    private func layeredParty(_ members: [SharedLoginPartyMember]) -> [SharedLoginPartyPlacement] {
        // The host order is presentation authority (the lead character is not
        // alphabetically re-sorted on the shared table).
        let ordered = members
        let count = max(ordered.count, 1)
        return ordered.enumerated().map { index, member in
            let x = 0.14 + (0.72 * Double(index + 1) / Double(count + 1))
            let centerDepth = 1 - min(1, abs(x - 0.5) * 2)
            let statureAdjustment = Double((member.sprite?.scaleMultiplier ?? 1) - 1) * 0.055
            return SharedLoginPartyPlacement(
                member: member,
                x: x,
                y: 0.47 + centerDepth * 0.035 + statureAdjustment,
                depth: 1 + centerDepth * 10
            )
        }
    }

    @ViewBuilder
    private var sharedEntryTransition: some View {
        if entryPhase.isTransitioning {
            GeometryReader { geometry in
                ZStack {
                    Color.white.opacity(entryPhase.whiteOpacity)

                    ForEach(0..<4, id: \.self) { index in
                        Ellipse()
                            .stroke(
                                index.isMultiple(of: 2) ? WayfolioPalette.cyan : WayfolioPalette.brassBright,
                                lineWidth: max(1, 4 - CGFloat(index))
                            )
                            .frame(
                                width: geometry.size.width * (0.20 + CGFloat(index) * 0.13),
                                height: geometry.size.height * (0.09 + CGFloat(index) * 0.065)
                            )
                            .scaleEffect(entryPhase.ringScale + CGFloat(index) * 0.10)
                            .opacity(entryPhase.ringOpacity * (1 - Double(index) * 0.14))
                            .blur(radius: CGFloat(index) * 1.8)
                    }

                    RoundedRectangle(cornerRadius: entryPhase.portalCornerRadius)
                        .fill(WayfolioPalette.cyan.opacity(entryPhase.portalOpacity * 0.34))
                        .overlay {
                            RoundedRectangle(cornerRadius: entryPhase.portalCornerRadius)
                                .stroke(WayfolioPalette.brassBright.opacity(entryPhase.portalOpacity), lineWidth: 2)
                        }
                        .frame(
                            width: geometry.size.width * entryPhase.portalWidth,
                            height: geometry.size.height * entryPhase.portalHeight
                        )
                        .scaleEffect(entryPhase.portalScale)
                        .blur(radius: 18)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
        }
    }

    @MainActor
    private func beginSharedSession(_ context: SharedLoginCampaignContext) {
        guard context.readyToBegin, entryPhase == .start else { return }
        let cleanedHost = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedJourney = draftJourney.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanedHost.isEmpty, !cleanedJourney.isEmpty else { return }

        host = cleanedHost
        journeyCode = cleanedJourney
        isEditingConnection = false
        entryTask?.cancel()
        entryTask = Task { @MainActor in
            audio.playUISound("spell_chime", volume: 0.72)
            entryHaptics.tap(.light)
            await setEntryPhase(.firstFlash, duration: reduceMotion ? 0.08 : 0.14)
            await setEntryPhase(.dip, duration: reduceMotion ? 0.07 : 0.12)

            audio.playUISound("spell_chime", volume: 0.88)
            entryHaptics.tap(.medium)
            await setEntryPhase(.secondFlash, duration: reduceMotion ? 0.09 : 0.17)
            await setEntryPhase(.settle, duration: reduceMotion ? 0.08 : 0.18)

            entryHaptics.tap(.soft)
            await setEntryPhase(.ellipseMorph, duration: reduceMotion ? 0.10 : 0.32)

            audio.playUISound("floating_arcane_pulse", volume: 0.72)
            await setEntryPhase(.gateway, duration: reduceMotion ? 0.15 : 0.42)

            audio.playUISound("spell_teleport", volume: 0.82)
            entryHaptics.risingPulse(reduced: reduceMotion)
            await setEntryPhase(.accelerating, duration: reduceMotion ? 0.24 : 0.82)

            audio.playUISound("transition_arrival", volume: 0.94)
            entryHaptics.tap(.heavy)
            await setEntryPhase(.whiteout, duration: reduceMotion ? 0.12 : 0.28)
            entryPhase = .gameplay
            webLoadState = .loading
            sharedWebViewID = UUID()
        }
    }

    @MainActor
    private func setEntryPhase(_ phase: WayfolioSharedEntryPhase, duration: Double) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: duration)) { entryPhase = phase }
        try? await Task.sleep(for: .seconds(duration))
    }

    private func contextField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(WayfolioTypography.tiny)
                .tracking(1.1)
                .foregroundStyle(WayfolioPalette.cyan)
            Text(value)
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.parchment)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
    }

    private func connectionField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(WayfolioTypography.tiny)
                .tracking(1.1)
                .foregroundStyle(WayfolioPalette.cyan)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(WayfolioPalette.parchment)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(WayfolioPalette.midnight.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(WayfolioPalette.brass.opacity(0.82), lineWidth: 1))
        }
    }

    private var newPlayerHelp: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(WayfolioFeatureIcon.character.rawValue)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 86)
                Text("Add the player on the Mac launcher, then connect their phone Wayfolio to the same journey. The iPad remains the shared public table.")
                    .font(WayfolioTypography.body)
                    .multilineTextAlignment(.center)
                Text("Wayfolio does not currently have a separate username/password account service, so this screen uses the real Mac host and journey code.")
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .navigationTitle("New Player Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingNewPlayerHelp = false }
                }
            }
        }
    }

    @MainActor
    private func connect() async {
        let cleanedHost = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedJourney = draftJourney.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanedHost.isEmpty, !cleanedJourney.isEmpty else { return }
        if loginContext == nil {
            await fetchLoginContext(host: cleanedHost, code: cleanedJourney)
            return
        }
        host = cleanedHost
        journeyCode = cleanedJourney
        if !rememberTable {
            draftHost = cleanedHost
            draftJourney = cleanedJourney
        }
        isEditingConnection = false
    }

    @MainActor
    private func fetchLoginContext(host: String, code: String) async {
        guard var components = URLComponents(url: httpBaseURL(for: host), resolvingAgainstBaseURL: false) else {
            connectionError = "Enter the Mac host address shown by the Wayfolio launcher."
            return
        }
        components.path = "/api/shared-login-context"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        guard let url = components.url else {
            connectionError = "The Mac host address could not be read."
            return
        }
        isCheckingTable = true
        connectionError = nil
        defer { isCheckingTable = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONDecoder().decode(SharedLoginError.self, from: data).error)
                    ?? "The Mac host did not accept that journey code."
                throw NSError(domain: "WayfolioSharedLogin", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: message])
            }
            let context = try JSONDecoder().decode(SharedLoginCampaignContext.self, from: data)
            guard context.sessionCode == code else {
                throw NSError(domain: "WayfolioSharedLogin", code: 409,
                              userInfo: [NSLocalizedDescriptionKey: "The Mac host returned a different journey code."])
            }
            loginContext = context
        } catch {
            loginContext = nil
            connectionError = error.localizedDescription
        }
    }

    private func invalidatePreview() {
        loginContext = nil
        connectionError = nil
    }

    private func httpBaseURL(for value: String) -> URL {
        let candidate = value.contains("://") ? value : "http://\(value)"
        var components = URLComponents(string: candidate) ?? URLComponents()
        components.scheme = "http"
        if components.port == nil { components.port = 8787 }
        components.path = ""
        components.query = nil
        return components.url ?? URL(string: "http://localhost:8787")!
    }

    private var sharedURL: URL? {
        let candidate = host.contains("://") ? host : "http://\(host)"
        guard var components = URLComponents(string: candidate) else { return nil }
        components.scheme = "http"
        if components.port == nil { components.port = 8787 }
        components.path = "/shared"
        components.queryItems = [URLQueryItem(name: "journey", value: journeyCode)]
        return components.url
    }
}

private enum WayfolioSharedEntryPhase: Equatable {
    case start, firstFlash, dip, secondFlash, settle, ellipseMorph, gateway, accelerating, whiteout, gameplay

    var isTransitioning: Bool { self != .start && self != .gameplay }
    var ringOpacity: Double {
        switch self {
        case .gateway: 0.52
        case .accelerating: 0.92
        case .whiteout: 0.38
        default: 0
        }
    }
    var ringScale: CGFloat {
        switch self {
        case .gateway: 0.72
        case .accelerating: 1.75
        case .whiteout: 2.7
        default: 0.45
        }
    }
    var portalOpacity: Double {
        switch self {
        case .firstFlash, .secondFlash: 0.82
        case .settle: 0.28
        case .ellipseMorph: 0.58
        case .gateway: 0.72
        case .accelerating: 1
        case .whiteout: 0.32
        default: 0
        }
    }
    var portalScale: CGFloat {
        switch self {
        case .firstFlash, .secondFlash: 0.25
        case .settle: 0.46
        case .ellipseMorph: 0.68
        case .gateway: 0.78
        case .accelerating: 1.65
        case .whiteout: 2.4
        default: 0.1
        }
    }
    var whiteOpacity: Double {
        switch self {
        case .firstFlash: 0.20
        case .secondFlash: 0.34
        case .whiteout: 1
        default: 0
        }
    }

    var portalWidth: CGFloat {
        switch self {
        case .firstFlash, .dip, .secondFlash, .settle: 0.44
        case .ellipseMorph: 0.52
        default: 0.58
        }
    }

    var portalHeight: CGFloat {
        switch self {
        case .firstFlash, .dip, .secondFlash, .settle: 0.22
        case .ellipseMorph: 0.15
        default: 0.12
        }
    }

    var portalCornerRadius: CGFloat {
        switch self {
        case .firstFlash, .dip, .secondFlash, .settle: 28
        case .ellipseMorph: 90
        default: 999
        }
    }
}

@MainActor
private final class WayfolioSharedEntryHaptics: ObservableObject {
    func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func risingPulse(reduced: Bool) {
        guard !reduced else { tap(.medium); return }
        Task { @MainActor in
            for (index, delay) in [0, 95, 170, 230, 280].enumerated() {
                if delay > 0 { try? await Task.sleep(for: .milliseconds(delay - (index > 0 ? [0, 95, 170, 230, 280][index - 1] : 0))) }
                tap(index < 2 ? .soft : index < 4 ? .medium : .rigid)
            }
        }
    }
}

private struct SpiritbloomBootstrapBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.085, blue: 0.13),
                    WayfolioPalette.midnight,
                    Color(red: 0.015, green: 0.045, blue: 0.075)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [WayfolioPalette.cyan.opacity(0.16), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 620
            )

            Image(systemName: "sparkles")
                .font(.system(size: 190, weight: .ultraLight))
                .foregroundStyle(WayfolioPalette.brassBright.opacity(0.08))
                .accessibilityHidden(true)
        }
    }
}

private struct SharedLoginCampaignContext: Decodable {
    let schemaVersion: Int
    let sessionCode: String
    let activeJourneyID: String
    let journeyTitle: String
    let sceneTitle: String
    let storyCheckpoint: String
    let sessionInformation: String
    let currentLocation: String
    let syncIndicators: [SharedLoginSyncIndicator]
    let readyToBegin: Bool
    let party: [SharedLoginPartyMember]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionCode = "session_code"
        case activeJourneyID = "active_journey_id"
        case journeyTitle = "journey_title"
        case sceneTitle = "scene_title"
        case storyCheckpoint = "story_checkpoint"
        case sessionInformation = "session_information"
        case currentLocation = "current_location"
        case syncIndicators = "sync_indicators"
        case readyToBegin = "ready_to_begin"
        case party
    }
}

private struct SharedLoginSyncIndicator: Decodable, Identifiable {
    let id: String
    let ready: Bool
}

private struct SharedLoginPartyMember: Decodable, Identifiable {
    let id: String
    let name: String
    let species: String
    let className: String
    let partyRole: String
    let scenePresence: String
    let playerControlled: Bool
    let connected: Bool
    let sprite: SharedLoginSprite?

    enum CodingKeys: String, CodingKey {
        case id, name, species, sprite, connected
        case className = "class_name"
        case partyRole = "party_role"
        case scenePresence = "scene_presence"
        case playerControlled = "player_controlled"
    }
}

private struct SharedLoginPartyPlacement {
    let member: SharedLoginPartyMember
    let x: Double
    let y: Double
    let depth: Double
}

private struct SharedLoginSprite: Decodable {
    let spriteID: String
    let version: Int
    let url: String
    let approvalStatus: String
    let loginEligible: Bool
    let facing: String
    let mirrorAllowed: Bool
    let scaleBand: String

    enum CodingKeys: String, CodingKey {
        case version, url, facing
        case spriteID = "sprite_id"
        case approvalStatus = "approval_status"
        case loginEligible = "login_eligible"
        case mirrorAllowed = "mirror_allowed"
        case scaleBand = "scale_band"
    }

    var scaleMultiplier: CGFloat {
        switch scaleBand.lowercased() {
        case "small", "compact": 0.84
        case "tall", "large": 1.12
        default: 1
        }
    }
}

private struct SharedLoginError: Decodable {
    let error: String
}

private struct SharedLoginPartyMemberView: View {
    enum Presentation: Equatable { case portrait, sprite }

    let member: SharedLoginPartyMember
    let hostBaseURL: URL
    var presentation: Presentation = .portrait

    private var isReady: Bool {
        guard member.sprite != nil else { return false }
        return member.playerControlled ? member.connected : member.scenePresence != "absent"
    }

    var body: some View {
        Group {
            if presentation == .sprite {
                VStack(spacing: 5) {
                    portrait
                        .scaledToFit()
                        .saturation(isReady ? 1 : 0.03)
                        .brightness(isReady ? 0 : -0.72)
                        .colorMultiply(isReady ? .white : Color(red: 0.13, green: 0.13, blue: 0.25))
                        .opacity(isReady ? 1 : 0.88)
                    Text(member.name)
                        .font(WayfolioTypography.caption)
                        .foregroundStyle(isReady ? WayfolioPalette.parchment : WayfolioPalette.parchment.opacity(0.58))
                }
            } else {
                VStack(spacing: 6) {
                    portrait
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(WayfolioPalette.brassBright, lineWidth: 1))
                    Text(member.name)
                        .font(WayfolioTypography.caption)
                        .foregroundStyle(WayfolioPalette.parchment)
                        .lineLimit(1)
                    Text(member.partyRole.uppercased())
                        .font(WayfolioTypography.tiny)
                        .foregroundStyle(WayfolioPalette.cyan)
                        .lineLimit(1)
                }
                .frame(width: 98)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.name), \(member.partyRole), \(isReady ? "ready" : "waiting")")
    }

    @ViewBuilder
    private var portrait: some View {
        if let sprite = member.sprite,
           sprite.approvalStatus == "approved",
           sprite.loginEligible,
           let url = URL(string: sprite.url, relativeTo: hostBaseURL)?.absoluteURL {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: presentation == .sprite ? .fit : .fill)
                case .empty:
                    ProgressView().tint(WayfolioPalette.cyan)
                case .failure:
                    approvedArtUnavailable
                @unknown default:
                    approvedArtUnavailable
                }
            }
        } else {
            approvedArtUnavailable
        }
    }

    private var approvedArtUnavailable: some View {
        ZStack {
            WayfolioPalette.navy
            WayfolioApprovedIcon(.character, size: 34)
        }
    }
}

private enum WayfolioWebLoadState: Equatable {
    case loading
    case ready
    case failed(String)

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .loading: return "Wayfolio is loading the local table. Its native controls remain available while the Host responds."
        case .ready: return "The shared table is ready."
        case .failed(let message): return message
        }
    }

    var diagnosticName: String {
        switch self {
        case .loading: return "loading"
        case .ready: return "ready"
        case .failed: return "degraded ready"
        }
    }
}

private struct WayfolioSharedWebView: UIViewRepresentable {
    let url: URL
    let onStateChange: (WayfolioWebLoadState) -> Void

    private func currentRequest() -> URLRequest {
        URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.contentInsetAdjustmentBehavior = .never
        onStateChange(.loading)
        view.load(currentRequest())
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        onStateChange(.loading)
        webView.load(currentRequest())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChange: onStateChange)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onStateChange: (WayfolioWebLoadState) -> Void

        init(onStateChange: @escaping (WayfolioWebLoadState) -> Void) {
            self.onStateChange = onStateChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onStateChange(.ready)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onStateChange(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onStateChange(.failed(error.localizedDescription))
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onStateChange(.failed("The shared display stopped responding. Try again to restore the current journey."))
        }
    }
}

private struct WayfolioProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: GameSessionClient
    @State private var showingImageEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section("Wayfinder") {
                    HStack(spacing: 12) {
                        CharacterPortraitView(
                            characterID: session.selectedCharacterID,
                            characterName: session.character?.name ?? session.playerName,
                            size: 54
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.character?.name ?? session.playerName)
                            Text("Player Wayfolio").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showingImageEditor = true
                    } label: {
                        Label("Edit Character Image", systemImage: "photo.badge.plus")
                    }
                    LabeledContent("Role", value: "Player Wayfolio")
                }

                Section("Wayfolio") {
                    NavigationLink {
                        WayfinderSessionView(showsHostPages: false)
                            .navigationTitle("Session")
                    } label: {
                        Label("Session", systemImage: "dot.radiowaves.left.and.right")
                    }

                    NavigationLink {
                        WayfolioProfileInformationView(
                            symbol: "speaker.wave.2.fill",
                            title: "Audio & Accessibility",
                            message: "Creature previews and interface sounds follow the existing Wayfolio audio system. VoiceOver, Dynamic Type, Reduce Motion, and device audio settings remain available throughout play."
                        )
                    } label: {
                        Label("Audio & Accessibility", systemImage: "speaker.wave.2.fill")
                    }

                    NavigationLink {
                        WayfolioProfileInformationView(
                            symbol: "gearshape.fill",
                            title: "Settings",
                            message: "Additional player settings will appear here when they have persistent, gameplay-safe contracts."
                        )
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WayfolioPalette.midnight)
            .foregroundStyle(WayfolioPalette.parchment)
            .navigationTitle("Wayfolio Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingImageEditor) {
            CharacterImageEditor(
                characterID: session.selectedCharacterID,
                characterName: session.character?.name ?? session.playerName
            )
        }
    }
}

private struct WayfolioProfileInformationView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(WayfolioPalette.cyan)
            Text(message)
                .font(WayfolioTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(WayfolioPalette.parchment.opacity(0.82))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WayfolioPalette.midnight.ignoresSafeArea())
        .navigationTitle(title)
    }
}
