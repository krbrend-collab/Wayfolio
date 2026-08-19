import SwiftUI

struct MapPlaceholderView: View {
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hemlock Village")
                        .font(WayfolioTypography.headline)
                        .foregroundStyle(WayfolioPalette.ink)
                    Text("Pinch to zoom • drag to explore")
                        .font(WayfolioTypography.caption)
                        .foregroundStyle(WayfolioPalette.ink.opacity(0.62))
                }
                Spacer()
                Button("Reset", action: resetMap)
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(WayfolioPalette.brass.opacity(0.35)))
            }
            .padding(12)
            .parchmentSurface(radius: 14)

            GeometryReader { proxy in
                Image("hemlock-map")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)
                    .clipped()
                    .background(WayfolioPalette.midnight)
            }
            .clipShape(RoundedRectangle(cornerRadius: WayfolioMetrics.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WayfolioMetrics.panelRadius, style: .continuous)
                    .stroke(WayfolioPalette.brass.opacity(0.78), lineWidth: 1.2)
            }
            .overlay(alignment: .bottomLeading) {
                Label("Hemlock Region", systemImage: "location.fill")
                    .font(WayfolioTypography.caption)
                    .foregroundStyle(WayfolioPalette.parchment)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
        .padding(.horizontal, WayfolioMetrics.contentInset)
        .padding(.bottom, 14)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 { resetMap() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetMap() {
        withAnimation(.snappy(duration: 0.25)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }
}
