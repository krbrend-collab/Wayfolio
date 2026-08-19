import SwiftUI

struct MorePlaceholderView: View {
    private let modules = ["Character", "Inventory", "Crafting", "Companions", "Quests", "Settings"]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
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
