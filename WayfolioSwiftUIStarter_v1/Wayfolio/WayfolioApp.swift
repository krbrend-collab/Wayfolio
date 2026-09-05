import SwiftUI
import SwiftData

@MainActor
final class WayfolioSessionContext: ObservableObject {
    @Published var backgroundAssetName: String = "hemlock-map"
    @Published var playerName: String = "Kevin Brend"
    @Published var deviceName: String = "Wayfolio iPhone"
    @Published var checkpointTitle: String = "Morning Before Departure"
    @Published var checkpointDetail: String = "Renn is prepared to leave Hemlock and begin the journey."
    @Published var locationTitle: String = "Central Commons"
    @Published var locationSubtitle: String = "Hemlock Village"

    /// The campaign/Bridge layer should call this whenever the current visual location changes.
    /// The login screen and gameplay shell both read the same value, so the environment is never baked into UI artwork.
    func setBackgroundAsset(_ assetName: String) {
        backgroundAssetName = assetName
    }
}

@main
struct WayfolioApp: App {
    @StateObject private var session = WayfolioSessionContext()

    var body: some Scene {
        WindowGroup {
            WayfolioRootView()
                .environmentObject(session)
        }
        .modelContainer(for: CreatureRecord.self)
    }
}
