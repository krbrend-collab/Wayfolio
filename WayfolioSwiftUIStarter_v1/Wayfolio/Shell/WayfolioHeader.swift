import SwiftUI

struct WayfolioHeader: View {
    @EnvironmentObject private var session: GameSessionClient
    let canGoBack: Bool
    let onBack: () -> Void
    let onOpenProfile: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scale = width / 440
            let runtimeY = 77 * scale

            ZStack(alignment: .topLeading) {
                Color.black

                Rectangle()
                    .fill(WayfolioPalette.cyan.opacity(0.20))
                    .frame(width: width, height: 18 * scale)
                    .blur(radius: 14 * scale)
                    .offset(y: 100 * scale)
                    .allowsHitTesting(false)

                Image("wayfolio-topbar-approved")
                    .resizable()
                    .aspectRatio(3, contentMode: .fit)
                    .frame(width: width, alignment: .top)
                    .accessibilityHidden(true)

                connectionOrBackControl
                    .frame(width: 44, height: 44)
                    .position(x: 24, y: runtimeY)

                Text(session.character?.name ?? session.playerName)
                    .font(.custom("EBGaramond-Regular", size: max(8.5, 10 * scale), relativeTo: .caption2))
                    .foregroundStyle(runtimeInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: width * 0.28, alignment: .leading)
                    .position(x: width * 0.25, y: runtimeY)

                Circle()
                    .fill(WayfolioPalette.cyan)
                    .frame(width: max(4, 5 * scale), height: max(4, 5 * scale))
                    .shadow(color: WayfolioPalette.cyan.opacity(0.72), radius: 4)
                    .position(x: width * 0.5, y: runtimeY)
                    .accessibilityHidden(true)

                HStack(spacing: 4 * scale) {
                    Label(displayWeather, systemImage: "sun.max.fill")
                    Text("·")
                    Label(displayTime, systemImage: "clock.fill")
                }
                .font(.custom("EBGaramond-Regular", size: max(8.5, 10 * scale), relativeTo: .caption2))
                .foregroundStyle(runtimeInk)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(width: width * 0.31, alignment: .trailing)
                .position(x: width * 0.749, y: runtimeY)
            }
        }
        .aspectRatio(3, contentMode: .fit)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var connectionOrBackControl: some View {
        if canGoBack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(runtimeInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
        } else {
            Button(action: onOpenProfile) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: connectionColor.opacity(0.72), radius: 4)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Connection status")
            .accessibilityValue(connectionLabel)
            .accessibilityHint("Opens Wayfolio connection settings")
        }
    }

    private var runtimeInk: Color {
        Color(red: 0.94, green: 0.84, blue: 0.61).opacity(0.95)
    }

    private var connectionLabel: String {
        switch session.state {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        case .failed: "Connection needs attention"
        }
    }

    private var connectionColor: Color {
        switch session.state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected, .failed: .red
        }
    }

    private var displayWeather: String {
        session.weather?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Weather unknown"
    }

    private var displayTime: String {
        session.timeOfDay?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Time unknown"
    }
}
