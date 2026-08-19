import SwiftUI
import SwiftData

@main
struct WayfolioApp: App {
    @StateObject private var presentation = PresentationRuntime()

    var body: some Scene {
        WindowGroup {
            WayfolioRootView()
                .environmentObject(presentation.audio)
                .task { presentation.connectConfiguredEndpoint() }
        }
        .modelContainer(for: CreatureRecord.self)
    }
}
