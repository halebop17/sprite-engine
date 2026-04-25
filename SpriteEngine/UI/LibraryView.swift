import SwiftUI

// MARK: - Theme key

enum AppThemeKey: String, CaseIterable {
    case dark  = "dark"
    case light = "light"
    case amber = "amber"

    var displayName: String {
        switch self {
        case .dark:  return "Dark Cinematic"
        case .light: return "macOS Native"
        case .amber: return "CRT Amber"
        }
    }
}

// MARK: - AppTheme

struct AppTheme {
    let key: AppThemeKey

    var surface:         Color
    var sidebar:         Color
    var sidebarBorder:   Color
    var toolbar:         Color
    var text:            Color
    var textMuted:       Color
    var textFaint:       Color
    var accent:          Color
    var accentSoft:      Color
    var card:            Color
    var cardHover:       Color
    var cardBorder:      Color
    var cardBorderHover: Color
    var divider:         Color
    var inputBg:         Color
    var tag:             Color
    var tagText:         Color
    var icon:            Color
    var sidebarActive:   Color
    var systemTabsBg:    Color
    var systemTabActive: Color
    var playBtnStart:    Color
    var playBtnEnd:      Color
    var sysNeo:          Color
    var sysCPS1:         Color
    var sysCPS2:         Color
    var sysSega:         Color
}

extension AppTheme {
    static let dark = AppTheme(
        key:             .dark,
        surface:         Color(hex: "0f0f1c"),
        sidebar:         Color.white.opacity(0.03),
        sidebarBorder:   Color.white.opacity(0.06),
        toolbar:         Color(hex: "0f0f1c").opacity(0.92),
        text:            Color(hex: "e8e8f2"),
        textMuted:       Color(hex: "e8e8f2").opacity(0.5),
        textFaint:       Color(hex: "e8e8f2").opacity(0.22),
        accent:          Color(hex: "e8001c"),
        accentSoft:      Color(hex: "e8001c").opacity(0.14),
        card:            Color.white.opacity(0.042),
        cardHover:       Color.white.opacity(0.085),
        cardBorder:      Color.white.opacity(0.07),
        cardBorderHover: Color(hex: "e8001c").opacity(0.5),
        divider:         Color.white.opacity(0.06),
        inputBg:         Color.white.opacity(0.055),
        tag:             Color(hex: "e8001c").opacity(0.15),
        tagText:         Color(hex: "ff4d5e"),
        icon:            Color(hex: "e8e8f2").opacity(0.42),
        sidebarActive:   Color(hex: "e8001c").opacity(0.9),
        systemTabsBg:    Color.white.opacity(0.03),
        systemTabActive: Color.white.opacity(0.1),
        playBtnStart:    Color(hex: "e8001c"),
        playBtnEnd:      Color(hex: "ff3850"),
        sysNeo:          Color(hex: "ffd60a"),
        sysCPS1:         Color(hex: "009ee0"),
        sysCPS2:         Color(hex: "0071c5"),
        sysSega:         Color(hex: "0066b3")
    )

    static let light = AppTheme(
        key:             .light,
        surface:         Color(hex: "f4f4fa"),
        sidebar:         Color(red: 0.82, green: 0.87, blue: 0.95).opacity(0.55),
        sidebarBorder:   Color.white.opacity(0.65),
        toolbar:         Color(hex: "f4f4fa").opacity(0.85),
        text:            Color(hex: "1c1c1e"),
        textMuted:       Color(hex: "1c1c1e").opacity(0.5),
        textFaint:       Color(hex: "1c1c1e").opacity(0.28),
        accent:          Color(hex: "0071e3"),
        accentSoft:      Color(hex: "0071e3").opacity(0.09),
        card:            Color.white.opacity(0.75),
        cardHover:       Color.white,
        cardBorder:      Color.black.opacity(0.05),
        cardBorderHover: Color(hex: "0071e3").opacity(0.45),
        divider:         Color.black.opacity(0.07),
        inputBg:         Color.white.opacity(0.6),
        tag:             Color(hex: "0071e3").opacity(0.08),
        tagText:         Color(hex: "0055b3"),
        icon:            Color(hex: "1c1c1e").opacity(0.4),
        sidebarActive:   Color(hex: "0071e3").opacity(0.88),
        systemTabsBg:    Color.black.opacity(0.04),
        systemTabActive: Color.white.opacity(0.85),
        playBtnStart:    Color(hex: "0071e3"),
        playBtnEnd:      Color(hex: "5e5ce6"),
        sysNeo:          Color(hex: "d4a017"),
        sysCPS1:         Color(hex: "0071e3"),
        sysCPS2:         Color(hex: "5856d6"),
        sysSega:         Color(hex: "2563a8")
    )

    static let amber = AppTheme(
        key:             .amber,
        surface:         Color(hex: "0b0800"),
        sidebar:         Color(red: 1, green: 0.59, blue: 0).opacity(0.03),
        sidebarBorder:   Color(red: 1, green: 0.59, blue: 0).opacity(0.09),
        toolbar:         Color(hex: "0b0800").opacity(0.96),
        text:            Color(hex: "ffc030"),
        textMuted:       Color(hex: "ffc030").opacity(0.5),
        textFaint:       Color(hex: "ffc030").opacity(0.2),
        accent:          Color(hex: "ff9500"),
        accentSoft:      Color(hex: "ff9500").opacity(0.13),
        card:            Color(red: 1, green: 0.55, blue: 0).opacity(0.05),
        cardHover:       Color(red: 1, green: 0.55, blue: 0).opacity(0.1),
        cardBorder:      Color(red: 1, green: 0.55, blue: 0).opacity(0.1),
        cardBorderHover: Color(hex: "ff9500").opacity(0.55),
        divider:         Color(red: 1, green: 0.55, blue: 0).opacity(0.08),
        inputBg:         Color(red: 1, green: 0.55, blue: 0).opacity(0.07),
        tag:             Color(hex: "ff9500").opacity(0.14),
        tagText:         Color(hex: "ffb340"),
        icon:            Color(hex: "ffc030").opacity(0.42),
        sidebarActive:   Color(hex: "ff9500").opacity(0.85),
        systemTabsBg:    Color(red: 1, green: 0.55, blue: 0).opacity(0.04),
        systemTabActive: Color(red: 1, green: 0.55, blue: 0).opacity(0.14),
        playBtnStart:    Color(hex: "ff9500"),
        playBtnEnd:      Color(hex: "e05c00"),
        sysNeo:          Color(hex: "ffd60a"),
        sysCPS1:         Color(hex: "30a0ff"),
        sysCPS2:         Color(hex: "5898e8"),
        sysSega:         Color(hex: "4488cc")
    )

    static func theme(for key: AppThemeKey) -> AppTheme {
        switch key {
        case .dark:  return .dark
        case .light: return .light
        case .amber: return .amber
        }
    }
}

// MARK: - Environment key

private struct AppThemeEnvKey: EnvironmentKey {
    static let defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeEnvKey.self] }
        set { self[AppThemeEnvKey.self] = newValue }
    }
}

// MARK: - AppState theme extension

extension AppState {
    var currentTheme: AppTheme { AppTheme.theme(for: themeKey) }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Library filter

enum LibraryFilter: Hashable {
    case all, favorites, recent
    case neoGeo, cps1, cps2, sega

    func matches(_ game: Game) -> Bool {
        switch self {
        case .all:       return true
        case .favorites: return game.isFavorite
        case .recent:    return game.lastPlayed != nil
        case .neoGeo:    return game.system.isNeoGeo
        case .cps1:      return game.system == .cps1
        case .cps2:      return game.system == .cps2
        case .sega:      return game.system.isSega
        }
    }

    var label: String {
        switch self {
        case .all:       return "All Games"
        case .favorites: return "Favorites"
        case .recent:    return "Recently Played"
        case .neoGeo:    return "Neo Geo"
        case .cps1:      return "CPS-1"
        case .cps2:      return "CPS-2"
        case .sega:      return "Sega"
        }
    }
}

// MARK: - LibraryView (root)

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @State private var filter: LibraryFilter = .all
    @State private var search = ""

    private var theme: AppTheme { appState.currentTheme }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(filter: $filter)
                .environment(\.appTheme, theme)
            Divider().opacity(0)
            VStack(spacing: 0) {
                LibraryToolbar(filter: filter, search: $search)
                    .environment(\.appTheme, theme)
                LibraryContent(filter: filter, search: search)
                    .environment(\.appTheme, theme)
            }
        }
        .background(theme.surface)
        .environment(\.appTheme, theme)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @Binding var filter: LibraryFilter
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @Environment(\.appTheme) private var t

    private var neogeoCount: Int { library.games.filter { $0.system.isNeoGeo }.count }
    private var cps1Count:   Int { library.games.filter { $0.system == .cps1 }.count }
    private var cps2Count:   Int { library.games.filter { $0.system == .cps2 }.count }
    private var segaCount:   Int { library.games.filter { $0.system.isSega }.count }

    private var activeSystems: Int {
        [neogeoCount > 0, cps1Count > 0, cps2Count > 0, segaCount > 0].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand
            HStack(spacing: 9) {
                BrandIcon()
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sprite Engine")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(t.text)
                    Text("Multi-System Emulator")
                        .font(.system(size: 10))
                        .foregroundColor(t.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            Divider().background(t.divider).padding(.bottom, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("LIBRARY")
                    NavItem(label: "All Games",       icon: "square.grid.2x2",  filter: .all,       active: filter)  { filter = $0 }
                    NavItem(label: "Favorites",       icon: "heart",             filter: .favorites, active: filter)  { filter = $0 }
                    NavItem(label: "Recently Played", icon: "clock",             filter: .recent,    active: filter)  { filter = $0 }

                    SectionHeader("PLATFORMS")
                    PlatformItem(label: "Neo Geo", logo: "NeoGeoLogo", color: t.sysNeo,  count: neogeoCount, filter: .neoGeo, active: filter) { filter = $0 }
                    PlatformItem(label: "CPS-1",   logo: "CPS1Logo",   color: t.sysCPS1, count: cps1Count,   filter: .cps1,   active: filter) { filter = $0 }
                    PlatformItem(label: "CPS-2",   logo: "CPS2Logo",   color: t.sysCPS2, count: cps2Count,   filter: .cps2,   active: filter) { filter = $0 }
                    if segaCount > 0 {
                        PlatformItem(label: "Sega", logo: "SegaLogo", color: t.sysSega, count: segaCount, filter: .sega, active: filter) { filter = $0 }
                    }

                    Divider().background(t.divider).padding(.horizontal, 14).padding(.vertical, 8)

                    SectionHeader("SYSTEM")
                    ActionItem(label: "Import ROMs", icon: "plus.circle") { appState.navigate(to: .`import`) }
                    ActionItem(label: "Settings",    icon: "gearshape")   { appState.navigate(to: .settings) }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            // Footer
            Divider().background(t.divider)
            Text("\(library.games.count) ROMs · \(activeSystems) systems")
                .font(.system(size: 10))
                .foregroundColor(t.textFaint)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 200)
        .background(t.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(t.sidebarBorder).frame(width: 1)
        }
    }
}

// MARK: - Sidebar sub-components

private struct SectionHeader: View {
    let label: String
    @Environment(\.appTheme) private var t
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.9)
            .foregroundColor(t.textFaint)
            .padding(.leading, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

private struct NavItem: View {
    let label: String
    let icon: String
    let filter: LibraryFilter
    let active: LibraryFilter
    let action: (LibraryFilter) -> Void

    @Environment(\.appTheme) private var t
    @State private var hovered = false
    private var isActive: Bool { active == filter }

    var body: some View {
        Button { action(filter) } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? .white : t.icon)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : t.text)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5.5)
            .background(isActive ? t.sidebarActive : (hovered ? t.accentSoft : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct PlatformItem: View {
    let label: String
    let logo: String
    let color: Color
    let count: Int
    let filter: LibraryFilter
    let active: LibraryFilter
    let action: (LibraryFilter) -> Void

    @Environment(\.appTheme) private var t
    @State private var hovered = false
    private var isActive: Bool { active == filter }

    var body: some View {
        Button { action(filter) } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive ? Color.white.opacity(0.18) : color.opacity(0.22))
                        .frame(width: 34, height: 34)
                    Image(logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                Text(label)
                    .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : t.text)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? .white.opacity(0.65) : t.textFaint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? t.sidebarActive : (hovered ? t.accentSoft : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct ActionItem: View {
    let label: String
    let icon: String
    let action: () -> Void

    @Environment(\.appTheme) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(t.icon)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12.5))
                    .foregroundColor(t.text)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5.5)
            .background(hovered ? t.accentSoft : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct BrandIcon: View {
    @Environment(\.appTheme) private var t

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(
                    colors: [t.accent, t.accent.opacity(0.73)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: t.accent.opacity(0.4), radius: 7, y: 4)
            Image(systemName: "arcade.stick.console")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 34, height: 34)
    }
}

// MARK: - Toolbar

private struct LibraryToolbar: View {
    let filter: LibraryFilter
    @Binding var search: String
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @Environment(\.appTheme) private var t

    private var title: String {
        switch filter {
        case .all:       return "All Games (\(library.games.count))"
        case .favorites: return "Favorites"
        case .recent:    return "Recently Played"
        case .neoGeo:    return "Neo Geo (\(library.games.filter { $0.system.isNeoGeo }.count))"
        case .cps1:      return "CPS-1 (\(library.games.filter { $0.system == .cps1 }.count))"
        case .cps2:      return "CPS-2 (\(library.games.filter { $0.system == .cps2 }.count))"
        case .sega:      return "Sega (\(library.games.filter { $0.system.isSega }.count))"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(t.text)
            Spacer()
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(t.icon)
                TextField("Search games…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(t.text)
                    .tint(t.accent)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(t.icon)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(t.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.divider, lineWidth: 1))
            .frame(width: 180)
            // Import button
            Button { appState.navigate(to: .`import`) } label: {
                Text("+ Import")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(LinearGradient(colors: [t.playBtnStart, t.playBtnEnd],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: t.accent.opacity(0.4), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(t.toolbar)
        .overlay(alignment: .bottom) { Rectangle().fill(t.divider).frame(height: 1) }
    }
}

// MARK: - Library content grid

private struct LibraryContent: View {
    let filter: LibraryFilter
    let search: String

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @Environment(\.appTheme) private var t

    private var filtered: [Game] {
        library.games.filter { game in
            filter.matches(game) &&
            (search.isEmpty || game.title.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !appState.isBIOSPresent {
                biosBanner
            }
            ScrollView {
                if filtered.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 144), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(filtered) { game in
                            GameCardView(game: game) {
                                appState.navigate(to: .detail(game))
                            }
                        }
                    }
                    .padding(18)
                }
            }
        }
        .background(t.surface)
    }

    private var biosBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)
            Text("BIOS files not found — some games may not launch.")
                .font(.system(size: 12))
                .foregroundColor(t.text)
            Spacer()
            Button("Fix in Settings") { appState.navigate(to: .settings) }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(t.accent)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.orange.opacity(0.2)).frame(height: 1) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: search.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(t.textFaint)
            Text(search.isEmpty ? "No games in library" : "No games found")
                .font(.system(size: 14))
                .foregroundColor(t.textMuted)
            if search.isEmpty && filter == .all {
                Button("Import ROMs") { appState.navigate(to: .`import`) }
                    .buttonStyle(.borderedProminent)
                    .tint(t.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
