import SwiftUI
import SwiftData

@main
struct WayfolioApp: App {
    var body: some Scene {
        WindowGroup {
            WayfolioRootView()
        }
        .modelContainer(for: [CreatureRecord.self, CreatureDiscoveryRecord.self])
    }
}
