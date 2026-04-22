import SwiftUI
import MetalKit
import AppKit
import UniformTypeIdentifiers

// MARK: - Navigation root

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.screen {
            case .library:
                LibraryView()
            case .detail(let game):
                DetailView(game: game)
            case .`import`:
                ImportView()
            case .settings:
                SettingsView()
            case .emulator(let game):
                EmulatorWindowView(game: game)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .environment(\.appTheme, appState.currentTheme)
    }
}
