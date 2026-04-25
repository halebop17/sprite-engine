import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var library: ROMLibrary
    @EnvironmentObject private var conversionQueue: ConversionQueue
    @Environment(\.appTheme) private var t

    @State private var isTargeted = false
    @State private var directItems: [DirectItem] = []

    // ZIPs that map to CPS-1/2 (FBNeo loads them directly — no conversion needed)
    struct DirectItem: Identifiable {
        let id    = UUID()
        let url:  URL
        let title: String
        var state: DirectState
        enum DirectState { case added, failed(String) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(t.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock
                    systemBadges
                    dropZone
                    biosNotice
                    if !allItems.isEmpty { progressList }
                }
                .padding(26)
            }
        }
        .background(t.surface)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            BackButton()
            Spacer()
            if !conversionQueue.items.filter({ $0.state.isPending }).isEmpty || conversionQueue.isRunning {
                Label("Converting…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(t.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(t.toolbar)
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Import ROMs")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(t.text)
            Text("Add ROM files to your Sprite Engine library. Supports Neo Geo, CPS, Sega, Toaplan, and Konami.")
                .font(.system(size: 13))
                .foregroundColor(t.textMuted)
                .lineSpacing(3)
        }
    }

    // MARK: - System badges

    private var systemBadges: some View {
        HStack(spacing: 8) {
            ForEach(systemBadgeData, id: \.label) { badge in
                HStack(spacing: 7) {
                    Circle().fill(badge.color).frame(width: 8, height: 8)
                    Text(badge.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.text)
                    Text("\(badge.count) ROMs")
                        .font(.system(size: 10))
                        .foregroundColor(t.textFaint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(t.cardBorder, lineWidth: 1))
            }
        }
    }

    private var systemBadgeData: [(label: String, color: Color, count: Int)] {
        [
            ("Neo Geo",  t.sysNeo,     library.games.filter { $0.system.isNeoGeo }.count),
            ("CPS-1",    t.sysCPS1,    library.games.filter { $0.system == .cps1 }.count),
            ("CPS-2",    t.sysCPS2,    library.games.filter { $0.system == .cps2 }.count),
            ("Sega",     t.sysSega,    library.games.filter { $0.system.isSega }.count),
            ("Toaplan",  t.sysToaplan, library.games.filter { $0.system.isToaplan }.count),
            ("Konami",   t.sysKonami,  library.games.filter { $0.system.isKonami }.count),
        ]
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 14) {
            Image(systemName: "archivebox")
                .font(.system(size: 34))
                .foregroundColor(isTargeted ? t.accent : t.textFaint)
            VStack(spacing: 4) {
                Text(isTargeted ? "Drop to add" : "Drop ROM files here")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.text)
                Text(".zip, .neo · Neo Geo MAME archives, CPS, Sega, Toaplan, Konami")
                    .font(.system(size: 12))
                    .foregroundColor(t.textMuted)
            }
            Button("Choose Files…", action: pickFiles)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(LinearGradient(colors: [t.playBtnStart, t.playBtnEnd],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: t.accent.opacity(0.4), radius: 5, y: 2)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(isTargeted ? t.accentSoft : t.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? t.accent : t.divider,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
        )
        .animation(.easeInOut(duration: 0.16), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - BIOS notice

    private var biosNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(t.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("BIOS Files Required")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(t.text)
                Group {
                    Text("Place ")
                    + Text("neogeo.zip").font(.system(size: 11, design: .monospaced))
                        .foregroundColor(t.accent)
                    + Text(" for Neo Geo and ")
                    + Text("qsound.zip").font(.system(size: 11, design: .monospaced))
                        .foregroundColor(t.accent)
                    + Text(" for CPS-2 in your ROM directory, then set it in Settings.")
                }
                .font(.system(size: 11.5))
                .foregroundColor(t.textMuted)
                .lineSpacing(2)
                if !appState.isBIOSPresent {
                    Button("Open Settings") { appState.navigate(to: .settings) }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(t.tagText)
                        .padding(.top, 2)
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(t.cardBorder, lineWidth: 1))
    }

    // MARK: - Progress list

    private var allItems: [AnyImportRow] {
        var rows: [AnyImportRow] = []
        rows += conversionQueue.items.map { AnyImportRow(id: $0.id, title: $0.title, state: .fromConversion($0.state)) }
        rows += directItems.map { AnyImportRow(id: $0.id, title: $0.title, state: .fromDirect($0.state)) }
        return rows
    }

    private var progressList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("IMPORTING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.textFaint)
                    .kerning(0.8)
                Spacer()
                if conversionQueue.items.allSatisfy({ $0.state.isFinished }) && !directItems.isEmpty {
                    Button("Clear") {
                        conversionQueue.clearFinished()
                        directItems.removeAll { if case .added = $0.state { return true }; return true }
                    }
                    .font(.system(size: 11))
                    .foregroundColor(t.textMuted)
                    .buttonStyle(.plain)
                }
            }
            ForEach(allItems) { row in
                ImportRowView(row: row)
            }
        }
    }

    // MARK: - File handling

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose ROM Files"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "zip")!,
            UTType(filenameExtension: "neo")!,
        ]
        panel.begin { response in
            guard response == .OK else { return }
            processURLs(panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                DispatchQueue.main.async { processURLs([url]) }
            }
        }
    }

    private func processURLs(_ urls: [URL]) {
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
            let ext  = url.pathExtension.lowercased()
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()

            if ext == "neo" {
                // .neo files go straight into the library via a scan
                Task { await library.scan(directory: url.deletingLastPathComponent()) }
            } else if ext == "zip" {
                let system = GameDatabase.shared[stem]
                switch system {
                case .neoGeoAES, .neoGeoMVS, .neoGeoCD, .none:
                    // Neo Geo or unknown zip → enqueue for .neo conversion
                    conversionQueue.enqueue([url])
                case .cps1, .cps2, .segaSys16, .segaSys18, .toaplan1, .toaplan2, .konamiGX, .irem, .taito:
                    // FBNeo zip → loads directly, add to library via scan
                    let item = DirectItem(url: url, title: stem.uppercased(), state: .added)
                    directItems.append(item)
                    Task { await library.scan(directory: url.deletingLastPathComponent()) }
                }
            }
        }
    }
}

// MARK: - Import row model (unified across conversion + direct)

struct AnyImportRow: Identifiable {
    let id:    UUID
    let title: String
    let state: RowState

    enum RowState {
        case fromConversion(ConversionState)
        case fromDirect(ImportView.DirectItem.DirectState)

        var icon: String {
            switch self {
            case .fromConversion(.done):    return "checkmark.circle.fill"
            case .fromConversion(.failed):  return "xmark.circle.fill"
            case .fromDirect(.added):       return "checkmark.circle.fill"
            case .fromDirect(.failed):      return "xmark.circle.fill"
            default:                        return "arrow.triangle.2.circlepath"
            }
        }

        var iconColor: Color {
            switch self {
            case .fromConversion(.done), .fromDirect(.added):   return Color(hex: "30d158")
            case .fromConversion(.failed), .fromDirect(.failed): return Color(red: 1, green: 0.27, blue: 0.23)
            default: return .orange
            }
        }

        var statusLabel: String {
            switch self {
            case .fromConversion(.pending):              return "Queued"
            case .fromConversion(.converting(let p)):   return "\(Int(p * 100))%"
            case .fromConversion(.done):                return "Ready"
            case .fromConversion(.failed):              return "Failed"
            case .fromDirect(.added):                   return "Added"
            case .fromDirect(.failed(let e)):           return e
            }
        }

        var progress: Double? {
            if case .fromConversion(.converting(let p)) = self { return p }
            return nil
        }
    }
}

private struct ImportRowView: View {
    let row: AnyImportRow
    @Environment(\.appTheme) private var t

    private var isDone: Bool {
        switch row.state {
        case .fromConversion(.done), .fromDirect(.added): return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: row.state.icon)
                    .font(.system(size: 13))
                    .foregroundColor(row.state.iconColor)
                Text(row.title)
                    .font(.system(size: 12.5))
                    .foregroundColor(t.text)
                    .lineLimit(1)
                Spacer()
                Text(row.state.statusLabel)
                    .font(.system(size: 11))
                    .foregroundColor(isDone ? Color(hex: "30d158") : t.textMuted)
            }
            if let p = row.state.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(t.divider)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(t.accent)
                            .frame(width: geo.size.width * p, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(isDone ? t.card.opacity(0.5) : t.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isDone ? t.accent.opacity(0.28) : t.cardBorder, lineWidth: 1))
    }
}
