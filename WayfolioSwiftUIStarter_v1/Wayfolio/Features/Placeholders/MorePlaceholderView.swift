import SwiftUI
import SpriteKit

struct MorePlaceholderView: View {
    private let modules = ["Character", "Inventory", "Crafting", "Companions", "Quests", "Settings"]
    @State private var showsAnimationLab = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        showsAnimationLab.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg.rectangle")
                            .foregroundStyle(WayfolioPalette.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Animation Lab")
                                .font(WayfolioTypography.headline)
                                .foregroundStyle(WayfolioPalette.ink)
                            Text("Pufftail Fox · native SpriteKit mesh prototype")
                                .font(WayfolioTypography.body)
                                .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
                        }
                        Spacer()
                        Image(systemName: showsAnimationLab ? "chevron.up" : "chevron.down")
                            .foregroundStyle(WayfolioPalette.ink.opacity(0.5))
                    }
                    .padding(14)
                    .parchmentSurface(radius: WayfolioMetrics.cardRadius)
                }
                .buttonStyle(.plain)

                if showsAnimationLab {
                    PufftailSpriteKitPrototypeView()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ForEach(modules, id: \.self) { module in
                    HStack {
                        Text(module)
                            .font(WayfolioTypography.headline)
                            .foregroundStyle(WayfolioPalette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(WayfolioPalette.ink.opacity(0.5))
                    }
                    .padding(14)
                    .parchmentSurface(radius: WayfolioMetrics.cardRadius)
                }
            }
            .padding(WayfolioMetrics.contentInset)
        }
        .scrollIndicators(.hidden)
    }
}

struct PufftailSpriteKitPrototypeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = PufftailSpriteKitScene(size: CGSize(width: 720, height: 720))
    @State private var motionIntensity = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: WayfolioMetrics.cardRadius, style: .continuous)
                    .fill(WayfolioPalette.paper.opacity(0.78))

                SpriteView(
                    scene: scene,
                    preferredFramesPerSecond: 60,
                    options: [.allowsTransparency, .shouldCullNonVisibleNodes]
                )
                .clipShape(RoundedRectangle(cornerRadius: WayfolioMetrics.cardRadius, style: .continuous))
            }
            .frame(height: 360)
            .overlay {
                RoundedRectangle(cornerRadius: WayfolioMetrics.cardRadius, style: .continuous)
                    .stroke(WayfolioPalette.ink.opacity(0.12), lineWidth: 1)
            }

            HStack {
                Text("Motion")
                    .font(WayfolioTypography.body)
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.75))
                Slider(value: $motionIntensity, in: 0.4...1.6, step: 0.1)
                Text(String(format: "%.1f×", motionIntensity))
                    .font(WayfolioTypography.body.monospacedDigit())
                    .foregroundStyle(WayfolioPalette.ink.opacity(0.65))
                    .frame(width: 44, alignment: .trailing)
            }

            Text("One continuous sprite is deformed by a native 12×12 SpriteKit warp grid. Feet, cheeks, and face stay pinned; the ears, tail, and upper chest receive controlled movement. No prerecorded video and no generative-video credits are used.")
                .font(WayfolioTypography.body)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
        }
        .padding(14)
        .parchmentSurface(radius: WayfolioMetrics.cardRadius)
        .onAppear {
            updateSceneIntensity()
        }
        .onChange(of: motionIntensity) { _ in
            updateSceneIntensity()
        }
        .onChange(of: reduceMotion) { _ in
            updateSceneIntensity()
        }
    }

    private func updateSceneIntensity() {
        scene.motionIntensity = reduceMotion ? 0.18 : Float(motionIntensity)
    }
}

final class PufftailSpriteKitScene: SKScene {
    var motionIntensity: Float = 1

    private let columns = 12
    private let rows = 12
    private let creature = SKSpriteNode(texture: SKTexture(imageNamed: "pufftail-fox-rig"))
    private lazy var identityGrid = SKWarpGeometryGrid(columns: columns, rows: rows)
    private lazy var sourcePositions: [SIMD2<Float>] = {
        (0..<identityGrid.vertexCount).map { identityGrid.sourcePosition(at: $0) }
    }()
    private var startTime: TimeInterval?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        configureCreature()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = .clear
        configureCreature()
    }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
        layoutCreature()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutCreature()
    }

    override func update(_ currentTime: TimeInterval) {
        if startTime == nil { startTime = currentTime }
        guard let startTime else { return }
        creature.warpGeometry = warp(at: Float(currentTime - startTime))
    }

    private func configureCreature() {
        creature.texture?.filteringMode = .linear
        creature.anchorPoint = CGPoint(x: 0.5, y: 0)
        creature.warpGeometry = identityGrid
        addChild(creature)
    }

    private func layoutCreature() {
        guard let texture = creature.texture else { return }
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return }

        // Deliberately leave generous motion-safe margins for tall ears and the large tail.
        let availableWidth = size.width * 0.70
        let availableHeight = size.height * 0.78
        let scale = min(availableWidth / textureSize.width, availableHeight / textureSize.height)
        creature.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        creature.position = CGPoint(x: size.width * 0.5, y: size.height * 0.08)
    }

    private func warp(at time: Float) -> SKWarpGeometryGrid {
        let intensity = motionIntensity
        let tailWave = sin(time * 2 * .pi / 6.2) * intensity
        let breath = sin(time * 2 * .pi / 4.0) * intensity
        let leftEar = (-0.9 * pulse(time, center: 1.55, width: 0.16)
                       + 0.35 * pulse(time, center: 5.85, width: 0.14)) * intensity
        let rightEar = (0.55 * pulse(time, center: 1.72, width: 0.15)
                        - 0.7 * pulse(time, center: 5.58, width: 0.15)) * intensity

        var destination = sourcePositions

        for index in destination.indices {
            let source = sourcePositions[index]
            let x = source.x
            let y = source.y
            var point = source

            // Face protection: this keeps the muzzle, cheeks, and eye region essentially rigid.
            let faceProtection = gaussian(x: x, y: y, cx: 0.30, cy: 0.58, rx: 0.25, ry: 0.20)

            // Feet / lower legs are a hard stability region.
            let lowerBodyPin = 1 - smoothstep(0.20, 0.34, y)

            // Tail: influence begins at the root and grows toward the outer mass/tip.
            let tailX = smoothstep(0.50, 0.96, x)
            let tailY = smoothstep(0.20, 0.34, y) * (1 - smoothstep(0.86, 0.98, y))
            let tailInfluence = tailX * tailX * tailY * (1 - faceProtection) * (1 - lowerBodyPin)
            point.x += tailWave * 0.020 * tailInfluence
            point.y += tailWave * 0.011 * tailInfluence

            // Left and right ears bend only above their bases; the head itself stays stable.
            let earHeight = smoothstep(0.70, 0.98, y)
            let leftEarBand = band(x, low: 0.02, high: 0.31, feather: 0.08) * earHeight
            let rightEarBand = band(x, low: 0.30, high: 0.56, feather: 0.08) * earHeight
            point.x += leftEar * 0.018 * leftEarBand
            point.x += rightEar * 0.018 * rightEarBand
            point.y += abs(leftEar) * 0.004 * leftEarBand
            point.y += abs(rightEar) * 0.004 * rightEarBand

            // Breathing: upper chest only. The face and all paws remain fixed.
            let chest = gaussian(x: x, y: y, cx: 0.34, cy: 0.40, rx: 0.22, ry: 0.13)
                * smoothstep(0.27, 0.37, y)
                * (1 - smoothstep(0.54, 0.66, y))
                * (1 - faceProtection)
            point.y += breath * 0.009 * chest
            point.x += (x < 0.34 ? -1 : 1) * breath * 0.0025 * chest

            // Never allow the live warp to reach the image edges. This protects against clipping.
            point.x = min(max(point.x, 0.025), 0.975)
            point.y = min(max(point.y, 0.025), 0.975)
            destination[index] = point
        }

        return SKWarpGeometryGrid(
            columns: columns,
            rows: rows,
            sourcePositions: sourcePositions,
            destinationPositions: destination
        )
    }

    private func smoothstep(_ low: Float, _ high: Float, _ value: Float) -> Float {
        let t = min(max((value - low) / max(high - low, 0.0001), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func band(_ value: Float, low: Float, high: Float, feather: Float) -> Float {
        smoothstep(low, low + feather, value) * (1 - smoothstep(high - feather, high, value))
    }

    private func gaussian(x: Float, y: Float, cx: Float, cy: Float, rx: Float, ry: Float) -> Float {
        let dx = (x - cx) / rx
        let dy = (y - cy) / ry
        return exp(-(dx * dx + dy * dy) * 2.4)
    }

    private func pulse(_ time: Float, center: Float, width: Float) -> Float {
        let distance = abs(time.truncatingRemainder(dividingBy: 7) - center)
        guard distance < width else { return 0 }
        return sin((1 - distance / width) * .pi)
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