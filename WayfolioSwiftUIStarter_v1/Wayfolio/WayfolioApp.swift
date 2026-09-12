import SwiftUI
import SwiftData

@main
struct WayfolioApp: App {
    @StateObject private var presentation = PresentationRuntime()
    @StateObject private var gameSession = GameSessionClient()
    @StateObject private var characterImages = CharacterImageStore()

    var body: some Scene {
        WindowGroup {
            WayfolioRootView()
                .environmentObject(presentation)
                .environmentObject(presentation.audio)
                .environmentObject(gameSession)
                .environmentObject(characterImages)
                .task {
                    gameSession.presentationEventHandler = { event in
                        presentation.handle(event)
                    }
                    gameSession.presentationStateHandler = { state in
                        presentation.restore(state)
                    }
                }
                .onOpenURL { gameSession.handleJoinLink($0) }
        }
        .modelContainer(for: CreatureRecord.self)
    }
}
