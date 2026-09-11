import SwiftUI

struct ParchmentSurface: ViewModifier {
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WayfolioPalette.parchment, WayfolioPalette.parchmentDeep.opacity(0.94)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(WayfolioPalette.brass.opacity(0.8), lineWidth: 1)
                    }
            )
    }
}

struct NavySurface: ViewModifier {
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WayfolioPalette.navyRaised, WayfolioPalette.midnight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(WayfolioPalette.brass.opacity(0.7), lineWidth: 1)
                    }
            )
    }
}

// MARK: - Shared iPad glass language

/// Approved Shared Table glass roles for iPad gameplay presentation.
///
/// The iPad glass language intentionally does NOT use visible strokes or borders.
/// Shape separation comes from translucency, backdrop diffusion, cyan-blue tint,
/// and restrained depth shadow. The main dialogue panel is deliberately much more
/// transparent than the speaker tag and response choices so full-screen scene art
/// remains visually dominant.
enum SharedIPadGlassRole: Equatable {
    case dialogue
    case speakerTag
    case choice
    case notification

    fileprivate var materialOpacity: Double {
        switch self {
        case .dialogue: return 0.14
        case .speakerTag: return 0.28
        case .choice: return 0.22
        case .notification: return 0.24
        }
    }

    fileprivate var cyanTintOpacity: Double {
        switch self {
        case .dialogue: return 0.075
        case .speakerTag: return 0.15
        case .choice: return 0.11
        case .notification: return 0.12
        }
    }

    fileprivate var blueTintOpacity: Double {
        switch self {
        case .dialogue: return 0.055
        case .speakerTag: return 0.10
        case .choice: return 0.075
        case .notification: return 0.08
        }
    }

    fileprivate var shadowOpacity: Double {
        switch self {
        case .dialogue: return 0.15
        case .speakerTag: return 0.18
        case .choice: return 0.16
        case .notification: return 0.16
        }
    }
}

struct SharedIPadGlassSurface: ViewModifier {
    let role: SharedIPadGlassRole
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .opacity(role.materialOpacity)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    WayfolioPalette.cyan.opacity(role.cyanTintOpacity),
                                    Color.blue.opacity(role.blueTintOpacity),
                                    WayfolioPalette.cyan.opacity(role.cyanTintOpacity * 0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(
                    color: Color.black.opacity(role.shadowOpacity),
                    radius: role == .dialogue ? 18 : 13,
                    y: role == .dialogue ? 9 : 6
                )
                .shadow(
                    color: WayfolioPalette.cyan.opacity(role == .dialogue ? 0.035 : 0.055),
                    radius: role == .dialogue ? 13 : 10
                )
            }
    }
}

/// Canonical Shared Table dialogue container.
/// The speaker tag overlaps the top edge of the main glass panel rather than
/// occupying a separate row. This stacked relationship is part of the approved
/// iPad dialogue composition and should be preserved across dialogue variants.
struct SharedIPadDialogueGlass<Content: View>: View {
    let speaker: String
    let content: Content

    init(speaker: String, @ViewBuilder content: () -> Content) {
        self.speaker = speaker
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
                .padding(.horizontal, 28)
                .padding(.top, 38)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sharedIPadGlass(role: .dialogue, radius: 24)
                .padding(.top, 20)

            Text(speaker)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color.white.opacity(0.96))
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .sharedIPadGlass(role: .speakerTag, radius: 20)
                .padding(.leading, 24)
        }
    }
}

struct SharedIPadChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.78 : 0.96))
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sharedIPadGlass(role: .choice, radius: 18)
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    func parchmentSurface(radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(ParchmentSurface(radius: radius))
    }

    func navySurface(radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(NavySurface(radius: radius))
    }

    func sharedIPadGlass(
        role: SharedIPadGlassRole,
        radius: CGFloat = WayfolioMetrics.panelRadius
    ) -> some View {
        modifier(SharedIPadGlassSurface(role: role, radius: radius))
    }
}
