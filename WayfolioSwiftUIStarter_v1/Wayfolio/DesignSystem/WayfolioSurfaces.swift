import SwiftUI

enum WayfolioSurfaceAsset: String, CaseIterable {
    case woodNeutral = "BG_Fallback_Wood_Neutral_V02"
    case stoneNeutral = "BG_Fallback_Stone_Neutral_V02"
    case forestFloorNeutral = "BG_Fallback_Forest_Floor_Neutral_V02"
    case clothInteriorNeutral = "BG_Fallback_Cloth_Interior_Neutral_V02"
    case metalWorkbenchNeutral = "BG_Fallback_Metal_Workbench_Neutral_V02"
    case notebookCoverNavyCloth = "BG_Fallback_Notebook_Cover_Navy_Cloth_V01"
    case leatherBrownWorn = "BG_Fallback_Leather_Brown_Worn_V01"
    case parchmentAged = "BG_Fallback_Parchment_Aged_V01"
    case sandWarm = "BG_Terrain_Sand_Warm_Desert_V01"
    case waterShallowClear = "BG_Terrain_Water_Shallow_Clear_V01"
    case snowFrosted = "BG_Terrain_Snow_Frosted_Blue_V01"
    case mudWet = "BG_Terrain_Mud_Wet_Earth_V01"
    case mossLush = "BG_Terrain_Moss_Lush_Forest_V01"
    case grassMeadow = "BG_Terrain_Grass_Sunlit_Meadow_V01"
    case fernsUnderstory = "BG_Terrain_Ferns_Forest_Understory_V01"
    case riverbedPebblesWet = "BG_Terrain_Pebbles_Wet_Riverbed_V01"
    case marshMisty = "BG_Terrain_Marsh_Misty_Wetland_V01"
    case cloverMeadow = "BG_Terrain_Clover_Lush_Meadow_V01"
    case builtWoodGoldenOak = "BG_Built_Wood_Rustic_Golden_Oak_V01"
    case builtTextileIndigoPlaid = "BG_Built_Textile_Indigo_Woven_Plaid_V01"
    case builtStonePavingBeige = "BG_Built_Stone_Paving_Weathered_Beige_V01"
    case builtTerracottaTile = "BG_Built_Terracotta_Tile_Mediterranean_V01"
    case pathCobblestoneMosaic = "BG_Path_Cobblestone_Mosaic_Weathered_V01"
    case pathGravelPale = "BG_Path_Gravel_Pale_Pebble_V01"
    case pathTerracottaBrick = "BG_Path_Terracotta_Brick_Weathered_V01"
    case pathCobblestoneRustic = "BG_Path_Cobblestone_Rustic_Earth_Toned_V01"

    var catalogName: String { rawValue }
}

enum ProjectionPaneVariant {
    case info, compact, detail, alert, list, media, map, featureGrid, settings, dialogue

    var tintOpacity: Double {
        switch self {
        case .compact: 0.08
        case .info, .list, .featureGrid: 0.10
        case .media, .map: 0.07
        case .detail, .settings, .dialogue, .alert: 0.18
        }
    }

    var edgeColor: Color {
        switch self {
        case .alert: WayfolioPalette.magenta
        case .compact, .featureGrid: WayfolioPalette.brass
        case .info, .detail, .list, .media, .map, .settings, .dialogue: WayfolioPalette.cyan
        }
    }

    var readabilityScrimOpacity: Double {
        switch self {
        case .dialogue: 0.72
        default: 0
        }
    }
}

struct EnvironmentalBackgroundLayer: View {
    let sceneTitle: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("hemlock-environment")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .transition(.opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: sceneTitle)
            .overlay {
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.07)],
                    center: .center,
                    startRadius: 170,
                    endRadius: 620
                )
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

struct ProjectedCanvasFrame: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(WayfolioPalette.cyan.opacity(0.76), lineWidth: 1.15)
                .shadow(color: WayfolioPalette.cyan.opacity(0.42), radius: 8)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [WayfolioPalette.brassBright.opacity(0.78), WayfolioPalette.cyan.opacity(0.18), WayfolioPalette.brass.opacity(0.66)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 0.9, dash: [32, 7, 5, 9])
                )
                .padding(4)

            ForEach(0..<4, id: \.self) { index in
                GeometryReader { proxy in
                    Circle()
                        .fill(WayfolioPalette.cyan)
                        .frame(width: 5, height: 5)
                        .shadow(color: WayfolioPalette.cyan, radius: 5)
                        .position(
                            x: index.isMultiple(of: 2) ? 13 : proxy.size.width - 13,
                            y: index < 2 ? 15 : proxy.size.height - 15
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ProjectionPane: ViewModifier {
    let variant: ProjectionPaneVariant
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(WayfolioPalette.midnight.opacity(variant.readabilityScrimOpacity))
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                        LinearGradient(
                            colors: [
                                Wayfolio.violetGlass,
                                WayfolioPalette.midnight.opacity(variant.tintOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        )
                }
            )
            .background(.ultraThinMaterial.opacity(0.22), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [variant.edgeColor.opacity(0.52), variant.edgeColor.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.12), radius: 7, y: 3)
            .shadow(color: variant.edgeColor.opacity(0.13), radius: 10)
    }
}

private enum Wayfolio {
    static let violetGlass = Color(red: 0.24, green: 0.30, blue: 0.58).opacity(0.10)
}

struct ParchmentSurface: ViewModifier {
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WayfolioPalette.cyan.opacity(0.12),
                                WayfolioPalette.navy.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(.ultraThinMaterial.opacity(0.22), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [WayfolioPalette.cyan.opacity(0.50), WayfolioPalette.brass.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: WayfolioPalette.cyan.opacity(0.15), radius: 12)
            .shadow(color: Color.black.opacity(0.16), radius: 8, y: 4)
    }
}

struct NavySurface: ViewModifier {
    var radius: CGFloat = WayfolioMetrics.panelRadius

    func body(content: Content) -> some View {
        content.modifier(ProjectionPane(variant: .detail, radius: radius))
    }
}

struct WayfolioChromeSurface: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .background(.ultraThinMaterial, in: shape)
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [
                            WayfolioPalette.navy.opacity(0.24),
                            WayfolioPalette.midnight.opacity(0.20),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            WayfolioPalette.cyan.opacity(0.36),
                            WayfolioPalette.brass.opacity(0.30),
                            WayfolioPalette.cyan.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
            }
            .shadow(color: Color.black.opacity(0.38), radius: 14, y: 7)
            .shadow(color: WayfolioPalette.cyan.opacity(0.10), radius: 10)
    }
}

extension View {
    func parchmentSurface(radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(ParchmentSurface(radius: radius))
    }

    func navySurface(radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(NavySurface(radius: radius))
    }

    func projectionPane(_ variant: ProjectionPaneVariant = .info, radius: CGFloat = WayfolioMetrics.panelRadius) -> some View {
        modifier(ProjectionPane(variant: variant, radius: radius))
    }

    func wayfolioChromeSurface(radius: CGFloat) -> some View {
        modifier(WayfolioChromeSurface(radius: radius))
    }
}
