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

    enum DetailTab { case info, notes, saveStates }

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
    }

    // MARK: - Left sidebar (220px art + stats)

    private var sidebarColumn: some View {
        ScrollView {
            VStack(spacing: 12) {
                BoxArtView(game: game, size: 220)
                    .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(t.cardBorder, lineWidth: 1))
                statsCard
            }
            .padding(26)
        }
        .frame(width: 272)
        .background(t.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(t.sidebarBorder).frame(width: 1)
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
                        .frame(width: 44, height: 44)
                    Image(systemName: game.system.systemIcon)
                        .font(.system(size: 20))
                        .foregroundColor(game.system.badgeColor)
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
        let states = game.saveStates.sorted { $0.createdAt > $1.createdAt }
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
                            library.removeSaveState(state, from: game)
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
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD: return "gamecontroller"
        case .cps1, .cps2:                       return "arcade.stick.console"
        }
    }

    var hardwareDescription: String {
        switch self {
        case .neoGeoAES: return "SNK Neo Geo AES Home System"
        case .neoGeoMVS: return "SNK Neo Geo MVS Arcade Hardware"
        case .neoGeoCD:  return "SNK Neo Geo CD Console"
        case .cps1:      return "Capcom Play System 1 · 68000 / Z80"
        case .cps2:      return "Capcom Play System 2 · 68000 / Q-Sound"
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
        }
    }
}
