import SwiftUI

@main
struct SpriteEngineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Sprite Engine") {
            ContentView()
        }
        .defaultSize(width: 1140, height: 710)
        .windowResizability(.contentSize)
    }
}
