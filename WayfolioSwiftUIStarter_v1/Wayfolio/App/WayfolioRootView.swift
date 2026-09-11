import SwiftUI

#if canImport(CoreHaptics)
import CoreHaptics
#endif

#if canImport(UIKit)
import UIKit
#endif

struct WayfolioRootView: View {
    @EnvironmentObject private var session: WayfolioSessionContext

    @State private var selectedSection: WayfolioSection = .entries
    @State private var guidePath: [WayfolioRoute] = []
    @State private var entriesPath: [WayfolioRoute] = []
    @State private var mapPath: [WayfolioRoute] = []
    @State private var notesPath: [WayfolioRoute] = []
    @State private var morePath: [WayfolioRoute] = []

    @State private var startPhase: SessionStartPhase = .login
    @State private var blackoutOpacity: Double = 0
    @State private var sessionStartTask: Task<Void, Never>?
    private let haptics = WayfolioSessionHaptics()

    var body: some View {
        ZStack {
            WayfolioShell(
                section: selectedSection,
                title: currentTitle,
                subtitle: currentSubtitle,
                canGoBack: currentPathIsNotEmpty,
                presentation: shellPresentation,
                backgroundAssetName: session.backgroundAssetName,
                onBack: popCurrentPath,
                onSelectSection: switchSection
            ) {
                currentNavigationStack
            }
            .allowsHitTesting(startPhase == .active)

            WayfolioLoginGate(session: session, onBeginSession: beginSession)
                .opacity(startPhase == .login ? 1 : 0)
                .allowsHitTesting(startPhase == .login)
                .animation(.easeOut(duration: 0.22), value: startPhase)
                .zIndex(20)

            Color.black
                .ignoresSafeArea()
                .opacity(blackoutOpacity)
                .allowsHitTesting(false)
                .zIndex(30)
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            sessionStartTask?.cancel()
        }
    }

    private var shellPresentation: WayfolioShellPresentation {
        switch startPhase {
        case .login, .blackout:
            return .hidden
        case .chrome:
            return WayfolioShellPresentation(
                chromeVisible: true,
                transitionPanelsOpacity: 0,
                contentOpacity: 0,
                backgroundOpacity: 0
            )
        case .panels:
            return WayfolioShellPresentation(
                chromeVisible: true,
                transitionPanelsOpacity: 1,
                contentOpacity: 0,
                backgroundOpacity: 0
            )
        case .content:
            return WayfolioShellPresentation(
                chromeVisible: true,
                transitionPanelsOpacity: 0.34,
                contentOpacity: 1,
                backgroundOpacity: 0
            )
        case .background:
            return WayfolioShellPresentation(
                chromeVisible: true,
                transitionPanelsOpacity: 0,
                contentOpacity: 1,
                backgroundOpacity: 1
            )
        case .active:
            return .active
        }
    }

    private func beginSession() {
        guard startPhase == .login else { return }

        sessionStartTask?.cancel()
        haptics.playProgressiveSessionStartPattern()

        sessionStartTask = Task { @MainActor in
            // Login quickly fades to black.
            withAnimation(.easeOut(duration: 0.22)) {
                blackoutOpacity = 1
                startPhase = .blackout
            }
            await sleep(milliseconds: 220)
            guard !Task.isCancelled else { return }

            // Hold on full black for exactly half a second.
            await sleep(milliseconds: 500)
            guard !Task.isCancelled else { return }

            // Upper bar drops in while lower gameplay dock rises from the bottom.
            startPhase = .chrome
            withAnimation(.easeOut(duration: 0.10)) {
                blackoutOpacity = 0
            }
            await sleep(milliseconds: 480)
            guard !Task.isCancelled else { return }

            // Empty menu/window frames fade in next.
            startPhase = .panels
            await sleep(milliseconds: 300)
            guard !Task.isCancelled else { return }

            // Live content follows the frames.
            startPhase = .content
            await sleep(milliseconds: 320)
            guard !Task.isCancelled else { return }

            // The campaign environment is deliberately last.
            startPhase = .background
            await sleep(milliseconds: 650)
            guard !Task.isCancelled else { return }

            startPhase = .active
        }
    }

    private func sleep(milliseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: milliseconds * 1_000_000)
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

private enum SessionStartPhase {
    case login
    case blackout
    case chrome
    case panels
    case content
    case background
    case active
}

private struct WayfolioLoginGate: View {
    @ObservedObject var session: WayfolioSessionContext
    let onBeginSession: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 430, proxy.size.height / 932)
            let canvasWidth = 430 * scale
            let canvasHeight = 932 * scale
            let originX = (proxy.size.width - canvasWidth) / 2
            let originY = (proxy.size.height - canvasHeight) / 2

            ZStack(alignment: .topLeading) {
                Color.black

                Image(session.backgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: canvasWidth, height: canvasHeight)
                    .clipped()
                    .position(
                        x: originX + canvasWidth / 2,
                        y: originY + canvasHeight / 2
                    )

                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.black.opacity(0.20), Color.black.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: canvasWidth, height: canvasHeight)
                .position(
                    x: originX + canvasWidth / 2,
                    y: originY + canvasHeight / 2
                )

                Group {
                    if approvedMenuArtworkAvailable {
                        approvedMenuCanvas
                    } else {
                        fallbackLoginCanvas
                    }
                }
                .frame(width: 430, height: 932, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .offset(x: originX, y: originY)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var approvedMenuCanvas: some View {
        ZStack(alignment: .topLeading) {
            menuMaster
            menuLiveOverlay
        }
    }

    private var menuMaster: some View {
        Image("wayfolio-login-menu-final")
            .resizable()
            .frame(width: 941, height: 1879)
            .scaleEffect(0.472, anchor: .topLeading)
            .offset(x: -7, y: 14)
    }

    private var menuLiveOverlay: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if loginPortraitAvailable {
                    Image("renn-login-avatar")
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "hare.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .foregroundStyle(.white.opacity(0.90))
                        .background(Color(red: 0.03, green: 0.11, blue: 0.27))
                }
            }
            .frame(width: 118, height: 118)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.cyan.opacity(0.60), lineWidth: 2))
            .shadow(color: .cyan.opacity(0.28), radius: 10)
            .position(x: 223, y: 601)

            loginText("LOGGING IN AS", at: CGPoint(x: 330, y: 566), size: 17, color: .wayfolioGold)
            loginText(session.playerName, at: CGPoint(x: 330, y: 611), size: 39, color: .white)
            loginText(session.deviceName, at: CGPoint(x: 330, y: 638), size: 19, color: .white.opacity(0.92), serif: false)

            statusRing(center: CGPoint(x: 221, y: 787), radius: 58.4)
            statusRing(center: CGPoint(x: 221, y: 917), radius: 58.2)
            statusRing(center: CGPoint(x: 220, y: 1055), radius: 56.2)

            loginText("RECOGNIZED DEVICE", at: CGPoint(x: 336, y: 748), size: 17, color: .wayfolioGold)
            loginText(session.deviceName, at: CGPoint(x: 336, y: 795), size: 36, color: .white)

            loginText("CONNECTED TO", at: CGPoint(x: 336, y: 882), size: 17, color: .wayfolioGold)
            loginText("Dungeon Master", at: CGPoint(x: 336, y: 929), size: 36, color: .white)

            loginText("WAYFOLIO SYNCHRONIZED", at: CGPoint(x: 336, y: 1017), size: 17, color: .wayfolioGold)
            loginText("All Records Synchronized", at: CGPoint(x: 336, y: 1064), size: 33, color: .white)

            Text("BEGIN SESSION  →")
                .font(.system(size: 51, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.82), radius: 3)
                .shadow(color: .cyan.opacity(0.34), radius: 6)
                .position(x: 471, y: 1231)

            loginText("CURRENT STORY CHECKPOINT", at: CGPoint(x: 326, y: 1361), size: 16, color: .wayfolioGold)
            loginText(session.checkpointTitle, at: CGPoint(x: 326, y: 1403), size: 32, color: .white)
            loginText(session.checkpointDetail, at: CGPoint(x: 326, y: 1432), size: 18, color: .white.opacity(0.92), serif: false, width: 430)

            loginText("CURRENT LOCATION", at: CGPoint(x: 326, y: 1494), size: 16, color: .wayfolioGold)
            loginText(session.locationTitle, at: CGPoint(x: 326, y: 1538), size: 36, color: .white)
            loginText(session.locationSubtitle, at: CGPoint(x: 326, y: 1567), size: 19, color: .white.opacity(0.92), serif: false)

            Button(action: onBeginSession) {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: 634, height: 129)
            .position(x: 473, y: 1225)
            .accessibilityLabel("Begin Session")
        }
        .frame(width: 941, height: 1879, alignment: .topLeading)
        .scaleEffect(0.472, anchor: .topLeading)
        .offset(x: -7, y: 14)
    }

    private var fallbackLoginCanvas: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 42)

            VStack(spacing: 4) {
                Text("SPIRITBLOOM: AWAKENING")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.5), radius: 8)
                Text("WAYFOLIO DEVICE LOGIN")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.6)
                    .foregroundStyle(.cyan.opacity(0.88))
            }

            Spacer(minLength: 90)

            VStack(spacing: 12) {
                fallbackRow(label: "LOGGING IN AS", value: session.playerName)
                fallbackRow(label: "RECOGNIZED DEVICE", value: session.deviceName)
                fallbackRow(label: "CONNECTED TO", value: "Dungeon Master")
                fallbackRow(label: "WAYFOLIO SYNCHRONIZED", value: "All Records Synchronized")
            }
            .padding(.horizontal, 26)

            Button(action: onBeginSession) {
                Text("BEGIN SESSION  →")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 29, style: .continuous)
                            .fill(Color(red: 0.10, green: 0.18, blue: 0.48).opacity(0.82))
                            .overlay(
                                RoundedRectangle(cornerRadius: 29, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.cyan, Color(red: 0.49, green: 0.37, blue: 1)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .shadow(color: .cyan.opacity(0.34), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 54)

            VStack(alignment: .leading, spacing: 10) {
                Text("CURRENT STORY CHECKPOINT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.wayfolioGold)
                Text(session.checkpointTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(session.checkpointDetail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                Divider().overlay(Color.cyan.opacity(0.28))

                Text("CURRENT LOCATION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.wayfolioGold)
                Text(session.locationTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(session.locationSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(20)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer(minLength: 28)
        }
        .frame(width: 430, height: 932)
    }

    private func fallbackRow(label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.cyan, Color(red: 0.49, green: 0.37, blue: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: .cyan.opacity(0.40), radius: 8)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "sparkles").foregroundStyle(.white.opacity(0.86)))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.wayfolioGold)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 76)
        .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
        )
    }

    private func statusRing(center: CGPoint, radius: CGFloat) -> some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        .cyan,
                        Color(red: 0.20, green: 0.68, blue: 1),
                        Color(red: 0.60, green: 0.33, blue: 1),
                        .cyan
                    ],
                    center: .center
                ),
                lineWidth: 4
            )
            .shadow(color: .cyan.opacity(0.52), radius: 11)
            .shadow(color: Color(red: 0.53, green: 0.35, blue: 1).opacity(0.34), radius: 15)
            .frame(width: radius * 2, height: radius * 2)
            .position(x: center.x, y: center.y)
    }

    private func loginText(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        color: Color,
        serif: Bool = true,
        width: CGFloat? = nil
    ) -> some View {
        Text(text)
            .font(.system(size: size, weight: size >= 30 ? .medium : .semibold, design: serif ? .serif : .default))
            .foregroundStyle(color)
            .lineLimit(2)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: width == nil, vertical: true)
            .position(x: point.x + (width ?? 0) / 2, y: point.y)
    }

    private var approvedMenuArtworkAvailable: Bool {
        #if canImport(UIKit)
        UIImage(named: "wayfolio-login-menu-final") != nil
        #else
        false
        #endif
    }

    private var loginPortraitAvailable: Bool {
        #if canImport(UIKit)
        UIImage(named: "renn-login-avatar") != nil
        #else
        false
        #endif
    }
}

private extension Color {
    static let wayfolioGold = Color(red: 0.94, green: 0.79, blue: 0.47)
}

@MainActor
private final class WayfolioSessionHaptics {
    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    #endif

    init() {
        prepare()
    }

    func prepare() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
        #endif
    }

    func playProgressiveSessionStartPattern() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil { prepare() }
        guard let engine else { return }

        let durations: [TimeInterval] = [0.030, 0.050, 0.075, 0.110, 0.155]
        let gap: TimeInterval = 0.070
        var time: TimeInterval = 0
        var events: [CHHapticEvent] = []

        for duration in durations {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.72),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.22)
                ],
                relativeTime: time,
                duration: duration
            )
            events.append(event)
            time += duration + gap
        }

        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are enhancement-only. The visual transition must always continue.
        }
        #endif
    }
}
