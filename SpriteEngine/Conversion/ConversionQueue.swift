import Foundation

enum ConversionState {
    case pending
    case converting(progress: Double)
    case done(outputURL: URL)
    case failed(error: Error)

    var isFinished: Bool {
        switch self { case .done, .failed: return true; default: return false }
    }

    var isPending: Bool {
        if case .pending = self { return true }; return false
    }
}

struct ConversionItem: Identifiable {
    let id   = UUID()
    let zipURL: URL
    var state: ConversionState = .pending

    var title: String {
        zipURL.deletingPathExtension().lastPathComponent.uppercased()
    }
}

@MainActor
final class ConversionQueue: ObservableObject {

    @Published private(set) var items: [ConversionItem] = []
    @Published private(set) var isRunning = false

    private let converter = NeoConverter()

    // Enqueue one or more zip URLs. Starts processing automatically.
    func enqueue(_ urls: [URL]) {
        let deduplicated = urls.filter { url in
            !items.contains { $0.zipURL == url }
        }
        items.append(contentsOf: deduplicated.map { ConversionItem(zipURL: $0) })
        if !isRunning { Task { await processNext() } }
    }

    func clearFinished() {
        items.removeAll { $0.state.isFinished }
    }

    // MARK: - Private

    private func processNext() async {
        guard let idx = items.firstIndex(where: { $0.state.isPending }) else {
            isRunning = false
            return
        }

        isRunning = true
        items[idx].state = .converting(progress: 0)

        let zipURL = items[idx].zipURL

        do {
            let outputURL = try await converter.convert(zipURL: zipURL) { [weak self] p in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self,
                          let i = self.items.firstIndex(where: { $0.zipURL == zipURL })
                    else { return }
                    self.items[i].state = .converting(progress: p)
                }
            }
            if let i = items.firstIndex(where: { $0.zipURL == zipURL }) {
                items[i].state = .done(outputURL: outputURL)
            }
        } catch {
            if let i = items.firstIndex(where: { $0.zipURL == zipURL }) {
                items[i].state = .failed(error: error)
            }
        }

        await processNext()
    }
}
