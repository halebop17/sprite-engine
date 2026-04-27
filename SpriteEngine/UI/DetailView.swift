import SwiftUI

struct DetailView: View {

    let game: Game

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @Environment(\.appTheme) private var t

    @State private var isFavorite: Bool
    @State private var tab: DetailTab = .info
    @State private var noteText: String
    @State private var editingNote = false

    // Lightbox + scrape
    @State private var coverLightboxImage: NSImage?
    @State private var lightboxIndex: Int = 0
    @State private var isFetchingArtwork = false
    @State private var fetchArtworkError: String?
    @State private var showNameOverride = false
    @State private var arrowKeyMonitor: Any?
    @ObservedObject private var artworkService = ArtworkService.shared

    enum DetailTab { case info, notes, media, saveStates }

    init(game: Game) {
        self.game = game
        _isFavorite = State(initialValue: game.isFavorite)
        _noteText = State(initialValue:
            UserDefaults.standard.string(forKey: "gameNote_\(game.id.uuidString)") ?? "")
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
            mainContent
        }
        .background(t.surface)
        .overlay(alignment: .bottomLeading) {
            navArrowButton(direction: .previous)
                .padding(.leading, 18)
                .padding(.bottom, 18)
        }
        .overlay(alignment: .bottomTrailing) {
            navArrowButton(direction: .next)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
        .overlay {
            if let img = coverLightboxImage {
                ImageLightboxView(
                    images: [img],
                    index: $lightboxIndex,
                    onDismiss: { coverLightboxImage = nil }
                )
            }
        }
        .onAppear { installArrowKeyMonitor() }
        .onDisappear { removeArrowKeyMonitor() }
        .sheet(isPresented: $showNameOverride) {
            NameOverrideSheet(
                game: liveGame,
                onSave: { override in
                    library.setScrapeNameOverride(liveGame.id, override)
                    showNameOverride = false
                    fetchArtwork()
                },
                onCancel: { showNameOverride = false }
            )
            .environment(\.appTheme, t)
        }
    }

    // MARK: - Left sidebar (220px art + stats)

    private var sidebarColumn: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button {
                    coverLightboxImage = liveCoverImage
                } label: {
                    GameCoverView(game: liveGame, size: 308)
                        .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(t.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(liveCoverImage == nil)

                if let marquee = ArtworkCache.marquee(for: liveGame.id) {
                    Image(nsImage: marquee)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 308)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(t.cardBorder, lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }

                statsCard
                if let result = library.verificationResults[liveGame.id], !result.status.isOK {
                    romIssuesCard(result)
                }
            }
            .padding(26)
        }
        .frame(width: 360)
        .background(t.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(t.sidebarBorder).frame(width: 1)
        }
    }

    /// Snapshot from navigation; for fields that can mutate (artwork download,
    /// favorites, save states) we look up the latest by id.
    private var liveGame: Game {
        library.games.first(where: { $0.id == game.id }) ?? game
    }

    private var liveCoverImage: NSImage? {
        guard liveGame.hasArtwork else { return nil }
        return ArtworkCache.boxArt(for: liveGame.id)
    }

    @ViewBuilder
    private func romIssuesCard(_ result: GameVerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.0))
                Text(result.status == .unknownGame ? "UNKNOWN GAME" : "ROM ISSUES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if result.status != .unknownGame {
                Divider().background(t.divider)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(result.files.filter { !$0.status.isOK }) { file in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: fileIcon(file.status))
                                .font(.system(size: 9))
                                .foregroundColor(fileColor(file.status))
                                .frame(width: 12)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.name)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(t.text)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(fileLabel(file.status))
                                    .font(.system(size: 9))
                                    .foregroundColor(fileColor(file.status))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        Divider().background(t.divider).padding(.leading, 34)
                    }
                }
            } else {
                Divider().background(t.divider)
                Text("This zip was not recognised by the FBNeo driver list. The ROM may be unsupported or incorrectly named.")
                    .font(.system(size: 10))
                    .foregroundColor(t.textMuted)
                    .padding(14)
            }
        }
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(red: 1.0, green: 0.62, blue: 0.0).opacity(0.35), lineWidth: 1))
    }

    private func fileIcon(_ status: ROMFileStatus) -> String {
        switch status {
        case .missing:  return "xmark.circle.fill"
        case .wrongCRC: return "exclamationmark.triangle.fill"
        default:        return "checkmark.circle.fill"
        }
    }

    private func fileColor(_ status: ROMFileStatus) -> Color {
        switch status {
        case .missing:  return .red
        case .wrongCRC: return Color(red: 1.0, green: 0.62, blue: 0.0)
        default:        return .green
        }
    }

    private func fileLabel(_ status: ROMFileStatus) -> String {
        switch status {
        case .missing:               return "Missing"
        case .wrongCRC(let e, let a):return "CRC \(String(e, radix: 16, uppercase: true)) ≠ \(String(a, radix: 16, uppercase: true))"
        default:                     return ""
        }
    }

    private var statsCard: some View {
        VStack(spacing: 8) {
            ForEach(stats, id: \.label) { stat in
                HStack(alignment: .firstTextBaseline) {
                    Text(stat.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(t.textFaint)
                        .kerning(0.5)
                        .textCase(.uppercase)
                    Spacer(minLength: 8)
                    Text(stat.value)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(t.text)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(t.cardBorder, lineWidth: 1))
    }

    private var stats: [(label: String, value: String)] {
        [
            ("Last Played", game.lastPlayed.map { formatted($0) } ?? "Never"),
            ("Save States", "\(game.saveStates.count)"),
            ("System",      game.system.rawValue),
            ("ROM",         game.romURL.lastPathComponent),
        ]
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(t.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    tabStrip
                    tabContent
                }
                .padding(26)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            BackButton()
            Spacer()
            // Fetch Artwork
            Button(action: fetchArtwork) {
                HStack(spacing: 6) {
                    if isFetchingArtwork {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 12))
                    }
                    Text(liveGame.hasArtwork ? "Refresh Artwork" : "Fetch Artwork")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(t.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(t.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isFetchingArtwork)
            .help(fetchArtworkError ?? "Download box art, wheel, marquee from ScreenScraper")
            // Set Cover…
            Menu {
                Button("Set Cover Image…", action: pickCoverImage)
                Divider()
                Button(liveGame.scrapeNameOverride == nil
                       ? "Set Name Override…"
                       : "Edit Name Override (\"\(liveGame.scrapeNameOverride!)\")…") {
                    showNameOverride = true
                }
                if liveGame.hasArtwork {
                    Divider()
                    Button("Clear Artwork", role: .destructive, action: clearArtwork)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundColor(t.text)
                    .frame(width: 36, height: 36)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(t.cardBorder, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 36, height: 36)
            // Favorite
            Button {
                isFavorite.toggle()
                library.setFavorite(game, isFavorite)
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundColor(isFavorite ? t.accent : t.text)
                    .frame(width: 36, height: 36)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(isFavorite ? t.accent : t.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            // Play Now
            Button { appState.navigate(to: .emulator(game)) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text("Play Now").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(LinearGradient(
                    colors: [t.playBtnStart, t.playBtnEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(color: t.accent.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(t.toolbar)
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(game.system.shortGenre.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(t.tagText)
                .kerning(1.0)

            Text(game.title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(t.text)
                .lineLimit(2)

            Text(game.system.rawValue)
                .font(.system(size: 13))
                .foregroundColor(t.textMuted)
        }
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: 4) {
            TabButton(label: "Info",        tab: .info,       active: tab) { tab = $0 }
            TabButton(label: "Notes",       tab: .notes,      active: tab) { tab = $0 }
            TabButton(label: "Media",       tab: .media,      active: tab) { tab = $0 }
            TabButton(label: "Save States", tab: .saveStates, active: tab) { tab = $0 }
        }
        .padding(5)
        .background(t.systemTabsBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(t.divider, lineWidth: 1))
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .info:       infoTab
        case .notes:      notesTab
        case .media:      MediaTabView(game: game)
        case .saveStates: saveStatesTab
        }
    }

    private var infoTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tags row
            HStack(spacing: 6) {
                ForEach([game.system.shortGenre, game.system.rawValue], id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(t.tagText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(t.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(t.accent.opacity(0.13), lineWidth: 1))
                }
            }
            // System card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(game.system.badgeColor.opacity(0.15))
                        .frame(width: 54, height: 44)
                    Image(game.system.logoAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 46, height: 36)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.system.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(t.text)
                    Text(game.system.hardwareDescription)
                        .font(.system(size: 11))
                        .foregroundColor(t.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(t.cardBorder, lineWidth: 1))
            // Description
            Text(game.system.systemBlurb(title: game.title))
                .font(.system(size: 13))
                .foregroundColor(t.textMuted)
                .lineSpacing(4)
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(t.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Save States tab

    private var saveStatesTab: some View {
        // Read fresh from library — `game` is a value snapshot from navigation
        // and won't reflect mutations like delete/add.
        let liveGame = library.games.first(where: { $0.id == game.id }) ?? game
        let states = liveGame.saveStates.sorted { $0.createdAt > $1.createdAt }
        return Group {
            if states.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(t.textFaint)
                    Text("No save states yet")
                        .font(.system(size: 13))
                        .foregroundColor(t.textMuted)
                    Text("Press ⌘S while playing to create one.")
                        .font(.system(size: 11))
                        .foregroundColor(t.textFaint)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(states) { state in
                        SaveStateCard(state: state) {
                            library.removeSaveState(state, from: liveGame)
                        }
                    }
                }
            }
        }
    }

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(editingNote ? "EDITING" : "NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.8)
                Spacer()
                if editingNote {
                    Button("Done") {
                        editingNote = false
                        UserDefaults.standard.set(noteText, forKey: "gameNote_\(game.id.uuidString)")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(LinearGradient(colors: [t.playBtnStart, t.playBtnEnd],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)
                }
                Button(editingNote ? "Preview" : "✎ Edit") { editingNote.toggle() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(editingNote ? t.accent : t.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(t.cardBorder, lineWidth: 1))
                    .buttonStyle(.plain)
            }
            if editingNote {
                TextEditor(text: $noteText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(t.text)
                    .scrollContentBackground(.hidden)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(t.accent.opacity(0.35), lineWidth: 1))
                    .frame(minHeight: 200)
            } else {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(t.card)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(t.cardBorder, lineWidth: 1))
                    if noteText.isEmpty {
                        Text("Click Edit to add notes…")
                            .font(.system(size: 13))
                            .foregroundColor(t.textFaint)
                            .padding(14)
                    } else {
                        Text(noteText)
                            .font(.system(size: 13))
                            .foregroundColor(t.text)
                            .lineSpacing(4)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minHeight: 200)
                .contentShape(Rectangle())
                .onTapGesture { editingNote = true }
            }
            Text("Plain text notes are saved locally on this device.")
                .font(.system(size: 10))
                .foregroundColor(t.textFaint)
        }
    }

    // MARK: - Game-step navigation

    private enum NavDirection { case previous, next }

    private var sortedGames: [Game] {
        library.games.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    private func adjacentGame(_ direction: NavDirection) -> Game? {
        let games = sortedGames
        guard let idx = games.firstIndex(where: { $0.id == game.id }) else { return nil }
        let target = direction == .previous ? idx - 1 : idx + 1
        return games.indices.contains(target) ? games[target] : nil
    }

    private func step(_ direction: NavDirection) {
        if let next = adjacentGame(direction) {
            appState.navigate(to: .detail(next))
        }
    }

    @ViewBuilder
    private func navArrowButton(direction: NavDirection) -> some View {
        let target = adjacentGame(direction)
        Button { step(direction) } label: {
            Image(systemName: direction == .previous ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(target == nil ? t.textFaint : t.text)
                .frame(width: 40, height: 40)
                .background(target == nil ? t.card.opacity(0.5) : t.card)
                .clipShape(Circle())
                .overlay(Circle()
                    .strokeBorder(t.cardBorder, lineWidth: 1))
                .shadow(color: .black.opacity(target == nil ? 0 : 0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .help(target.map { "\(direction == .previous ? "Previous" : "Next"): \($0.title)" }
              ?? (direction == .previous ? "First game" : "Last game"))
    }

    private func installArrowKeyMonitor() {
        guard arrowKeyMonitor == nil else { return }
        arrowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't steal arrow keys from text editing.
            if isTypingFocused { return event }
            switch event.keyCode {
            case 123: step(.previous); return nil
            case 124: step(.next);     return nil
            default: return event
            }
        }
    }

    private func removeArrowKeyMonitor() {
        if let m = arrowKeyMonitor {
            NSEvent.removeMonitor(m)
            arrowKeyMonitor = nil
        }
    }

    private var isTypingFocused: Bool {
        let responder = NSApp.keyWindow?.firstResponder
        return responder is NSText || responder is NSTextView
    }

    // MARK: - Artwork actions

    private func fetchArtwork() {
        isFetchingArtwork = true
        fetchArtworkError = nil
        let target = liveGame
        Task {
            let ok = await artworkService.scrapeOne(target, library: library, force: true)
            await MainActor.run {
                isFetchingArtwork = false
                if !ok, case .error(let msg) = artworkService.status(for: target.id) {
                    fetchArtworkError = msg
                } else if !ok, case .notFound = artworkService.status(for: target.id) {
                    fetchArtworkError = "No match found on ScreenScraper."
                }
            }
        }
    }

    private func pickCoverImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Cover Image"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                let target = liveGame
                _ = artworkService.setManualCover(from: url, for: target, library: library)
            }
        }
    }

    private func clearArtwork() {
        ArtworkCache.clear(for: liveGame.id)
        library.clearArtwork(liveGame.id)
    }

    // MARK: - Helpers

    private func formatted(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Tab button

private struct TabButton: View {
    let label: String
    let tab: DetailView.DetailTab
    let active: DetailView.DetailTab
    let action: (DetailView.DetailTab) -> Void

    @Environment(\.appTheme) private var t
    private var isActive: Bool { active == tab }

    var body: some View {
        Button { action(tab) } label: {
            Text(label)
                .font(.system(size: 12, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? t.text : t.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(isActive ? t.systemTabActive : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isActive ? t.cardBorderHover : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Back button

struct BackButton: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.appTheme) private var t
    @State private var hovered = false

    var body: some View {
        Button { appState.navigateBack() } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Library")
                    .font(.system(size: 13))
            }
            .foregroundColor(hovered ? t.accent : t.textMuted)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: hovered)
    }
}

// MARK: - Themed segmented picker

/// Drop-in replacement for `.pickerStyle(.segmented)` that respects custom
/// dark/amber themes by drawing the track and label colours explicitly.
struct ThemedSegmentedPicker<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T
    @Environment(\.appTheme) private var t

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                let selected = selection == opt.value
                Button {
                    selection = opt.value
                } label: {
                    Text(opt.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selected ? .white : t.text)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            selected
                                ? t.accent
                                : t.card,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(t.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(t.divider, lineWidth: 1))
    }
}

// MARK: - Save state card

private struct SaveStateCard: View {
    let state: SaveState
    let onDelete: () -> Void
    @Environment(\.appTheme) private var t
    @State private var hovered = false

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black)
                    .aspectRatio(320.0 / 224.0, contentMode: .fit)
                if let img = SaveStateManager.thumbnail(for: state) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(t.textFaint)
                }
                // Delete button on hover
                if hovered {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onDelete) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Timestamp
            Text(Self.dateFormatter.localizedString(for: state.createdAt, relativeTo: Date()))
                .font(.system(size: 10))
                .foregroundColor(t.textMuted)
                .lineLimit(1)
                .padding(.top, 5)
                .padding(.bottom, 3)
        }
        .padding(8)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(hovered ? t.accent.opacity(0.5) : t.cardBorder, lineWidth: 1))
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: hovered)
    }
}

// MARK: - EmulatorSystem display extensions

extension EmulatorSystem {
    var systemIcon: String {
        switch self {
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD:    return "gamecontroller"
        case .cps1, .cps2:                           return "arcade.stick.console"
        case .segaSys16, .segaSys18:                 return "arcade.stick.console"
        case .toaplan1, .toaplan2:                   return "airplane"
        case .konamiGX:                              return "arcade.stick.console"
        case .konami68k:                             return "arcade.stick.console"
        case .irem:                                  return "airplane"
        case .taito:                                 return "arcade.stick.console"
        }
    }

    var logoAssetName: String {
        switch self {
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD: return "NeoGeoLogo"
        case .cps1:                               return "CPS1Logo"
        case .cps2:                               return "CPS2Logo"
        case .segaSys16, .segaSys18:              return "SegaLogo"
        case .toaplan1, .toaplan2:                return "ToaplanLogo"
        case .konamiGX, .konami68k:               return "KonamiLogo"
        case .irem:                               return "IremLogo"
        case .taito:                              return "TaitoLogo"
        }
    }

    var hardwareDescription: String {
        switch self {
        case .neoGeoAES:  return "SNK Neo Geo AES Home System"
        case .neoGeoMVS:  return "SNK Neo Geo MVS Arcade Hardware"
        case .neoGeoCD:   return "SNK Neo Geo CD Console"
        case .cps1:       return "Capcom Play System 1 · 68000 / Z80"
        case .cps2:       return "Capcom Play System 2 · 68000 / Q-Sound"
        case .segaSys16:  return "Sega System 16 · 68000 / Z80"
        case .segaSys18:  return "Sega System 18 · 68000 / Z80 / VDP"
        case .toaplan1:   return "Toaplan 1 · 68000 / Z80"
        case .toaplan2:   return "Toaplan 2 · 68000 / GP9001"
        case .konamiGX:   return "Konami GX · 68EC020 / K054539"
        case .konami68k:  return "Konami 16-bit · 68000 / K053260"
        case .irem:       return "Irem M72/M92 · V30 / Z80"
        case .taito:      return "Taito F2/F3 · 68000 / Z80"
        }
    }

    func systemBlurb(title: String) -> String {
        switch self {
        case .neoGeoAES, .neoGeoMVS:
            return "\(title) is a Neo Geo title running on SNK's legendary MVS/AES hardware — renowned for its large ROM capacity, crisp pixel art, and arcade-perfect home conversions."
        case .neoGeoCD:
            return "\(title) is a Neo Geo CD release featuring CD-quality audio and enhanced loading of the full MVS/AES library in an affordable home format."
        case .cps1:
            return "\(title) runs on Capcom's CPS-1 hardware, the board behind some of Capcom's most iconic late-80s and early-90s arcade titles."
        case .cps2:
            return "\(title) runs on CPS-2, Capcom's encrypted successor board featuring the Q-Sound audio system and the powerhouse fighters of the mid-90s arcade scene."
        case .segaSys16:
            return "\(title) runs on Sega's System 16, the 68000-based board that powered Shinobi, Golden Axe, and Altered Beast — Sega's dominant arcade platform of the late 80s."
        case .segaSys18:
            return "\(title) runs on Sega System 18, an evolution of System 16 adding a VDP tile layer for richer backgrounds."
        case .toaplan1:
            return "\(title) runs on Toaplan 1 hardware, home to some of the most demanding vertical scrolling shooters of the late 80s arcade era."
        case .toaplan2:
            return "\(title) runs on Toaplan 2, featuring the GP9001 sprite/tile chip that powered Batsugun and other late-era Toaplan titles."
        case .konamiGX:
            return "\(title) runs on the Konami GX board — a 68EC020-powered 32-bit platform featuring the PSAC2 rotate/scale chip and K054539 sound."
        case .konami68k:
            return "\(title) runs on Konami's 16-bit 68000-era boards — the family behind Teenage Mutant Ninja Turtles, The Simpsons, X-Men, and Sunset Riders, driven by the K052109/K051960 tile/sprite chipset and K053260 sound."
        case .irem:
            return "\(title) runs on Irem M-series hardware — the board family behind R-Type, Image Fight, and Ninja Baseball Batman, known for precise controls and large sprites."
        case .taito:
            return "\(title) runs on Taito arcade hardware — a prolific platform spanning titles from Rainbow Islands and Ninja Warriors to Elevator Action Returns."
        }
    }
}

// MARK: - Name Override sheet

private struct NameOverrideSheet: View {
    let game: Game
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    @Environment(\.appTheme) private var t
    @State private var draft: String

    init(game: Game, onSave: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.game = game
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: game.scrapeNameOverride ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Name Override")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(t.text)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 6)

            Text("Send a different filename to ScreenScraper when fetching artwork. The actual ROM file is not renamed.")
                .font(.system(size: 12))
                .foregroundColor(t.textMuted)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("ACTUAL FILENAME")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.6)
                Text(game.romURL.lastPathComponent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(t.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("OVERRIDE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.6)
                TextField("e.g. tmnt.zip", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(t.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(t.cardBorder, lineWidth: 1))
                Text("If you omit “.zip”, it will be appended automatically.")
                    .font(.system(size: 10))
                    .foregroundColor(t.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            Divider().background(t.divider)

            HStack {
                if game.scrapeNameOverride != nil {
                    Button("Clear Override") { onSave(nil) }
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .buttonStyle(.plain)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(game.scrapeNameOverride == nil ? "Save & Refetch" : "Update & Refetch") {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(trimmed.isEmpty ? nil : trimmed)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty
                          && game.scrapeNameOverride == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 460)
        .background(t.surface)
    }
}
