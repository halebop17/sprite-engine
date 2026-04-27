import SwiftUI

/// Sheet that drives a bulk artwork scrape across the library.
/// Shows per-game status and a running progress counter. Closing the sheet
/// does not stop the queue — work continues in the background.
struct ArtworkScrapeView: View {

    let games: [Game]
    let onClose: () -> Void

    @EnvironmentObject private var library: ROMLibrary
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var service = ArtworkService.shared
    @Environment(\.appTheme) private var t

    @State private var force = false

    private var doneCount: Int {
        games.filter { service.status(for: $0.id) == .done || $0.hasArtwork }.count
    }

    private var notFoundCount: Int {
        games.filter { service.status(for: $0.id) == .notFound }.count
    }

    private var errorCount: Int {
        games.filter {
            if case .error = service.status(for: $0.id) { return true } else { return false }
        }.count
    }

    private var inFlightCount: Int { service.inFlight.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(t.divider)
            controls
            Divider().background(t.divider)
            list
        }
        .frame(minWidth: 540, minHeight: 540)
        .background(t.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Fetch Artwork")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(t.text)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(t.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(t.toolbar)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(progressText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(t.text)
                Text(detailText)
                    .font(.system(size: 11))
                    .foregroundColor(t.textMuted)
            }
            Spacer()
            Toggle(isOn: $force) {
                Text("Re-scrape existing")
                    .font(.system(size: 11))
                    .foregroundColor(t.textMuted)
            }
            .toggleStyle(.checkbox)
            Button(action: startScrape) {
                HStack(spacing: 6) {
                    if inFlightCount > 0 {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        Text("Scraping…")
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text(force ? "Re-scrape All" : "Scrape Missing")
                    }
                    Text("(\(targetCount))")
                        .foregroundColor(t.textMuted)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(LinearGradient(colors: [t.playBtnStart, t.playBtnEnd],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(inFlightCount > 0 || targetCount == 0)
            if inFlightCount > 0 {
                Button("Stop") { service.cancelBulk() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(t.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(t.cardBorder, lineWidth: 1))
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var progressText: String {
        if inFlightCount > 0 {
            return "Scraping \(doneCount)/\(games.count) — \(inFlightCount) in flight"
        }
        if doneCount == games.count, !games.isEmpty {
            return "All \(games.count) games have artwork"
        }
        return "\(doneCount)/\(games.count) games have artwork"
    }

    private var detailText: String {
        var parts: [String] = []
        if notFoundCount > 0 { parts.append("\(notFoundCount) not found") }
        if errorCount > 0    { parts.append("\(errorCount) errors") }
        if appState.screenScraperUsername.isEmpty {
            parts.append("Set credentials in Settings → Scraping")
        }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

    private var targetCount: Int {
        force ? games.count : games.filter { !$0.hasArtwork }.count
    }

    private func startScrape() {
        service.scrapeMany(games, library: library, force: force)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(games) { game in
                    ArtworkScrapeRow(game: game, status: service.status(for: game.id))
                    Divider().background(t.divider).padding(.leading, 56)
                }
            }
        }
    }
}

private struct ArtworkScrapeRow: View {
    let game: Game
    let status: ArtworkService.Status
    @Environment(\.appTheme) private var t

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(game.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(t.text)
                    .lineLimit(1)
                Text(statusLabel)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
            }
            Spacer()
            Text(game.system.shortName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(t.tagText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(t.tag)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .scraping:
            ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
        case .notFound:
            Image(systemName: "questionmark.circle").foregroundColor(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
        case .skipped:
            Image(systemName: "hand.raised.fill").foregroundColor(t.textFaint)
        case .idle:
            if game.hasArtwork {
                Image(systemName: "checkmark.circle").foregroundColor(.green.opacity(0.6))
            } else {
                Image(systemName: "circle").foregroundColor(t.textFaint)
            }
        }
    }

    private var statusLabel: String {
        switch status {
        case .done:           return "Saved"
        case .scraping:       return "Scraping…"
        case .notFound:       return "No match on ScreenScraper"
        case .error(let msg): return msg
        case .skipped:        return "Manual cover — skipped"
        case .idle:           return game.hasArtwork ? "Already saved" : "Pending"
        }
    }

    private var statusColor: Color {
        switch status {
        case .done:           return .green
        case .scraping:       return t.accent
        case .notFound:       return .orange
        case .error:          return .red
        case .skipped:        return t.textMuted
        case .idle:           return t.textMuted
        }
    }
}
