import SwiftUI

@main
struct SpriteEngineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var library  = ROMLibrary.shared
    @StateObject private var conversionQueue = ConversionQueue()

    var body: some Scene {
        WindowGroup("Sprite Engine") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(library)
                .environmentObject(conversionQueue)
        }
        .defaultSize(width: 1140, height: 710)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Library") {
                Button("Import ROMs…") {
                    appState.navigate(to: .`import`)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Settings") {
                    appState.navigate(to: .settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
