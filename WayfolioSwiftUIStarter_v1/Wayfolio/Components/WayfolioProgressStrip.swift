import SwiftUI

struct WayfolioProgressStrip: View {
    let value: Double
    var showLabel = true

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel {
                HStack {
                    Text("Entry Completion")
                    Spacer()
                    Text(clamped, format: .percent.precision(.fractionLength(0)))
                }
                .font(WayfolioTypography.caption)
                .foregroundStyle(WayfolioPalette.ink.opacity(0.82))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(WayfolioPalette.midnight.opacity(0.7))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [WayfolioPalette.cyan, WayfolioPalette.violet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }
}
